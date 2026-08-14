# TODO — Client

> As imagens citadas abaixo são capturas do cliente oficial, mantidas fora do
> repositório. Cada item descreve o que comparar.

## Geral / Branding
- [ ] Corrigir diferenças de cor na janela principal

## Minimapa
- [x] Persistir a área explorada (`saveOtmm` no logout, no fechamento e autosave de 5min,
      gravando em `%APPDATA%\NyxosClient\Nyxos\minimap.otmm`)
- [x] Remover o `data/minimap.otmm` empacotado — era de outro mapa (blocos em x/y < 6336
      contra o mundo em ~32000), nunca teve como aparecer
- [ ] Botão "Download Minimap" dentro do próprio minimapa: baixa o minimapa completo
      para a pasta certa, com barra de progresso no lugar do botão
- [x] **MAJOR:** Nova funcionalidade — Janela de Diálogo Cip (Cip Dialogue Window) — conferir `New Feature Cip Dialogue Window.png`

## Menu Interface
- [ ] Exibir cursor do mouse animado (Show Animated Mouse Cursor)
- [ ] Exibir cursor do mouse grande (Show Big Mouse Cursor)

## Menu HUD
> Provavelmente relacionado aos monges (monks)
- [ ] Exibir Harmony (com opções selecionáveis abaixo*)
  - [ ] Próximo ao arco de vida (Next to Health Arc)
  - [ ] Próximo ao arco de mana (Next to Mana Arc)

## Menu Janela do Jogo (Game Window)
- [ ] Exibir animação de ataque corpo a corpo (Show Melee Attack Animation)
- [ ] Exibir banner de informações (Show Info Banner)

## Menu Barras de Ação (Action Bars)
- [x] Auto-inserir novas magias (Auto-Insert New Spells)
- [x] Alterar o menu "Control Buttons" para "Shortcuts" (mudança de rótulo do botão)
- [x] Adicionar botão de menu de Som (Sound)

## Menu Diversos (Misc.)
- [x] Perguntar antes de organizar containers aninhados (Ask Before Sorting Nested Containers)
- [x] Perguntar antes de mover conteúdo de containers aninhados (Ask Before Moving Contents of Nested Containers)
- [ ] Usar renderizador de fonte alternativo (Use Alternate Font Renderer)
- [ ] Adicionar o submenu de Screenshots dentro do Menu Gameplay (conferir print oficial na pasta citada acima)

## Menu Gameplay
- [x] Adicionar botão de menu de Ajuda (Help) — conferir print citado acima
- [ ] Implementar completamente o Menu Task Board (Task Board Menu)
- [ ] Popular o Compêndio (Compendium)
- [ ] Ajustar o widget de Pontos Injustificados (Unjustified Points) — conferir print oficial e o atual para comparação e entender o que precisa mudar
- [ ] Ajustar Diálogo de Prey — sprites das criaturas não estão reproduzindo animações

## Store — desacoplar do myAAC
> Mesma causa da Boosted Creatures: hoje a Store depende do myAAC para os assets
> (gifs de itens/criaturas) e para os dados de oferta. Confirmar o motivo exato na wiki.
- [ ] Tornar a Store 100% client-side, sem depender do site
- [ ] Construir um gerenciador de Store para editar vendas/promoções
- [ ] Ligar os sons `STORE_ANIMATION_RATTLING` (2780) e `STORE_ANIMATION_BUY` (2781) quando a Store voltar a funcionar
