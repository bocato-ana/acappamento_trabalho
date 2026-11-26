# Acappamento (GBA)

Jogo desenvolvido em **Assembly ARM** para **Game Boy Advance (GBA)**, utilizando renderização em **Modo 3 (Bitmap)** com sprites via **OAM (OBJ)**, interação com NPC, caixa de diálogo e minijogos (barraca e pesca).

## Tecnologias Utilizadas

- **Linguagem:** Assembly ARM (`arm7tdmi`)
- **Toolchain:** [devkitPro](https://devkitpro.org/) / **devkitARM** (`arm-none-eabi-gcc`, `arm-none-eabi-objcopy`)
- **Linkagem / Runtime GBA:** `gba.specs`
- **Emulador:** [mGBA](https://mgba.io/)
- **Recursos de Hardware GBA utilizados:**
  - **Modo 3 (`DISPCNT_MODE3_BG2_OBJ`)**: Framebuffer bitmap 240×160 (`BG2`) para cenários, NPC e caixas de texto
  - **OAM / OBJ**: Sprites em hardware para jogador, seta interativa, raquete, mosquito e pesca
  - **DMA3 (`REG_DMA3SAD`)**: Transferência rápida de dados para a VRAM
  - **VBlank (`REG_VCOUNT`)**: Sincronização de quadros (frame sync)
  - **Entrada (`REG_KEYINPUT`)**: Leitura dos botões direcionais e botão `A`

## Estrutura do Projeto

- `main.s` — Loop principal, controle de estado, movimentação do jogador, interação com NPC e transição para os minijogos
- `minijogo.s` — Lógica do minijogo da barraca
- `pesca.s`, `pesca_map.s`, `pesca_msgs.s`, `pesca_sprites.s` — Lógica, mapa, mensagens e sprites do minijogo de pesca
- `cenario_map.s`, `barraca_map.s` — Mapas/cenários em bitmap
- `caixa_texto.s` — Renderização da caixa de diálogo
- `contador.s`, `ficheiro_pontuacao.s` — Contagem e pontuação
- `sprite_jogador_obj.s`, `sprite_monitor.s`, `sprite_raquete.s`, `mosquito_sprite.s` — Dados e rotinas de sprites
- `.vscode/tasks.json` — Tarefa de build configurada para o VS Code

## Como Compilar

### Pré-requisitos

1. Instale o **devkitPro** (com o componente **GBA Development / devkitARM**) em `C:/Users/analu/devkitPro` (ou ajuste o caminho em `.vscode/tasks.json` caso tenha instalado em outro diretório).
2. Instale o emulador **mGBA** para executar a ROM gerada.

### Opção 1: Pelo VS Code (Recomendado)

1. Abra a pasta do projeto no VS Code.
2. Execute a tarefa de build padrão (`Ctrl+Shift+B`) — ela executará a task **Compilar GBA** definida em `.vscode/tasks.json`.
3. Ao final, serão gerados os arquivos `jogo.elf` e `jogo.gba` na raiz do projeto.

### Opção 2: Pelo Terminal (PowerShell)

Na raiz do projeto, execute:

```powershell
C:/Users/analu/devkitPro/devkitARM/bin/arm-none-eabi-gcc -mcpu=arm7tdmi -specs=C:/Users/analu/devkitPro/devkitARM/arm-none-eabi/lib/gba.specs main.s minijogo.s contador.s ficheiro_pontuacao.s mosquito_sprite.s pesca.s pesca_sprites.s pesca_msgs.s pesca_map.s sprite_raquete.s barraca_map.s cenario_map.s caixa_texto.s sprite_monitor.s sprite_jogador_obj.s -o jogo.elf
if ($?) { C:/Users/analu/devkitPro/devkitARM/bin/arm-none-eabi-objcopy -O binary jogo.elf jogo.gba }
```

## Como Executar

1. Abra o **mGBA**.
2. Carregue o arquivo `jogo.gba` gerado na raiz do projeto.
3. Use as setas direcionais para mover o personagem e a tecla **X** (botão `A` do GBA) para interagir.
