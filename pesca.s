@ =====================================================================
@  pesca.s  -  minijogo da PESCARIA (tela secundaria)
@
@  Controles:
@     Esquerda/Direita ... move o barco
@     Cima/Baixo ......... sobe e desce o anzol
@     A .................. puxa (tenta pescar o que estiver no anzol)
@     B .................. sai do minijogo
@
@  Regras:
@     Peixe laranja = +1 ponto   |  Peixe azul (rapido) = +2 pontos
@     Bota ou lata  = LIXO -> perde na hora
@     Chegou a META pontos antes do tempo acabar = vitoria
@ =====================================================================

.equ REG_KEYINPUT,   0x04000130
.equ REG_VCOUNT,     0x04000006
.equ REG_DMA3SAD,    0x040000D4
.equ REG_TM0CNT_L,   0x04000100
.equ REG_TM0CNT_H,   0x04000102
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

@ --- Ajustes do jogo (pode mexer a vontade) ---
.equ META,           10              @ pontos para vencer
.equ PESCA_TEMPO,    2400            @ 40 segundos a 60 fps
.equ NUM_NAD,        6               @ quantos objetos nadando ao mesmo tempo
.equ VEL_BARCO,      2
.equ VEL_ANZOL,      2

@ --- Graficos (gerados por gerar_pesca.py) ---
.equ PESCA_VRAM,     0x06016000
.equ PESCA_NTILES,   34
.equ TILE_PEIXE_A,   768             @ 4 tiles (16x16)
.equ TILE_PEIXE_B,   772
.equ TILE_BOTA,      776
.equ TILE_LATA,      780
.equ TILE_BARCO,     784             @ 16 tiles (32x32)
.equ TILE_ANZOL,     800             @ 2 tiles (8x16)
.equ PAL_BARCO,      11
.equ PAL_PEIXE,      12
.equ PAL_BARCO_ADDR, (OBJ_PALETTE + PAL_BARCO * 32)
.equ PAL_PEIXE_ADDR, (OBJ_PALETTE + PAL_PEIXE * 32)

@ --- Geometria ---
.equ BARCO_Y,        28
.equ BARCO_MIN_X,    24              @ a doca ocupa x = 0..24
.equ BARCO_MAX_X,    204
.equ TIP_DX,         31              @ ponta da vara: x = barco_x + 31
.equ TIP_Y,          37              @ ponta da vara: y = 37 (linha comeca logo abaixo)
.equ ANZOL_DX,       27              @ sprite do anzol: x = barco_x + 27 (linha do anzol no pixel 4)
.equ ANZOL_MIN_Y,    44
.equ ANZOL_MAX_Y,    140
.equ FAIXA_Y0,       72              @ 4 faixas de agua: 72, 92, 112, 132
.equ COR_LINHA,      0x7BDE

.equ BANNER_X,       32
.equ BANNER_Y,       58

.macro ESPERA_FRAME
    ldr  r0, =REG_VCOUNT
2:  ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    bge  2b
3:  ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    blt  3b
.endm

@ =====================================================================
@  VARIAVEIS
@ =====================================================================
.data
.align 2
pesca_barco_x:    .word 100
pesca_anzol_y:    .word 70
pesca_estado:     .word 0            @ 0=jogando 1=vitoria 2=tempo 3=lixo
pesca_botaA_ant:  .word 0
pesca_tempo_sub:  .word 0
pesca_rng:        .word 0x2545F491
pesca_linha_x:    .word 0
pesca_linha_y1:   .word (TIP_Y + 1)
pesca_nad_x:      .space 24          @ NUM_NAD words cada
pesca_nad_y:      .space 24
pesca_nad_vx:     .space 24
pesca_nad_tipo:   .space 24          @ 0=peixe A 1=peixe B 2=bota 3=lata

@ =====================================================================
@  CODIGO (IWRAM)
@ =====================================================================
.section .iwram, "ax", %progbits
.arm
.align 2

.global iniciar_pesca
iniciar_pesca:
    push {r4-r12, lr}

    @ --- Espera soltar A ---
    ldr  r0, =REG_KEYINPUT
