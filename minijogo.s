@ =====================================================================
@  minijogo.s  -  tela secundária (barraca) com a RAQUETE
@  Roda em loop próprio e retorna quando o jogador aperta B.
@ =====================================================================

.equ REG_KEYINPUT,   0x04000130
.equ REG_VCOUNT,     0x04000006
.equ REG_DMA3SAD,    0x040000D4
.equ VRAM,           0x06000000
.equ OAM,            0x07000000
.equ OBJ_PALETTE,    0x05000200
.equ SCREEN_H,       160
.equ KEY_A,          0x0001
.equ KEY_B,          0x0002
.equ KEY_RIGHT,      0x0010
.equ KEY_LEFT,       0x0020
.equ KEY_UP,         0x0040
.equ KEY_DOWN,       0x0080
.equ DMA_CENARIO,    0x84004B00      @ 19200 words = 240x160 16bpp

@ --- Raquete (gerada pelo converter_raquete.py) ---
.equ RAQ_W,          32
.equ RAQ_H,          64
.equ RAQ_SHAPE,      2            @ 2 = vertical
.equ RAQ_SIZE,       3            @ 3 = 32x64
.equ RAQ_NTILES,     32
.equ RAQ_START,      0            @ tiles começam no início de raqueteTiles
.equ RAQ_VRAM,       0x06016000   @ depois do jogador e da seta
.equ RAQ_TILE_INDEX, 768          @ (0x06016000 - 0x06010000) / 32
.equ RAQ_PAL_BANK,   14           @ entradas 224-239 da paleta de OBJ
.equ RAQ_PAL_ADDR,   (OBJ_PALETTE + RAQ_PAL_BANK * 32)

.equ MAX_X,          (240 - RAQ_W)
.equ MAX_Y,          (160 - RAQ_H)

.section .iwram, "ax", %progbits
.arm
.align 2

.global iniciar_minijogo
iniciar_minijogo:
    push {r4-r11, lr}               @ Preserva r4 (estado) e r11/r12 (posição)

    @ --- Espera soltar A (evita que o mesmo toque dispare outra ação) ---
    ldr  r0, =REG_KEYINPUT
1:  ldrh r1, [r0]
    tst  r1, #KEY_A
    beq  1b

    @ --- Desenha a barraca no BG2 (sobrescreve o mundo) ---
    ldr  r0, =REG_DMA3SAD
    ldr  r1, =barraca_map
    ldr  r2, =VRAM
    ldr  r3, =DMA_CENARIO
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop

    @ --- Limpa a OAM (some com NPC, seta e jogador) ---
    bl   inicializar_oam

    @ --- Tiles da raquete (4bpp, 8 palavras por tile, 32 bits) ---
    ldr  r0, =REG_DMA3SAD
    ldr  r1, =raqueteTiles
    ldr  r4, =(RAQ_START * 32)
    add  r1, r1, r4
    ldr  r2, =RAQ_VRAM
    ldr  r3, =(0x84000000 | (RAQ_NTILES * 8))
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop

    @ --- Paleta da raquete (16 cores, 16 bits) no banco RAQ_PAL_BANK ---
    ldr  r1, =raquetePal
    ldr  r2, =RAQ_PAL_ADDR
    ldr  r3, =(0x80000000 | 16)
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop

    mov  r11, #100                  @ Posição inicial da raquete
    mov  r12, #60

@ ---------------- LOOP DO MINIJOGO ----------------
loop_minijogo:
    ldr  r0, =REG_VCOUNT
2:  ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    bge  2b
3:  ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    blt  3b

    ldr  r0, =REG_KEYINPUT
    ldrh r1, [r0]

    tst  r1, #KEY_B                 @ B = sair do minijogo
    beq  sair_minijogo

    @ --- Movimento da raquete (mesma lógica do jogador) ---
    tst  r1, #KEY_UP
    subeq r12, r12, #1
    tst  r1, #KEY_DOWN
    addeq r12, r12, #1
    tst  r1, #KEY_LEFT
    subeq r11, r11, #1
    tst  r1, #KEY_RIGHT
    addeq r11, r11, #1

    cmp  r11, #0
    movlt r11, #0
    cmp  r11, #MAX_X
    movgt r11, #MAX_X
    cmp  r12, #0
    movlt r12, #0
    cmp  r12, #MAX_Y
    movgt r12, #MAX_Y

    mov  r0, r11
    mov  r1, r12
    bl   atualizar_raquete_obj

    @ =====================================================
    @  SUA LÓGICA DO MINIJOGO VAI AQUI
    @  (ex.: checar colisão com itens, contar pontos, timer)
    @ =====================================================

    b    loop_minijogo

sair_minijogo:
    ldr  r0, =REG_KEYINPUT
4:  ldrh r1, [r0]                   @ Espera soltar B antes de voltar
    tst  r1, #KEY_B
    beq  4b
    pop  {r4-r11, pc}

@ ---------------------------------------------------------------------
@ OAM: raquete = objeto 0 (4bpp). r0 = X, r1 = Y
@ ---------------------------------------------------------------------

atualizar_raquete_obj:
    ldr  r2, =OAM

    and  r3, r1, #0xFF              @ Attr0: Y + forma (4bpp: bit 13 = 0)
    ldr  r1, =(RAQ_SHAPE << 14)
    orr  r3, r3, r1
    strh r3, [r2]

    mov  r3, r0, lsl #23            @ Attr1: mantém só os 9 bits de X
    mov  r3, r3, lsr #23
    ldr  r1, =(RAQ_SIZE << 14)
    orr  r3, r3, r1
    strh r3, [r2, #2]

    ldr  r3, =(RAQ_TILE_INDEX | (RAQ_PAL_BANK << 12))   @ Attr2: tile + banco
    strh r3, [r2, #4]
    bx   lr

.pool
