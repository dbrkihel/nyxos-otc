# Skills — Combat Stats (estado atual + roadmap de enriquecimento)

## Estado atual (FEITO)

A aba **Skills** já apresenta os mesmos campos de combate do Tibia global, com **decimais**:

- Damage/Healing, Attack Value
- Life Leech, Mana Leech, Critical Hit (Chance + Extra Damage), Onslaught
- Resistências elementais (Physical … Agony)
- Defence Value, Armor Value, Mantra Value, Mitigation
- Dodge, Momentum, Transcendence, Amplification

Cada campo aparece quando o valor é `> 0` (igual ao global) e popula no **login**.

### Como funciona (pipeline atual)

1. **Servidor** manda tudo no pacote **0xA1** (`AddPlayerSkills`, server `protocolgame.cpp`).
2. **Client** `ProtocolGame::parsePlayerSkillsModern` (`src/client/protocolgameparse.cpp`)
   captura os valores (decode do `addDouble`: `(scaled - INT32_MAX) / 10^precision`;
   frações × 100 = %, exceto mitigation que já vem em %), guarda os "special skills"
   no LocalPlayer (`m_specialSkills`, chaves = ids do `Skill` em `gamelib/const.lua`) e
   dispara, **no objeto do player**, `callLuaField`:
   - `onUpdateOffenceStats(player, damageAndHealing, attackValue, attackElement, converted, convElem)`
   - `onUpdateDefenceStats(player, resistências[12], defense, armor, mantra, mitigation, reflection)`
   - `onUpdateMiscStats(player)`
3. **`modules/game_skills/skills.lua`** (já existia) consome esses eventos; helper
   `fmtPct` formata os decimais. Widgets escondem quando 0.

> ⚠️ Os eventos `onUpdate*Stats` são conectados em `connect(LocalPlayer, {...})`, então
> têm que ser disparados via `m_localPlayer->callLuaField(...)` (NÃO `callGlobalField("g_game", ...)`).

---

## Roadmap de enriquecimento (A FAZER)

> Objetivo: o player entender **de onde vem** cada proteção/bônus — breakdown por fonte,
> estilo Cyclopedia. Fenomenal pra build-crafting.

### 1. Tooltips com breakdown por fonte (prioridade)

Para cada stat de combate, mostrar no tooltip a decomposição:

```
Critical Hit Chance: +35.7%
  ├─ Flat Bonus:        +X%
  ├─ Equipment:         +X%
  ├─ Imbuement:         +X%
  ├─ Wheel of Destiny:  +X%
  └─ Concoction:        +X%
```

Mesma ideia para Life/Mana Leech, Onslaught, e (idealmente) as resistências elementais
(de onde vem cada resistência: armor, imbuement, etc.).

### 2. O dado JÁ EXISTE no servidor (sem mexer no server!)

O servidor já serializa esse breakdown em **`addCyclopediaSkills`** (server
`protocolgame.cpp`, ~linha 365-430), enviado no pacote de **Cyclopedia Character Info /
Combat Stats**. Por skill ele manda como `addDouble(... / 10000.)`:

- **Total Bonus**
- **Flat Bonus** (só Critical Chance/Damage)
- **Equipment Bonus**
- **Imbuement Bonus**
- **Wheel Bonus** (Wheel of Destiny)
- **Event Bonus** (leech) / **Concoction Bonus** (crit)

Ou seja: o enriquecimento é **client-only** — parsear esse pacote da Cyclopedia e montar
os tooltips. Decode dos doubles = igual ao 0xA1.

### 3. Onde mexer (client)

- **Parse**: o handler do pacote de Cyclopedia character-info (procurar onde
  `parseCyclopediaCharacterInfo` / a aba "Combat Stats" da Cyclopedia é parseada em
  `protocolgameparse.cpp`; ver também `mods/game_cyclopedia/cyclopediaprotocol.lua` e
  `classes/character.lua`, que já têm referências a `criticalChance.fromEquipment`,
  `fromImbuement`, `fromSkillWheel`, `fromConcoction`).
- **Storage**: guardar o breakdown por skill (ex.: estender `m_specialSkills` para um
  struct {total, flat, equipment, imbuement, wheel, concoction} OU um segundo map).
- **UI**: enriquecer os tooltips em `modules/game_skills/skills.lua` (`specialTooltips`)
  com as linhas de breakdown.

### 4. Extras (depois do breakdown)

- Resistências: breakdown por fonte (armor/imbuement/charm/etc.) por elemento.
- Mostrar valores absolutos além do %, onde fizer sentido.
- Formatar Damage/Healing e Attack com separador de milhar (ex.: "7,610").

---

## Referências

- Decode/encoding e layout do 0xA1: ver memória `skills-combat-stats-wiring`.
- Server source: `src/server/network/protocol/protocolgame.cpp`
  (`AddPlayerSkills` ≈ 9463; `addCyclopediaSkills` ≈ 365-430).
