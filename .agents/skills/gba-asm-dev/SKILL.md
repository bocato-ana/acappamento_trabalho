---
name: gba-asm-dev
description: Continue developing this GBA ARM7TDMI assembly game. Use when adding gameplay, minigame logic, sprites, backgrounds, OAM/VRAM changes, or building jogo.gba.
---

# GBA Assembly Game Development

Work within this repo's GBA Mode 3 ARM7TDMI architecture. Keep all changes **conflict-free** across VRAM, OAM, palette banks, and loop registers.

## Steps

### 1. Inspect Contracts and Memory Map
Before editing `.s` files, check the affected routines and consult [REFERENCE.md](REFERENCE.md) whenever touching VRAM offsets, OAM slots, palette banks, DMA3 transfers, or asset formats.

**Done when:** Every register, OAM index, VRAM address, and palette bank used by your change is accounted for and non-overlapping.

### 2. Implement in ARM Assembly
- **Section placement:** Put performance-critical or per-frame routines in `.section .iwram, "ax", %progbits` and static assets in `.section .rodata`.
- **Cross-section calls:** Call `.iwram` routines from `.text` (ROM) using `CHAMA rotina` (`ldr r8, =\rotina; mov lr, pc; bx r8`), because `bl` cannot span the ROM (`0x08...`) to IWRAM (`0x03...`) gap. Use `bl` only for calls within the same section.
- **Register preservation:** `main.s` holds live state in `r4` (interaction state `0..2`), `r11` (player X), and `r12` (player Y) across `game_loop`. Any routine called from `game_loop` that modifies `r4`–`r12` must `push`/`pop` them (note: `r12` is caller-saved in AAPCS, so explicitly push `r12` if used as a persistent coordinate).
- **Mode 3 background vs OBJ:** Keep per-frame movement strictly in OAM (`0x07000000`). Write to the 240x160 BG2 framebuffer (`0x06000000`) only on state transitions or scene loads via DMA3 (`REG_DMA3SAD = 0x040000D4`).
- **Input & VBlank:** Poll `REG_VCOUNT` (`0x04000006`) against `160` (exit VBlank, then enter VBlank). Read `REG_KEYINPUT` (`0x04000130`) as active-low (`0` = pressed).

**Done when:** Every new routine has a `.global` symbol if cross-file, a `.pool` directive after its literal-loading functions, and preserves all live loop registers.

### 3. Build and Verify
Compile and link all `.s` files into `jogo.elf` and `jogo.gba` using the command in `.vscode/tasks.json` (updating the `devkitPro` path if running on a different machine):

```powershell
arm-none-eabi-gcc -mcpu=arm7tdmi -specs=<DEVKITARM>/arm-none-eabi/lib/gba.specs main.s minijogo.s sprite_raquete.s barraca_map.s cenario_map.s caixa_texto.s sprite_monitor.s sprite_jogador_obj.s -o jogo.elf && arm-none-eabi-objcopy -O binary jogo.elf jogo.gba
```

Add any new `.s` files to both the build command and `.vscode/tasks.json`.

**Done when:** `arm-none-eabi-gcc` and `arm-none-eabi-objcopy` exit with code `0`, producing an updated `jogo.elf` and `jogo.gba`, and every modified OAM/VRAM/palette slot is verified conflict-free.
