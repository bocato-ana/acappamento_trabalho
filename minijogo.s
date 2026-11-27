@ =====================================================================
@  minijogo.s  -  tela secundária (barraca): RAQUETE + MOSQUITO
@  Roda em loop próprio e retorna quando o jogador aperta B,
@  vence (pontuação >= meta) ou o tempo acaba.
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

@ --- Raquete ---
.equ RAQ_W,          32
.equ RAQ_H,          64
.equ RAQ_SHAPE,      2            @ 2 = vertical
.equ RAQ_SIZE,       3            @ 3 = 32x64
.equ RAQ_NTILES,     32
.equ RAQ_START,      0
.equ RAQ_VRAM,       0x06016000
.equ RAQ_TILE_INDEX, 768          @ (0x06016000 - 0x06010000) / 32
.equ RAQ_PAL_BANK,   14
.equ RAQ_PAL_ADDR,   (OBJ_PALETTE + RAQ_PAL_BANK * 32)

.equ MAX_X,          (240 - RAQ_W)
.equ MAX_Y,          (160 - RAQ_H)

@ --- Mosquito (64x64, OBJ 4bpp) ---
.equ MOS_W,          64
.equ MOS_H,          64
.equ MOS_SHAPE,      0            @ Quadrado
.equ MOS_SIZE,       3            @ 64x64
.equ MOS_NTILES,     64
.equ MOS_VRAM,       0x06016400
.equ MOS_TILE_INDEX, 800          @ (0x06016400 - 0x06010000) / 32
.equ MOS_PAL_BANK,   13
.equ MOS_PAL_ADDR,   (OBJ_PALETTE + MOS_PAL_BANK * 32)

.equ TEMPO_INICIAL,  1800         @ 30 segundos a 60 fps

@ =====================================================================
@  VARIÁVEIS (ficam em .data / IWRAM)
@ =====================================================================
.data
.align 2
.global pontuacao
.global tempo_frames

pontuacao:        .word 0
meta_pontuacao:   .word 10
tempo_frames:     .word TEMPO_INICIAL
estado_minijogo:  .word 0          @ 0=jogo, 1=vitoria, 2=tempo acabou
botaoA_anterior:  .word 0
tempo_sub:        .word 0          @ frames dentro do segundo atual (0-59)
mosquitoX:        .word 50
mosquitoY:        .word 40
mosquitoVX:       .word 1
mosquitoVY:       .word 1

@ =====================================================================
@  CÓDIGO (IWRAM)
@ =====================================================================
.section .iwram, "ax", %progbits
.arm
.align 2

.global iniciar_minijogo
iniciar_minijogo:
    push {r4-r12, lr}               @ Preserva r4-r12 (r11/r12 = posição do jogador no main)

    @ --- Espera soltar A ---
    ldr  r0, =REG_KEYINPUT
1:  ldrh r1, [r0]
    tst  r1, #KEY_A
    beq  1b

    @ --- Desenha a barraca no BG2 ---
    ldr  r0, =REG_DMA3SAD
    ldr  r1, =barraca_map
    ldr  r2, =VRAM
    ldr  r3, =DMA_CENARIO
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop

    @ --- Limpa a OAM ---
    bl   inicializar_oam

    @ --- Tiles da raquete ---
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

    @ --- Paleta da raquete ---
    ldr  r1, =raquetePal
    ldr  r2, =RAQ_PAL_ADDR
    ldr  r3, =(0x80000000 | 16)
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop

    @ --- Tiles do mosquito ---
    ldr  r1, =mosquitoTiles
    ldr  r2, =MOS_VRAM
    ldr  r3, =(0x84000000 | (MOS_NTILES * 8))
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop

    @ --- Paleta do mosquito ---
    ldr  r1, =mosquitoPal
    ldr  r2, =MOS_PAL_ADDR
    ldr  r3, =(0x80000000 | 16)
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop

    @ --- Posição inicial da raquete ---
    mov  r11, #100
    mov  r12, #60

    @ --- Reinicia variáveis do minijogo ---
    mov  r1, #0
    ldr  r0, =pontuacao
    str  r1, [r0]
    ldr  r0, =estado_minijogo
    str  r1, [r0]
    ldr  r0, =botaoA_anterior
    str  r1, [r0]
    ldr  r0, =tempo_sub
    str  r1, [r0]

    ldr  r0, =tempo_frames
    ldr  r1, =TEMPO_INICIAL
    str  r1, [r0]

    ldr  r0, =mosquitoX
    mov  r1, #50
    str  r1, [r0]
    ldr  r0, =mosquitoY
    mov  r1, #40
    str  r1, [r0]
    ldr  r0, =mosquitoVX
    mov  r1, #2
    str  r1, [r0]
    ldr  r0, =mosquitoVY
    str  r1, [r0]

    @ --- Desenha pontuação inicial (00) e tempo inicial (30) ---
    ldr  r3, =desenhar_pontuacao
    mov  lr, pc
    bx   r3
    ldr  r3, =desenhar_tempo
    mov  lr, pc
    bx   r3