1:  ldrh r1, [r0]
    tst  r1, #KEY_A
    beq  1b

    bl   pesca_carregar_cenario
    bl   inicializar_oam

    @ --- Tiles dos sprites ---
    ldr  r0, =REG_DMA3SAD
    ldr  r1, =pescaTiles
    ldr  r2, =PESCA_VRAM
    ldr  r3, =(0x84000000 | (PESCA_NTILES * 8))
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop

    @ --- Paleta do barco/anzol ---
    ldr  r1, =pescaPalBarco
    ldr  r2, =PAL_BARCO_ADDR
    ldr  r3, =(0x80000000 | 16)
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop

    @ --- Paleta dos peixes/lixo ---
    ldr  r1, =pescaPalPeixes
    ldr  r2, =PAL_PEIXE_ADDR
    ldr  r3, =(0x80000000 | 16)
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop

    @ --- Variaveis ---
    mov  r1, #0
    ldr  r0, =pesca_estado
    str  r1, [r0]
    ldr  r0, =pesca_botaA_ant
    str  r1, [r0]
    ldr  r0, =pesca_tempo_sub
    str  r1, [r0]
    ldr  r0, =pontuacao
    str  r1, [r0]
    ldr  r0, =pesca_linha_x
    str  r1, [r0]
    mov  r1, #(TIP_Y + 1)
    ldr  r0, =pesca_linha_y1
    str  r1, [r0]
    mov  r1, #100
    ldr  r0, =pesca_barco_x
    str  r1, [r0]
    mov  r1, #70
    ldr  r0, =pesca_anzol_y
    str  r1, [r0]
    ldr  r0, =tempo_frames
    ldr  r1, =PESCA_TEMPO
    str  r1, [r0]

    @ --- Timer 0 livre (so serve de fonte de aleatoriedade) ---
    ldr  r0, =REG_TM0CNT_H
    mov  r1, #0x80
    strh r1, [r0]

    @ --- Posiciona os objetos que nadam ---
    mov  r4, #0
2:  cmp  r4, #NUM_NAD
    bge  3f
    mov  r0, r4
    mov  r1, #1                     @ 1 = posicao inicial aleatoria na tela
    bl   pesca_spawn
    add  r4, r4, #1
    b    2b
3:
    @ --- HUD inicial: pontuacao (00) e tempo (40) ---
    ldr  r3, =desenhar_pontuacao
    mov  lr, pc
    bx   r3
    ldr  r3, =desenhar_tempo
    mov  lr, pc
    bx   r3

    b    pesca_loop

.pool

@ ---------------- LOOP DO MINIJOGO ----------------
pesca_loop:
    ESPERA_FRAME

    ldr  r0, =pesca_estado
    ldr  r0, [r0]
    cmp  r0, #0
    bne  pesca_fim

    ldr  r0, =REG_KEYINPUT
    ldrh r4, [r0]

    tst  r4, #KEY_B                 @ B = sair
    beq  pesca_sair

    @ --- Barco (esquerda/direita) ---
    ldr  r5, =pesca_barco_x
    ldr  r6, [r5]
    tst  r4, #KEY_LEFT
    subeq r6, r6, #VEL_BARCO
    tst  r4, #KEY_RIGHT
    addeq r6, r6, #VEL_BARCO
    cmp  r6, #BARCO_MIN_X
    movlt r6, #BARCO_MIN_X
    cmp  r6, #BARCO_MAX_X
    movgt r6, #BARCO_MAX_X
    str  r6, [r5]

    @ --- Anzol (cima/baixo) ---
    ldr  r5, =pesca_anzol_y
    ldr  r6, [r5]
    tst  r4, #KEY_UP
    subeq r6, r6, #VEL_ANZOL
    tst  r4, #KEY_DOWN
    addeq r6, r6, #VEL_ANZOL
    cmp  r6, #ANZOL_MIN_Y
    movlt r6, #ANZOL_MIN_Y
    cmp  r6, #ANZOL_MAX_Y
    movgt r6, #ANZOL_MAX_Y
    str  r6, [r5]

    bl   pesca_mover_nadadores
    bl   pesca_desenhar
    bl   pesca_atualizar_tempo
    bl   pesca_botao_A

    b    pesca_loop

@ ---------------- FIM DE JOGO (vitoria / tempo / lixo) ----------------
pesca_fim:
    ldr  r0, =pesca_estado
    ldr  r4, [r0]

    bl   inicializar_oam            @ esconde barco, anzol e peixes
    bl   pesca_carregar_cenario     @ apaga a linha de pesca

    ldr  r3, =desenhar_pontuacao
    mov  lr, pc
    bx   r3
    ldr  r3, =desenhar_tempo
    mov  lr, pc
    bx   r3

    ldr  r2, =pesca_msg_tempo
    cmp  r4, #1
    ldreq r2, =pesca_msg_vitoria
    cmp  r4, #3
    ldreq r2, =pesca_msg_lixo
    mov  r0, #BANNER_X
    mov  r1, #BANNER_Y
    ldr  r3, =desenhar_caixa_dialogo
    mov  lr, pc
    bx   r3

    mov  r5, #120                   @ mostra a mensagem por ~2 segundos
