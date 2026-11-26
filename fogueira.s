@ =====================================================================
@  fogueira.s  -  Minijogo Guitar Hero na Fogueira (GBA Modo 3 + OAM)
@  4 pistas: LEFT (Verde), DOWN (Vermelho), UP (Amarelo), RIGHT (Azul)
@  Usa tempo_frames, pontuacao, desenhar_pontuacao e desenhar_tempo
@ =====================================================================

.equ REG_DISPCNT,       0x04000000
.equ REG_VCOUNT,        0x04000006
.equ REG_KEYINPUT,      0x04000130
.equ VRAM,              0x06000000
.equ OBJ_PALETTE,       0x05000200
.equ OAM,               0x07000000

.equ DISPCNT_MODE3_BG2_OBJ, 0x1443
.equ FORCED_BLANK,      0x0080

.equ KEY_A,             0x0001
.equ KEY_B,             0x0002
.equ KEY_RIGHT,         0x0010
.equ KEY_LEFT,          0x0020
.equ KEY_UP,            0x0040
.equ KEY_DOWN,          0x0080

.equ SCREEN_W,          240
.equ SCREEN_H,          160

@ --- Pistas e Zona de Acerto ---
.equ NUM_NOTAS,         8
.equ HIT_Y,             132
.equ HIT_TOL,           14
.equ NOTE_SPEED,        1

@ --- VRAM / OAM para notas (16x16 4bpp, tile 800 em 0x06016400) ---
.equ NOTA_VRAM,         0x06016400
.equ NOTA_TILE_IDX,     800

.equ FOGUEIRA_TEMPO,    2400            @ 40 segundos a 60 fps
.equ META_FOGUEIRA,     50              @ Pontuação máxima para vencer

.section .iwram, "ax", %progbits
.arm
.align 2

.global iniciar_fogueira

@ ---------------------------------------------------------------------
@  iniciar_fogueira: roda o minijogo da fogueira até acabar o tempo ou B
@ ---------------------------------------------------------------------
iniciar_fogueira:
    push {r4-r12, lr}

    @ Tela em branco durante carga
    ldr  r0, =REG_DISPCNT
    ldr  r1, =(DISPCNT_MODE3_BG2_OBJ | FORCED_BLANK)
    strh r1, [r0]

    @ Inicializa variáveis
    ldr  r0, =pontuacao
    mov  r1, #0
    str  r1, [r0]

    ldr  r0, =tempo_frames
    ldr  r1, =FOGUEIRA_TEMPO
    str  r1, [r0]

    ldr  r0, =fogueira_tempo_sub
    mov  r1, #0
    str  r1, [r0]

    ldr  r0, =fogueira_venceu
    mov  r1, #0
    str  r1, [r0]

    ldr  r0, =fogueira_spawn_cnt
    mov  r1, #20
    str  r1, [r0]

    ldr  r0, =fogueira_prev_keys
    ldr  r1, =0x03FF
    strh r1, [r0]

    @ Limpa notas
    ldr  r0, =notas_ativas
    mov  r1, #0
    mov  r2, #NUM_NOTAS
1:  strb r1, [r0], #1
    subs r2, r2, #1
    bne  1b

    @ Desenha fundo da pista + fogueira
    bl   fogueira_desenhar_fundo

    @ Limpa OAM (esconde jogador e seta do mapa) e carrega setas das notas
    ldr  r3, =inicializar_oam
    mov  lr, pc
    bx   r3
    bl   fogueira_carregar_obj

    @ Desenha HUD inicial (pontuação e tempo)
    ldr  r3, =desenhar_pontuacao
    mov  lr, pc
    bx   r3
    ldr  r3, =desenhar_tempo
    mov  lr, pc
    bx   r3

    @ Liga a tela
    ldr  r0, =REG_DISPCNT
    ldr  r1, =DISPCNT_MODE3_BG2_OBJ
    strh r1, [r0]

@ =====================================================================
@  LOOP PRINCIPAL DA FOGUEIRA
@ =====================================================================
fogueira_loop:
    @ --- VBlank ---
    ldr  r0, =REG_VCOUNT
2:  ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    bge  2b
3:  ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    blt  3b

    @ --- Lê entrada ---
    ldr  r0, =REG_KEYINPUT
    ldrh r4, [r0]                       @ r4 = curr_keys (ativo em 0)
    tst  r4, #KEY_B
    beq  fogueira_sair                  @ B sai imediatamente

    @ Detecta borda de descida (botão recém-pressionado)
    ldr  r0, =fogueira_prev_keys
    ldrh r5, [r0]                       @ r5 = prev_keys
    strh r4, [r0]
    bic  r5, r5, r4                     @ r5 = bits que mudaram de 1 -> 0

    @ --- Checa acerto nas 4 pistas ---
    tst  r5, #KEY_LEFT
    movne r0, #0
    blne fogueira_checar_acerto

    tst  r5, #KEY_DOWN
    movne r0, #1
    blne fogueira_checar_acerto

    tst  r5, #KEY_UP
    movne r0, #2
    blne fogueira_checar_acerto

    tst  r5, #KEY_RIGHT
    movne r0, #3
    blne fogueira_checar_acerto

    @ --- Spawn de novas notas ---
    bl   fogueira_spawn_nota

    @ --- Move notas e atualiza OAM ---
    bl   fogueira_atualizar_notas

    @ --- Atualiza tempo ---
    bl   fogueira_atualizar_tempo
    cmp  r0, #0
    bne  fogueira_fim_espera

    @ --- Checa se atingiu pontuação máxima ---
    ldr  r0, =fogueira_venceu
    ldr  r1, [r0]
    cmp  r1, #0
    beq  fogueira_loop