@ ---------------- LOOP DO MINIJOGO ----------------
loop_minijogo:
    @ Sincroniza com o VBlank
    ldr  r0, =REG_VCOUNT
2:  ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    bge  2b
3:  ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    blt  3b

    @ Jogo já terminou?
    ldr  r0, =estado_minijogo
    ldr  r0, [r0]
    cmp  r0, #0
    bne  fim_minijogo

    @ Ler botões
    ldr  r0, =REG_KEYINPUT
    ldrh r1, [r0]

    tst  r1, #KEY_B                 @ B = sair
    beq  sair_minijogo

    @ Movimento da raquete
    tst  r1, #KEY_UP
    subeq r12, r12, #2
    tst  r1, #KEY_DOWN
    addeq r12, r12, #2
    tst  r1, #KEY_LEFT
    subeq r11, r11, #2
    tst  r1, #KEY_RIGHT
    addeq r11, r11, #2

    @ Limites da raquete
    cmp  r11, #0
    movlt r11, #0
    cmp  r11, #MAX_X
    movgt r11, #MAX_X
    cmp  r12, #0
    movlt r12, #0
    cmp  r12, #MAX_Y
    movgt r12, #MAX_Y

    @ Move o mosquito e desenha (OBJ 1)
    bl   movimentar_mosquitos

    ldr  r0, =mosquitoX
    ldr  r0, [r0]
    ldr  r1, =mosquitoY
    ldr  r1, [r1]
    mov  r2, #1
    bl   atualizar_mosquito_obj

    @ Tempo
    bl   atualizar_tempo

    @ Botão A (r1 = KEYINPUT)
    ldr  r0, =REG_KEYINPUT
    ldrh r1, [r0]
    bl   verificar_botao_A

    @ Ganhou ou perdeu?
    ldr  r0, =estado_minijogo
    ldr  r0, [r0]
    cmp  r0, #0
    bne  fim_minijogo

    @ Raquete (OBJ 0)
    mov  r0, r11
    mov  r1, r12
    bl   atualizar_raquete_obj

    b    loop_minijogo

@ ---------------- SAÍDAS ----------------
sair_minijogo:
    ldr  r0, =REG_KEYINPUT
4:  ldrh r1, [r0]                   @ Espera soltar B
    tst  r1, #KEY_B
    beq  4b

fim_minijogo:
    bl   esconder_mosquito
    pop  {r4-r12, pc}

