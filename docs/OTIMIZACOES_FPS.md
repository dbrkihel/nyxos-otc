# Otimizações de FPS — NyxosClient

Documento técnico das mudanças feitas para aumentar o FPS do client. As **duas que mais
deram resultado** estão detalhadas primeiro:

1. **Cache de framebuffer da UI (render C++)** — a maior de todas: `fps mínimo 0 → 178`,
   eliminou os *hitches* e derrubou o custo do render thread de 72% para 16%.
2. **Battle list — só reconstruir janelas visíveis (Lua)** — era o gargalo #1 de Lua na
   hunt; cortou ~21 janelas reconstruídas por tick para ~1 (≈20×).

No fim há uma seção com as otimizações secundárias (texto do mapa por referência,
walking, etc.).

---

## TL;DR — resultados medidos

| Otimização | Onde | Antes | Depois |
| --- | --- | --- | --- |
| **Cache de FB da UI** | render thread C++ (`DrawSecondForeground`) | 72% do render thread, 265–352 draw-calls/frame, **fps mín 0** (hitches) | 16% do render thread, **26 draw-calls/frame**, **fps mín 178**, UI re-rasterizada ~8/120 frames |
| **Throttle do build da UI** | main/worker thread C++ (`DrawForeground`) | build da UI a ~1000fps (~40% do worker) | build limitado a ~60fps → *"melhorou o fps pra caramba"* |
| **Battle list só-visíveis** | Lua (`checkCreatures`) | ~570–805 ms a cada 20 s, 21 janelas reconstruídas/tick | ~1 janela/tick (≈20× menos trabalho) |

---

## 1) Cache de framebuffer da UI (render C++) — a maior melhoria

**Arquivos:**
[graphicalapplication.cpp](src/framework/core/graphicalapplication.cpp) ·
[graphicalapplication.h](src/framework/core/graphicalapplication.h) ·
[luafunctions.cpp](src/framework/luafunctions.cpp)

### O problema

O run loop em [graphicalapplication.cpp](src/framework/core/graphicalapplication.cpp), por
frame, executa os passes: `UpdateMap` (desenha o mapa inteiro num framebuffer próprio),
`DrawFirstForeground`, `DrawMapBackground`, `DrawMapForeground` e
**`DrawSecondForeground`** (`toDrawQueue->draw(DRAW_AFTER_MAP)`).

Descoberta-chave: `markMapPosition()` é chamado no `UIMap::drawSelf`, então
**`DRAW_AFTER_MAP` = a UI inteira desenhada por cima do mapa** (painéis, janelas, battle
list, trackers, action bars, labels, barras) — **não** os efeitos de spell (esses vão no
`UpdateMap`).

O batching (`drawqueue.cpp` / `drawcache.h`) acumula itens cacheáveis num atlas + vertex
buffer e dá flush em 1 GL draw-call quando enche. Mas **todo texto** (`g_painter->drawText`,
cada chamada = `m_calls += 1`), além de clips/rotações/marks, **quebra o batch** (cada um =
flush + draw-call). Resultado diagnosticado numa hunt:

> `DrawSecondForeground` = **72% do render thread**, **265–352 draw-calls/frame** (88% de
> todos os draw-calls do frame), **~290 deles eram TEXTO** (nameplates/dano), verts médios
> 53k (encostando no teto de 65k do cache).

A causa real do custo: **a UI inteira era re-rasterizada ~1000×/s** (o client roda sem
vsync, cap alto), mesmo a UI mudando só algumas vezes por segundo. Era trabalho jogado
fora e fonte dos *hitches* (fps mínimo caindo a 0).

### O conserto — Fase 1: cachear a UI num framebuffer

A UI dos widgets atualiza via `scheduleEvent(cb, intervalo)` (fps 500ms, cooldowns 250ms,
barras só em evento) — **não por frame**. Logo, fica idêntica em ~90% dos frames. O molde
foi o próprio mapa (que já usa `m_mapFramebuffer`).