4:  ESPERA_FRAME
    subs r5, r5, #1
    bne  4b

pesca_sair:
    ldr  r0, =REG_KEYINPUT
5:  ldrh r1, [r0]                   @ espera soltar A e B
    and  r1, r1, #(KEY_A | KEY_B)
    cmp  r1, #(KEY_A | KEY_B)
    bne  5b

    bl   inicializar_oam
    pop  {r4-r12, pc}

.pool

@ ---------------------------------------------------------------------
@ Copia o cenario da pesca para o BG (Modo 3)
@ ---------------------------------------------------------------------
pesca_carregar_cenario:
    ldr  r0, =REG_DMA3SAD
    ldr  r1, =pesca_map
    ldr  r2, =VRAM
    ldr  r3, =DMA_CENARIO
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop
    bx   lr

@ ---------------------------------------------------------------------
@ Numero aleatorio de 16 bits em r0  (usa r0-r3)
@ ---------------------------------------------------------------------
pesca_rand:
    ldr  r2, =pesca_rng
    ldr  r0, [r2]
    ldr  r1, =1664525
    mul  r3, r0, r1
    ldr  r1, =1013904223
    add  r3, r3, r1
    ldr  r1, =REG_TM0CNT_L
    ldrh r1, [r1]
    eor  r3, r3, r1                 @ mistura o timer (varia a cada partida)
    str  r3, [r2]
    mov  r0, r3, lsr #16
    bx   lr

.pool

@ ---------------------------------------------------------------------
@ (Re)cria o objeto r0 que nada.   r1 = 1 -> posicao aleatoria na tela
@                                  r1 = 0 -> entra pela borda da tela
@ ---------------------------------------------------------------------
pesca_spawn:
    push {r4-r8, lr}
    mov  r4, r0, lsl #2             @ deslocamento no vetor (indice * 4)
    mov  r5, r1

    bl   pesca_rand
    mov  r6, r0

    @ tipo: 0,1,2 -> peixe A | 3,4 -> peixe B | 5,6 -> bota | 7 -> lata
    and  r1, r6, #7
    mov  r7, #0
    cmp  r1, #3
    blt  1f
    mov  r7, #1
    cmp  r1, #5
    blt  1f
    mov  r7, #2
    cmp  r1, #7
    blt  1f
    mov  r7, #3
1:
    ldr  r0, =pesca_nad_tipo
    str  r7, [r0, r4]

    @ faixa de profundidade: y = 72 + 20 * (0..3)
    mov  r1, r6, lsr #3
    and  r1, r1, #3
    add  r1, r1, r1, lsl #2
    mov  r1, r1, lsl #2
    add  r1, r1, #FAIXA_Y0
    ldr  r0, =pesca_nad_y
    str  r1, [r0, r4]

    @ velocidade: peixe azul e rapido
    mov  r8, #1
    cmp  r7, #1
    moveq r8, #2

    @ direcao
    tst  r6, #0x20
    beq  2f
    rsb  r8, r8, #0                 @ vai para a esquerda
    mov  r3, #240
    b    3f
2:  mvn  r3, #15                    @ vai para a direita (comeca em x = -16)
3:
    ldr  r0, =pesca_nad_vx
    str  r8, [r0, r4]
    ldr  r0, =pesca_nad_x
    str  r3, [r0, r4]

    cmp  r5, #0
    beq  4f
    bl   pesca_rand                 @ posicao inicial: x = 0..223
    and  r0, r0, #0xFF
    sub  r0, r0, r0, lsr #3
    ldr  r1, =pesca_nad_x
    str  r0, [r1, r4]
4:
    pop  {r4-r8, pc}

.pool

@ ---------------------------------------------------------------------
@ Move todos os objetos; os que saem da tela voltam por outra borda
@ ---------------------------------------------------------------------
pesca_mover_nadadores:
    push {r4-r8, lr}
    mov  r4, #0