@ ---------------------------------------------------------------------
@ Esconde o mosquito (OBJ 1)
@ ---------------------------------------------------------------------
esconder_mosquito:
    ldr  r0, =OAM
    mov  r1, #0x0200                @ bit 9 = OBJ desativado
    strh r1, [r0, #8]
    bx   lr

@ ---------------------------------------------------------------------
@ OAM: raquete = objeto 0 (4bpp). r0 = X, r1 = Y
@ ---------------------------------------------------------------------
atualizar_raquete_obj:
    ldr  r2, =OAM

    and  r3, r1, #0xFF
    ldr  r1, =(RAQ_SHAPE << 14)
    orr  r3, r3, r1
    strh r3, [r2]

    mov  r3, r0, lsl #23
    mov  r3, r3, lsr #23
    ldr  r1, =(RAQ_SIZE << 14)
    orr  r3, r3, r1
    strh r3, [r2, #2]

    ldr  r3, =(RAQ_TILE_INDEX | (RAQ_PAL_BANK << 12))
    strh r3, [r2, #4]
    bx   lr

@ ---------------------------------------------------------------------
@ OAM: mosquito. r0 = X, r1 = Y, r2 = índice do OBJ
@ ---------------------------------------------------------------------
atualizar_mosquito_obj:
    ldr  r3, =OAM
    add  r3, r3, r2, lsl #3         @ cada OBJ ocupa 8 bytes

    and  r2, r1, #0xFF
    ldr  r1, =(MOS_SHAPE << 14)
    orr  r2, r2, r1
    strh r2, [r3]

    mov  r2, r0, lsl #23
    mov  r2, r2, lsr #23
    ldr  r1, =(MOS_SIZE << 14)
    orr  r2, r2, r1
    strh r2, [r3, #2]

    ldr  r2, =(MOS_TILE_INDEX | (MOS_PAL_BANK << 12))
    strh r2, [r3, #4]
    bx   lr

.pool

@ ---------------------------------------------------------------------
@ Movimenta o mosquito (quica nas bordas)
@ ---------------------------------------------------------------------
movimentar_mosquitos:
    push {r4-r7, lr}

    @ ---- X ----
    ldr  r5, =mosquitoX
    ldr  r6, [r5]
    ldr  r7, =mosquitoVX
    ldr  r0, [r7]
    add  r6, r6, r0
    str  r6, [r5]

    cmp  r6, #0                     @ limite: 240 - 64 = 176
    ble  inverter_x
    cmp  r6, #176
    bge  inverter_x
    b    mover_y
inverter_x:
    ldr  r0, [r7]
    rsb  r0, r0, #0
    str  r0, [r7]

    @ ---- Y ----
mover_y:
    ldr  r5, =mosquitoY
    ldr  r6, [r5]
    ldr  r7, =mosquitoVY
    ldr  r0, [r7]
    add  r6, r6, r0
    str  r6, [r5]

    cmp  r6, #0                     @ limite: 160 - 64 = 96
    ble  inverter_y
    cmp  r6, #96
    bge  inverter_y
    b    mover_fim
inverter_y:
    ldr  r0, [r7]
    rsb  r0, r0, #0
    str  r0, [r7]

mover_fim:
    pop  {r4-r7, pc}

@ ---------------------------------------------------------------------
@ Colisão raquete x mosquito.  r11 = X, r12 = Y da raquete
@ Retorno r0 = 0 (acertou) ou -1
@ ---------------------------------------------------------------------
verificar_colisao:
    push {r4-r7, lr}

    @ parte mais central do mosquito 24x24
    @ Margem de 8 pixels em cada lado

    ldr  r5, =mosquitoX
    ldr  r6, [r5]
    add  r6, r6, #8                @ desloca a hitbox para dentro

    add  r7, r6, #24                @ direita do mosquito
    cmp  r7, r11
    ble  colisao_nenhuma

    add  r7, r11, #24               @ direita da raquete (hitbox 24)
    cmp  r6, r7
    bge  colisao_nenhuma

    ldr  r5, =mosquitoY
    ldr  r6, [r5]
    add  r6, r6, #8                 @ desloca a hitbox para dentro

    add  r7, r6, #24                @ baixo do mosquito
    cmp  r7, r12
    ble  colisao_nenhuma

    add  r7, r12, #24              @ baixo da raquete (hitbox 48)
    cmp  r6, r7
    bge  colisao_nenhuma

    mov  r0, #0
    b   colisao_fim


colisao_nenhuma:
    mvn  r0, #0

colisao_fim:
    pop  {r4-r7, pc}

@ ---------------------------------------------------------------------
@ Apanhou o mosquito: +1 ponto, redesenha, checa meta, reposiciona
@ ---------------------------------------------------------------------
apanhar_mosquito:
    push {r4-r7, lr}

    ldr  r0, =pontuacao
    ldr  r5, [r0]
    add  r5, r5, #1
    str  r5, [r0]

    ldr  r3, =desenhar_pontuacao
    mov  lr, pc
    bx   r3

    ldr  r0, =pontuacao
    ldr  r5, [r0]
    ldr  r0, =meta_pontuacao
    ldr  r6, [r0]
    cmp  r5, r6
    bge  apanhar_vitoria

    ldr  r0, =mosquitoX
    mov  r1, #150
    str  r1, [r0]
    ldr  r0, =mosquitoY
    mov  r1, #70
    str  r1, [r0]

    pop  {r4-r7, pc}

apanhar_vitoria:
    ldr  r0, =estado_minijogo
    mov  r1, #1
    str  r1, [r0]
    pop  {r4-r7, pc}

@ ---------------------------------------------------------------------
@ Contagem regressiva
@ ---------------------------------------------------------------------
atualizar_tempo:
    push {r4, lr}

    ldr  r0, =tempo_frames
    ldr  r1, [r0]
    cmp  r1, #0
    beq  tempo_esgotado
    sub  r1, r1, #1
    str  r1, [r0]

    @ A cada 60 frames (1 segundo) redesenha o tempo
    ldr  r0, =tempo_sub
    ldr  r2, [r0]
    add  r2, r2, #1
    cmp  r2, #60
    movge r2, #0
    str  r2, [r0]
    bne  tempo_sair

    ldr  r3, =desenhar_tempo
    mov  lr, pc
    bx   r3

tempo_sair:
    pop  {r4, pc}

tempo_esgotado:
    ldr  r0, =estado_minijogo
    mov  r1, #2
    str  r1, [r0]
    pop  {r4, pc}

@ ---------------------------------------------------------------------
@ Botão A (só no momento em que é pressionado).  r1 = KEYINPUT
@ ---------------------------------------------------------------------
verificar_botao_A:
    push {r4, lr}

    tst  r1, #KEY_A                 @ ativo em zero
    bne  botao_A_solto

    ldr  r0, =botaoA_anterior
    ldr  r2, [r0]
    cmp  r2, #1
    beq  botao_A_sair               @ já estava pressionado

    mov  r2, #1
    str  r2, [r0]

    bl   verificar_colisao
    cmp  r0, #0
    blt  botao_A_sair

    bl   apanhar_mosquito
    b    botao_A_sair

botao_A_solto:
    ldr  r0, =botaoA_anterior
    mov  r2, #0
    str  r2, [r0]

botao_A_sair:
    pop  {r4, pc}

.pool