@ --- Tempo acabou: espera ~1.5s ou aperto de A/B ---
    mov  r4, #90
fogueira_fim_espera:
    ldr  r0, =REG_VCOUNT
4:  ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    bge  4b
5:  ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    blt  5b

    ldr  r0, =REG_KEYINPUT
    ldrh r1, [r0]
    tst  r1, #(KEY_A | KEY_B)
    beq  fogueira_sair
    subs r4, r4, #1
    bne  fogueira_fim_espera

fogueira_sair:
    @ Restaura OAM para o mundo principal
    ldr  r3, =inicializar_oam
    mov  lr, pc
    bx   r3
    ldr  r3, =carregar_jogador_obj
    mov  lr, pc
    bx   r3
    ldr  r3, =carregar_seta_obj
    mov  lr, pc
    bx   r3

    pop  {r4-r12, lr}
    bx   lr

@ ---------------------------------------------------------------------
@  fogueira_checar_acerto: r0 = pista (0..3)
@ ---------------------------------------------------------------------
fogueira_checar_acerto:
    push {r4-r7, lr}
    mov  r4, r0                         @ r4 = pista alvo
    ldr  r5, =notas_ativas
    ldr  r6, =notas_pista
    ldr  r7, =notas_y
    mov  r1, #0                         @ i = 0