1:  cmp  r4, #NUM_NAD
    bge  4f
    mov  r5, r4, lsl #2
    ldr  r6, =pesca_nad_x
    ldr  r7, [r6, r5]
    ldr  r8, =pesca_nad_vx
    ldr  r8, [r8, r5]
    add  r7, r7, r8
    str  r7, [r6, r5]

    cmp  r8, #0
    blt  2f
    cmp  r7, #240                   @ indo para a direita: saiu em x >= 240
    blt  3f
    b    5f
2:  cmn  r7, #16                    @ indo para a esquerda: saiu em x <= -16
    bgt  3f
5:  mov  r0, r4
    mov  r1, #0
    bl   pesca_spawn
3:  add  r4, r4, #1
    b    1b
4:  pop  {r4-r8, pc}

.pool

@ ---------------------------------------------------------------------
@ Apaga a linha de pesca antiga (restaura os pixels do cenario)
@ ---------------------------------------------------------------------
pesca_apagar_linha:
    push {r4-r7, lr}
    ldr  r0, =pesca_linha_x
    ldr  r4, [r0]
    ldr  r0, =pesca_linha_y1
    ldr  r5, [r0]
    mov  r2, #(TIP_Y + 1)
    ldr  r6, =pesca_map
    ldr  r7, =VRAM
1:  cmp  r2, r5
    bge  2f
    mov  r0, r2, lsl #9
    sub  r0, r0, r2, lsl #5         @ y * 480
    add  r0, r0, r4, lsl #1         @ + x * 2
    ldrh r1, [r6, r0]
    strh r1, [r7, r0]
    add  r2, r2, #1
    b    1b
2:  pop  {r4-r7, pc}

