# GBA Game Architecture & Memory Reference

Primary reference for `acappamento_trabalho` (GBA Mode 3, ARM7TDMI, devkitARM).

## 1. File Inventory

| File | Section | Role & Exported Symbols |
| :--- | :--- | :--- |
| `main.s` | `.text`, `.iwram`, `.data` | Entry `main`, `game_loop`, NPC proximity state machine (`r4`), IWRAM OAM/DMA/sprite routines, inline `seta_tile` (8x8 4bpp), `frame_contador` |
| `minijogo.s` | `.iwram` | `iniciar_minijogo` (tent/barraca minigame loop, exits on `KEY_B`), `atualizar_raquete_obj` |
| `cenario_map.s` | `.rodata` | `cenario_map`: 240x160 16bpp RGB555 overworld background |
| `barraca_map.s` | `.rodata` | `barraca_map`: 240x160 16bpp RGB555 tent background |
| `sprite_monitor.s` | `.rodata` | `sprite_monitor`: `.hword 44, 40` header + 16bpp RGB555 pixels (`0x7C1F` magenta = transparent) |
| `caixa_texto.s` | `.rodata` | `caixa_texto`: `.hword 200, 42` header + 16bpp RGB555 pixels |
| `sprite_jogador_obj.s` | `.rodata` | `sprite_jogador_obj_tiles` (64x64 8bpp, 4096 B), `sprite_jogador_obj_palette` (124 hwords), `sprite_jogador_obj_palette_count` |
| `sprite_raquete.s` | `.rodata` | `raqueteTiles` (32x64 4bpp, 32 tiles = 1024 B), `raquetePal` (16 hwords) |

## 2. Mode 3 VRAM, OAM, and Palette Map

In Mode 3 (`REG_DISPCNT = 0x1443`: Mode 3 + BG2 + OBJ + 1D mapping), `0x06000000–0x06013FFF` holds the 240x160x16bpp framebuffer (`76,800` bytes). **OBJ tiles start at `0x06014000` (tile index `512`).**

### OBJ VRAM (`0x06014000–0x06017FFF`, 16 KB available)
Tile index formula (4bpp units): `(addr - 0x06010000) / 32`. Note that 8bpp tiles occupy 64 bytes (2 tile-index units per tile).

| Address Range | Tile Index | Size | Owner |
| :--- | :--- | :--- | :--- |
| `0x06014000–0x06014FFF` | `512` | 4096 B | Player (`64x64` 8bpp, 40x48 art padded) |
| `0x06015000–0x0601501F` | `640` | 32 B | Floating arrow (`8x8` 4bpp) |
| `0x06016000–0x060163FF` | `768` | 1024 B | Racket (`32x64` 4bpp, 32 tiles, minigame only) |
| `0x06016400–0x06017FFF` | `800–1023` | 7168 B | **Free** for new OBJ sprites |

### OBJ Palette (`0x05000200`, 256 RGB555 colors = 512 B)
- **Entries `0–123` (`0x05000200–0x050002F7`):** Player 8bpp palette (index `0` transparent).
- **Entries `124–223` (`Banks 8–13` safe for 4bpp):** **Free** (avoid overlapping `0–123` if player is visible).
- **Bank `14` (`entries 224–239`, `0x050003C0`):** Racket 4bpp palette (16 colors).
- **Bank `15` (`entries 240–255`, `0x050003E0`):** Arrow 4bpp palette (`0`=transparent, `1`=`0x0000` black, `2`=`0x03FF` yellow).

### OAM (`0x07000000`, 128 entries × 8 bytes)
- **`OBJ 0` (`OAM + 0`):** Player (overworld) or Racket (minigame).
- **`OBJ 1` (`OAM + 8`):** Floating NPC arrow (overworld).
- **`OBJ 2–127` (`OAM + 16..`):** **Free**. Call `inicializar_oam` to disable all 128 entries (`Attr0 = 0x200`) before enabling specific OBJs.

## 3. Hardware, ISA (ARMv4T), and Asset Conventions

- **ARMv4T ISA (`-mcpu=arm7tdmi`, 16.78 MHz / ~280k cycles per 59.73 Hz frame):**
  - **No `blx` (ARMv5+):** Use `mov lr, pc; bx r8` (via `CHAMA`) for indirect/long calls.
  - **No `movw`/`movt` (ARMv6T2+):** Load 32-bit constants with `ldr rX, =imm` and place `.pool` within ±4 KB.
  - **No hardware division (`udiv`/`sdiv`):** Use bit-shifts for powers of 2, or BIOS `swi 0x06` (`Div`) / a software loop.
  - **Bus widths:** IWRAM (`0x03000000`) is 32-bit 0-waitstate (ideal for `.arm` hot loops); ROM (`0x08000000`) is 16-bit with waitstates.
- **RGB555 format:** `0b0BBBBBGGGGGRRRRR` (bit 15 unused; `0x7C1F` = magenta transparency key for `desenhar_sprite`).
- **DMA3 (`REG_DMA3SAD = 0x040000D4`, `DAD = +4`, `CNT = +8`):**
  - Full-screen 32-bit copy: `0x84004B00` (Enable | 32-bit | 19,200 words).
  - Line-by-line 16-bit copy (`apagar_retangulo`, `desenhar_caixa_dialogo`): `0x80000000 | width_pixels`.
- **OAM Attributes (halfwords):**
  - `Attr0`: bits `0–7` = Y, bit `9` (`0x200`) = disable, bit `13` (`0x2000`) = 8bpp (`0` = 4bpp), bits `14–15` = shape (`0`=square, `1`=wide, `2`=tall).
  - `Attr1`: bits `0–8` = X, bits `14–15` = size (`0..3`; e.g., `3` with square = `64x64`, `3` with tall = `32x64`).
  - `Attr2`: bits `0–9` = base tile index, bits `12–15` = 4bpp palette bank (`0` for 8bpp).

## 4. Known Issues & Unfinished Areas

1. **`minijogo.s` clobbers `r12`:** `iniciar_minijogo` pushes `{r4-r11, lr}` and overwrites `r12` with `#60` (racket Y), corrupting `main.s`'s player Y (`r12`) on return. Fix by saving/restoring `r12` (or moving player/racket coordinates to `.data`/`.bss` variables).
2. **Minigame gameplay (`minijogo.s` lines 129–132):** Only racket movement and `KEY_B` exit are implemented; falling/bouncing items, AABB collision, score, and timer are unimplemented.
3. **Overworld features (`main.s`):** Single static NPC (`NPC_X=55, NPC_Y=35`), single static dialog image (`caixa_texto`), no map collision bounds beyond screen edges (`0..200`, `0..112`), no player walk animation, and no audio.
4. **Build path (`.vscode/tasks.json`):** Hardcodes `C:/Users/analu/devkitPro/devkitARM/bin/...`; adjust if devkitPro is installed elsewhere.