1:  cmp  r1, #NUM_NOTAS
    bge  9f

    ldrb r2, [r5, r1]
    cmp  r2, #0
    beq  2f

    ldrb r2, [r6, r1]
    cmp  r2, r4
    bne  2f

    ldr  r2, [r7, r1, lsl #2]           @ Y da nota
    sub  r3, r2, #HIT_Y
    cmp  r3, #0
    rsblt r3, r3, #0
    cmp  r3, #HIT_TOL
    bgt  2f

    @ Acertou!
    mov  r2, #0
    strb r2, [r5, r1]                   @ Desativa nota

    ldr  r2, =pontuacao
    ldr  r3, [r2]
    add  r3, r3, #1
    str  r3, [r2]

    cmp  r3, #META_FOGUEIRA
    ldrge r2, =fogueira_venceu
    movge r3, #1
    strge r3, [r2]

    ldr  r3, =desenhar_pontuacao
    mov  lr, pc
    bx   r3
    b    9f

2:  add  r1, r1, #1
    b    1b
9:  pop  {r4-r7, lr}
    bx   lr

@ ---------------------------------------------------------------------
@  fogueira_spawn_nota: gera nota periódica em pista pseudo-aleatória
@ ---------------------------------------------------------------------
fogueira_spawn_nota:
    push {r4-r6, lr}
    ldr  r0, =fogueira_spawn_cnt
    ldr  r1, [r0]
    subs r1, r1, #1
    str  r1, [r0]
    bgt  9f

    mov  r1, #28                        @ Intervalo entre notas (28 frames)
    str  r1, [r0]

    @ Atualiza PRNG simples
    ldr  r0, =fogueira_rng
    ldr  r2, [r0]
    ldr  r3, =1103515245
    mul  r2, r3, r2
    ldr  r3, =12345
    add  r2, r2, r3
    str  r2, [r0]
    lsr  r2, r2, #16
    and  r2, r2, #3                     @ Pista 0..3

    @ Procura slot livre
    ldr  r3, =notas_ativas
    mov  r4, #0
1:  cmp  r4, #NUM_NOTAS
    bge  9f
    ldrb r5, [r3, r4]
    cmp  r5, #0
    beq  2f
    add  r4, r4, #1
    b    1b

2:  mov  r5, #1
    strb r5, [r3, r4]
    ldr  r3, =notas_pista
    strb r2, [r3, r4]
    ldr  r3, =notas_y
    mov  r5, #8
    str  r5, [r3, r4, lsl #2]

9:  pop  {r4-r6, lr}
    bx   lr

@ ---------------------------------------------------------------------
@  fogueira_atualizar_notas: move notas e atualiza OBJ 2..9 na OAM
@ ---------------------------------------------------------------------
fogueira_atualizar_notas:
    push {r4-r9, lr}
    ldr  r4, =notas_ativas
    ldr  r5, =notas_pista
    ldr  r6, =notas_y
    ldr  r7, =OAM
    add  r7, r7, #16                    @ Começa em OBJ 2
    ldr  r8, =pistas_x
    mov  r9, #0

1:  cmp  r9, #NUM_NOTAS
    bge  9f

    ldrb r0, [r4, r9]
    cmp  r0, #0
    beq  2f

    ldr  r1, [r6, r9, lsl #2]
    add  r1, r1, #NOTE_SPEED
    cmp  r1, #152
    blt  3f

    @ Passou da tela: desativa
    mov  r0, #0
    strb r0, [r4, r9]
    b    2f

3:  str  r1, [r6, r9, lsl #2]
    ldrb r2, [r5, r9]                   @ Pista 0..3
    ldr  r3, [r8, r2, lsl #2]           @ X da pista

    @ Attr0: Y (bits 0-7), 4bpp, square (0)
    and  r1, r1, #0xFF
    strh r1, [r7, #0]
    @ Attr1: X (bits 0-8), size 1 (16x16 = 0x4000)
    ldr  r0, =0x1FF
    and  r3, r3, r0
    orr  r3, r3, #0x4000
    strh r3, [r7, #2]
    @ Attr2: tile (800 + pista*4) + palette bank (8 + pista)
    lsl  r0, r2, #2                     @ pista * 4
    add  r2, r2, #8
    lsl  r2, r2, #12
    ldr  r3, =NOTA_TILE_IDX
    add  r3, r3, r0
    orr  r2, r2, r3
    strh r2, [r7, #4]
    b    4f

2:  mov  r0, #0x200                     @ Desabilita OBJ
    strh r0, [r7, #0]

4:  add  r7, r7, #8
    add  r9, r9, #1
    b    1b

9:  pop  {r4-r9, lr}
    bx   lr

@ ---------------------------------------------------------------------
@  fogueira_atualizar_tempo: retorna r0=1 se tempo acabou, 0 caso contrário
@ ---------------------------------------------------------------------
fogueira_atualizar_tempo:
    push {lr}
    ldr  r0, =tempo_frames
    ldr  r1, [r0]
    subs r1, r1, #1
    str  r1, [r0]
    ble  1f

    ldr  r0, =fogueira_tempo_sub
    ldr  r1, [r0]
    add  r1, r1, #1
    cmp  r1, #60
    movge r1, #0
    str  r1, [r0]
    bne  2f

    ldr  r3, =desenhar_tempo
    mov  lr, pc
    bx   r3

2:  mov  r0, #0
    pop  {lr}
    bx   lr

1:  mov  r1, #0
    ldr  r0, =tempo_frames
    str  r1, [r0]
    ldr  r3, =desenhar_tempo
    mov  lr, pc
    bx   r3
    mov  r0, #1
    pop  {lr}
    bx   lr

@ ---------------------------------------------------------------------
@  fogueira_desenhar_fundo: copia fogueira_map (240x160) via DMA3
@ ---------------------------------------------------------------------
fogueira_desenhar_fundo:
    ldr  r0, =0x040000D4                @ REG_DMA3SAD
    ldr  r1, =fogueira_map
    str  r1, [r0, #0]
    ldr  r1, =VRAM
    str  r1, [r0, #4]
    ldr  r1, =0x84004B00                @ Enable | 32-bit | 19200 words
    str  r1, [r0, #8]
    bx   lr

@ ---------------------------------------------------------------------
@  fogueira_carregar_obj: carrega 4 setas 16x16 (16 tiles) e paletas 8..11
@ ---------------------------------------------------------------------
fogueira_carregar_obj:
    push {r4-r5, lr}
    @ Copia 16 tiles (512 bytes = 128 words) de fogueira_setas_tiles
    ldr  r0, =NOTA_VRAM
    ldr  r1, =fogueira_setas_tiles
    mov  r2, #128
1:  ldr  r3, [r1], #4
    str  r3, [r0], #4
    subs r2, r2, #1
    bne  1b

    @ Paletas 8..11 (offset 8*32 = 256 bytes em OBJ_PALETTE)
    ldr  r0, =(OBJ_PALETTE + 256)
    mov  r1, #0
    strh r1, [r0, #0]                   @ Bank 8: Verde
    ldr  r1, =0x03E0
    strh r1, [r0, #2]

    add  r0, r0, #32
    mov  r1, #0
    strh r1, [r0, #0]                   @ Bank 9: Vermelho
    ldr  r1, =0x001F
    strh r1, [r0, #2]

    add  r0, r0, #32
    mov  r1, #0
    strh r1, [r0, #0]                   @ Bank 10: Amarelo
    ldr  r1, =0x03FF
    strh r1, [r0, #2]

    add  r0, r0, #32
    mov  r1, #0
    strh r1, [r0, #0]                   @ Bank 11: Azul
    ldr  r1, =0x7C00
    strh r1, [r0, #2]

    pop  {r4-r5, lr}
    bx   lr

.pool

@ =====================================================================
@  DADOS DO MINIJOGO DA FOGUEIRA
@ =====================================================================
.section .data
.align 2
pistas_x:            .word 84, 104, 124, 144
fogueira_tempo_sub:  .word 0
fogueira_venceu:     .word 0
fogueira_spawn_cnt:  .word 20
fogueira_rng:        .word 0x12345678
fogueira_prev_keys:  .hword 0x03FF
.align 2
notas_y:             .space (NUM_NOTAS * 4)
notas_ativas:        .space NUM_NOTAS
notas_pista:         .space NUM_NOTAS