@ ---------------------------------------------------------------------
@ Atualiza a OAM (barco, anzol, objetos) e desenha a linha de pesca
@   OBJ 0 = barco | OBJ 1 = anzol | OBJ 2..7 = peixes e lixo
@ ---------------------------------------------------------------------
pesca_desenhar:
    push {r4-r9, lr}

    bl   pesca_apagar_linha

    ldr  r0, =pesca_barco_x
    ldr  r4, [r0]
    ldr  r0, =pesca_anzol_y
    ldr  r5, [r0]
    ldr  r6, =OAM

    @ --- Barco (32x32) ---
    mov  r0, #BARCO_Y
    strh r0, [r6]
    mov  r0, r4, lsl #23
    mov  r0, r0, lsr #23
    orr  r0, r0, #0x8000            @ tamanho 2 = 32x32
    strh r0, [r6, #2]
    ldr  r0, =(TILE_BARCO | (PAL_BARCO << 12))
    strh r0, [r6, #4]

    @ --- Anzol (8x16: forma vertical, tamanho 0) ---
    and  r0, r5, #0xFF
    orr  r0, r0, #0x8000            @ forma 2 = vertical
    strh r0, [r6, #8]
    add  r0, r4, #ANZOL_DX
    mov  r0, r0, lsl #23
    mov  r0, r0, lsr #23
    strh r0, [r6, #10]
    ldr  r0, =(TILE_ANZOL | (PAL_BARCO << 12))
    strh r0, [r6, #12]

    @ --- Peixes e lixo (16x16) ---
    mov  r7, #0
1:  cmp  r7, #NUM_NAD
    bge  2f
    mov  r8, r7, lsl #2
    ldr  r0, =pesca_nad_x
    ldr  r0, [r0, r8]
    ldr  r1, =pesca_nad_y
    ldr  r1, [r1, r8]
    ldr  r2, =pesca_nad_vx
    ldr  r2, [r2, r8]
    ldr  r3, =pesca_nad_tipo
    ldr  r3, [r3, r8]
    add  r9, r6, r7, lsl #3
    add  r9, r9, #16                @ OBJ (2 + i)

    and  r1, r1, #0xFF
    strh r1, [r9]                   @ Attr0: Y, 4bpp, quadrado
    mov  r0, r0, lsl #23
    mov  r0, r0, lsr #23
    orr  r0, r0, #0x4000            @ tamanho 1 = 16x16
    cmp  r2, #0
    orrlt r0, r0, #0x1000           @ indo para a esquerda: espelha
    strh r0, [r9, #2]               @ Attr1
    mov  r3, r3, lsl #2
    add  r3, r3, #TILE_PEIXE_A
    orr  r3, r3, #(PAL_PEIXE << 12)
    strh r3, [r9, #4]               @ Attr2
    add  r7, r7, #1
    b    1b
2:
    @ --- Linha de pesca (no fundo): da ponta da vara ate o anzol ---
    add  r7, r4, #TIP_DX
    ldr  r0, =pesca_linha_x
    str  r7, [r0]
    ldr  r0, =pesca_linha_y1
    str  r5, [r0]
    mov  r2, #(TIP_Y + 1)
    ldr  r3, =VRAM
    ldr  r1, =COR_LINHA
3:  cmp  r2, r5
    bge  4f
    mov  r0, r2, lsl #9
    sub  r0, r0, r2, lsl #5
    add  r0, r0, r7, lsl #1
    strh r1, [r3, r0]
    add  r2, r2, #1
    b    3b
4:  pop  {r4-r9, pc}

.pool

@ ---------------------------------------------------------------------
@ Contagem regressiva (redesenha o tempo uma vez por segundo)
@ ---------------------------------------------------------------------
pesca_atualizar_tempo:
    push {r4, lr}

    ldr  r0, =tempo_frames
    ldr  r1, [r0]
    cmp  r1, #0
    beq  2f
    sub  r1, r1, #1
    str  r1, [r0]

    ldr  r0, =pesca_tempo_sub
    ldr  r2, [r0]
    add  r2, r2, #1
    cmp  r2, #60
    movge r2, #0
    str  r2, [r0]
    bne  1f
    ldr  r3, =desenhar_tempo
    mov  lr, pc
    bx   r3
1:  pop  {r4, pc}

2:  ldr  r0, =pesca_estado          @ tempo acabou
    mov  r1, #2
    str  r1, [r0]
    pop  {r4, pc}

@ ---------------------------------------------------------------------
@ Botao A: puxa o anzol. So vale no momento em que e apertado.
@ A ponta do anzol (barco_x + 31, anzol_y + 14) precisa estar a
@ no maximo 4 pixels de um objeto 16x16.
@ ---------------------------------------------------------------------
pesca_botao_A:
    push {r4-r9, lr}

    ldr  r0, =REG_KEYINPUT
    ldrh r1, [r0]
    ldr  r2, =pesca_botaA_ant
    tst  r1, #KEY_A
    bne  9f                         @ solto

    ldr  r3, [r2]
    cmp  r3, #1
    beq  10f                        @ ja estava apertado
    mov  r3, #1
    str  r3, [r2]

    ldr  r0, =pesca_barco_x
    ldr  r4, [r0]
    add  r4, r4, #TIP_DX            @ px
    ldr  r0, =pesca_anzol_y
    ldr  r5, [r0]
    add  r5, r5, #14                @ py

    mov  r6, #0
1:  cmp  r6, #NUM_NAD
    bge  10f
    mov  r7, r6, lsl #2

    ldr  r0, =pesca_nad_x
    ldr  r0, [r0, r7]
    sub  r1, r4, r0
    add  r1, r1, #4
    cmp  r1, #24                    @ (sem sinal) fora de [-4, 20) -> proximo
    bhs  8f
    ldr  r0, =pesca_nad_y
    ldr  r0, [r0, r7]
    sub  r1, r5, r0
    add  r1, r1, #4
    cmp  r1, #24
    bhs  8f

    @ --- pegou o objeto r6 ---
    ldr  r0, =pesca_nad_tipo
    ldr  r8, [r0, r7]
    cmp  r8, #2
    bge  7f                         @ bota ou lata

    mov  r9, #1                     @ peixe A = +1
    cmp  r8, #1
    moveq r9, #2                    @ peixe B = +2
    ldr  r0, =pontuacao
    ldr  r1, [r0]
    add  r1, r1, r9
    str  r1, [r0]
    ldr  r3, =desenhar_pontuacao
    mov  lr, pc
    bx   r3

    ldr  r0, =pontuacao
    ldr  r1, [r0]
    cmp  r1, #META
    blt  6f
    ldr  r0, =pesca_estado          @ bateu a meta: vitoria
    mov  r1, #1
    str  r1, [r0]
6:  mov  r0, r6                     @ o peixe pescado some e outro entra
    mov  r1, #0
    bl   pesca_spawn
    b    10f

7:  ldr  r0, =pesca_estado          @ pescou lixo: derrota
    mov  r1, #3
    str  r1, [r0]
    b    10f

8:  add  r6, r6, #1
    b    1b

9:  mov  r3, #0
    str  r3, [r2]
10: pop  {r4-r9, pc}

.pool