Foi adicionado um `m_uiFramebuffer` persistente, criado no boot junto dos outros
([graphicalapplication.cpp:140](src/framework/core/graphicalapplication.cpp#L140)):

```cpp
m_uiFramebuffer = g_framebuffers.createFrameBuffer();
m_uiFramebuffer->resize(g_painter->getResolution());
```

No bloco `DrawSecondForeground`
([graphicalapplication.cpp:331-362](src/framework/core/graphicalapplication.cpp#L331-L362)),
com o cache ligado a UI é re-rasterizada **no máximo a ~60fps** (16666 µs) ou quando há
mudança de resolução/scaling ou um repaint explícito; nos demais frames apenas faz **blit
da textura cacheada**:

```cpp
AutoStat s(STATS_RENDER, "DrawSecondForeground");
if (m_cacheUI) {
    const Size uiRes = g_painter->getResolution();
    const ticks_t uiNow = stdext::micros();
    // refresca em mudança de resolução/scaling, em repaint explícito, ou quando passou o
    // intervalo de ~60fps; caso contrário reusa a textura cacheada.
    if (uiRes != uiCacheSize || repaintRequested || uiNow - uiCacheLastRender >= 16666) {
        m_uiFramebuffer->resize(uiRes);
        m_uiFramebuffer->bind();
        g_painter->clear(Color::alpha);
        toDrawQueue->draw(DRAW_AFTER_MAP);   // mesmo path de draw -> clips/condições replayam certo
        m_uiFramebuffer->release();
        uiCacheLastRender = uiNow;
        uiCacheSize = uiRes;
    }
    // reset COMPLETO (não só a cor): em frames de cache-hit nada resetava o painter,
    // então composição/blend/clip/shader do draw anterior poderia vazar para o blit e
    // divergir do path sem cache (que termina em DrawQueue::draw -> resetState).
    g_painter->resetState();                 // resetState NÃO mexe na resolução
    m_uiFramebuffer->draw(Rect(0, 0, uiRes)); // compõe a UI sobre o mapa
} else {
    toDrawQueue->draw(DRAW_AFTER_MAP);       // caminho original (cache off)
}
```

Por que funciona sem race: o `m_uiFramebuffer` é **propriedade do render thread** (igual ao
`m_mapFramebuffer`), então não há acesso cross-thread. Os clips/condições replayam corretos
porque é exatamente o mesmo `draw(DRAW_AFTER_MAP)`, só que para dentro do framebuffer.

**Fix crítico da revisão adversarial:** usar `g_painter->resetState()` (não só
`resetColor`) antes do blit no cache-hit — senão a composição/blend/clip do frame anterior
vazava para o blit. `resetState` preserva a resolução.

### O conserto — Fase 2b: throttle do *build* da UI no worker thread

A Fase 1 cortou a **re-rasterização** (render thread). Mas o **build da fila** da UI
(`g_ui.render(Fw::ForegroundPane)`, a reconstrução da árvore de widgets na main/worker
thread) ainda rodava à taxa cheia do producer — era ~40% do `DrawForeground` desse thread.

Como o consumer já reusa a última fila (`toDrawQueue = drawQueue ? drawQueue : toDrawQueue`)
e o framebuffer cacheado, rebuildar a árvore na taxa cheia é trabalho perdido. O build
passou a ser limitado a ~60fps quando o cache está ligado
([graphicalapplication.cpp:193-211](src/framework/core/graphicalapplication.cpp#L193-L211)):

```cpp
const ticks_t uiNow = stdext::micros();
if (!m_cacheUI || m_mustRepaint || uiNow - uiBuildLast >= 16666) {
    {
        AutoStat s(STATS_MAIN, "DrawForeground");
        g_drawQueue = std::make_shared<DrawQueue>();
        g_ui.render(Fw::ForegroundPane);
    }
    mutex.lock();
    drawQueue = g_drawQueue;
    g_drawQueue = nullptr;
    mutex.unlock();
    uiBuildLast = uiNow;
}
// senão: pula o rebuild — drawQueue fica null, o consumer mantém a última fila da UI
```

Para manter a interação **crisp** sob o throttle, qualquer input que não seja um simples
mouse-move força um refresh imediato (rebuild + re-rasteriza no mesmo ciclo) em vez de
esperar até ~32ms ([graphicalapplication.cpp:451-456](src/framework/core/graphicalapplication.cpp#L451-L456)):

```cpp
// clique/tecla/wheel = refresh imediato; MouseMove fica de fora p/ não anular o throttle
if (event.type != Fw::MouseMoveInputEvent)
    m_mustRepaint = true;
```

**Fixes da revisão adversarial (liveness/cross-thread):**
- `m_mustRepaint` virou `std::atomic_bool` — é setado no worker thread e lido/limpo no
  render thread (antes era `bool` puro = UB cross-thread).
  ([graphicalapplication.h:84](src/framework/core/graphicalapplication.h#L84))
- O guard do consumer ganhou `&& !m_cacheUI`
  ([graphicalapplication.cpp:251-255](src/framework/core/graphicalapplication.cpp#L251-L255)):
  com o cache ligado o consumer reusa a fila e nunca bloqueia esperando um build fresco
  (evita livelock contra a back-pressure do mapa); o refresh é garantido em ≤16ms.

### Toggle em runtime (A/B)

Exposto como `g_app.setCacheUI(bool)` / `g_app.isCacheUI()`, atômico, **default ON**. O
setter força um repaint ao religar.
([graphicalapplication.h:50-52](src/framework/core/graphicalapplication.h#L50-L52),
binding em [luafunctions.cpp:324-325](src/framework/luafunctions.cpp#L324-L325))

```lua
g_app.setCacheUI(false)  -- reverte Fase 1 + 2b em runtime (volta ao comportamento antigo)
g_app.setCacheUI(true)   -- religa (default)
```

### Resultados (hunt real, medidos via g_stats + GFXPERF)

- `DrawSecondForeground`: **72% → 16%** do render thread.
- `Wait` do render thread: 3% → **50%** (recuperou metade da capacidade).
- Draw-calls por frame: **265 → 26**.
- **fps mínimo: 0 → 178** (os *hitches* sumiram).
- UI re-rasterizada apenas ~8 a cada 120 frames.
- Fase 2b validada pelo usuário: *"melhorou o fps pra caramba"*, sem freeze, input crisp.
- UI visualmente idêntica (risco cosmético residual conhecido: possível double-blend de
  alpha em texto AA — não perceptível).

---

## 2) Battle list — só reconstruir janelas visíveis (Lua)

**Arquivo:** [battle.lua](modules/game_battle/battle.lua) (`checkCreatures`)

### O problema (gargalo #1 de Lua na hunt)

Medido via instrumentação: `checkCreatures` rodava **~570–805 ms a cada 20 s** com só
5–15 criaturas em tela (até 29 ms por call). Os bot loops (helper/cavebot/scripting) eram
desprezíveis (~0 ms) — **não** eram o problema.

**Causa-raiz:** `maxBattleWindow = 21` → 21 `BattleClass` são criadas no init (1 primária +
20 secundárias fechadas). O `checkCreatures` (a cada 100ms) chamava `updateBattleCreatures`
para **TODAS as 21** janelas: filtro `doCreatureFitFilters` por spectator +
`sortCreaturesForBattle` + `creatureSetup` por botão, e **cria 30 botões por janela** na
1ª chamada (630 botões no boot). ~20 janelas que o player nunca abriu eram reconstruídas
10×/s à toa. Veja o corpo de `updateBattleCreatures` em
[battle.lua:356-427](modules/game_battle/battle.lua#L356-L427).

### O conserto (otimizar o código, NÃO atrasar — o throttle foi rejeitado)

Em `checkCreatures`, só reconstruir as janelas que estão **abertas**
([battle.lua:468-478](modules/game_battle/battle.lua#L468-L478)):

```lua
for _, battle in pairs(battleClasses) do
  -- A janela PRIMÁRIA (battle.secondary == false) é sempre reconstruída, então nunca fica
  -- stale mesmo que uma mini-janela docada reporte isVisible() enganoso. As ~20
  -- SECUNDÁRIAS só são reconstruídas enquanto realmente abertas; uma recém-aberta se
  -- atualiza no próximo tick (<=100ms). O targeter/helper usam scan próprio, não este
  -- painel, então nada depende das fechadas estarem atualizadas.
  if not battle.secondary or (battle.window and battle.window:isVisible()) then
    updateBattleCreatures(battle, spectators, player)
  end
end
```

Isso corta de 21 → ~1 janela por tick (≈20×). Detalhes importantes:

- A **primária** (`secondary == false`) **sempre** atualiza — nunca fica stale, mesmo se
  uma mini-janela docada reportar `isVisible()` falso (lição aprendida no boss tracker).
- As **secundárias** só quando visíveis; uma recém-aberta se atualiza no próximo tick.
- `updateBattleButtons` / `clearBattlePanels` já eram baratos (pulam botões hidden).
- **Per-botão já estava ok:** `updateLifeBarPercent` / `updateManaBarPercent` /
  `updateSkull` / `updateIcons` têm dirty-check (pulam se nada mudou).

### Histórico: o experimento de throttle (revertido)

Numa branch anterior houve uma tentativa de **throttle** (`bb862ab`): subir
`battleUpdateInterval` de 100→300ms + pular o scan se o player não tivesse se movido
(`lastCheckPosition`). Isso foi **descartado** porque introduzia atraso perceptível na
battle list. A solução final mantém o intervalo em **100ms**
([battle.lua:12](modules/game_battle/battle.lua#L12)) e otimiza o trabalho em si
(só-visíveis), sem nenhum atraso.

### Resultado

`checkCreatures` deixou de reconstruir ~21 janelas por tick e passa a tocar só ~1. Era o
maior consumidor de Lua na hunt; eliminado sem custo de latência.

---

## Otimizações secundárias

### Texto do mapa retornado por referência (C++)
**Commit `6498168`** — [map.h](src/client/map.h)
`Map::getAnimatedTexts()` / `getStaticTexts()` retornavam `std::vector` **por valor**,
copiando o vetor inteiro todo frame em `MapView::drawMapForeground`. Como são iterados
read-only e não estão bindados em Lua, passaram a retornar `const&`:

```cpp
const std::vector<AnimatedTextPtr>& getAnimatedTexts() { return m_animatedTexts; }
const std::vector<StaticTextPtr>&   getStaticTexts()   { return m_staticTexts; }
```

### Otimizações de walking (Lua)
**Commit `7610a08`** — [walking.lua](modules/game_walking/walking.lua)
Removeu `g_game.setWalkProtection(true/false)` do `smartWalk`/`onWalkFinish`, código morto
(`autoWalkAttempts`, `nextAutoWalkAttempt`, `previousStoppedAutoWalkPos`) e um
`insertLuaCall("onFocusChange")` redundante; passou a conectar `onPositionChange`.

### Infra de frame/threading (C++)
**Commit `57f6904`** — adicionou `adaptativeframecounter.cpp/.h`, `BS_thread_pool.hpp` e
`spinlock.h` ao framework (base para o pipeline producer/consumer usado pelo cache de UI),
além de carregar o mapa da cyclopedia/bestiary de arquivo e renomear `vc17 → vc23`.

---

## Como validar / ligar-desligar

- **Cache de UI:** ligado por padrão. Para comparar A/B em runtime no terminal Lua do
  client: `g_app.setCacheUI(false)` (antigo) vs `g_app.setCacheUI(true)` (otimizado).
- **Profiling do engine:** dumps de `g_stats` são salvos a cada 60s em
  `%APPDATA%\NyxosClient\nyxos-client\profiler\session_*.log` (custo por-pass do render e
  da main thread). A instrumentação temporária `[GFXPERF]` e o utilitário `Perf` em Lua
  foram **removidos** após validar os ganhos — os fixes permanecem.
- **Build de dev:** compilar só a config **DirectX x64** (a que o usuário roda).

---

## Resumo de arquivos tocados

| Arquivo | Otimização |
| --- | --- |
| [src/framework/core/graphicalapplication.cpp](src/framework/core/graphicalapplication.cpp) | Cache de FB da UI (Fase 1) + throttle do build (Fase 2b) + invalidação por input |
| [src/framework/core/graphicalapplication.h](src/framework/core/graphicalapplication.h) | `m_uiFramebuffer`, `m_cacheUI`/`m_mustRepaint` (atomic), `setCacheUI`/`isCacheUI` |
| [src/framework/luafunctions.cpp](src/framework/luafunctions.cpp) | Binding `g_app.setCacheUI` / `g_app.isCacheUI` |
| [modules/game_battle/battle.lua](modules/game_battle/battle.lua) | `checkCreatures` só reconstrói janelas visíveis |
| [src/client/map.h](src/client/map.h) | Texto do mapa por `const&` (sem cópia por frame) |
| [modules/game_walking/walking.lua](modules/game_walking/walking.lua) | Remoção de walk-protection / código morto |
