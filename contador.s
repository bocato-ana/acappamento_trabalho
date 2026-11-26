.equ VRAM, 0x06000000
.arm
.section .text
.align 2
@ =====================================================
@ DESENHAR DIGITO 5x7
@ r0 = digito (0-9)
@ r1 = X
@ r2 = Y
@ Cor: branco RGB555
@ =====================================================

.global desenhar_pontuacao

desenhar_digito:
    push {r4-r8, lr}

    mov  r4, r0              @ Digito
    mov  r5, r1              @ X
    mov  r6, r2              @ Y

    @ Offset = digito * 7 (7 bytes por digito)
    ldr  r7, =digitos_5x7

    add  r7, r7, r4, lsl #2  @ digito * 4
    add  r7, r7, r4, lsl #1  @ digito * 2
    add  r7, r7, r4           @ digito * 1

    mov  r4, #0              @ Linha = 0

digito_linha:

    cmp  r4, #7
    bge  digito_fim

    ldrb r3, [r7, r4]       @ Bitmap da linha

    @ Calcular endereco do pixel inicial
    add  r0, r6, r4          @ Y + linha
    mov  r1, r0, lsl #9
    sub  r1, r1, r0, lsl #5 @ Y * 480

    ldr  r0, =VRAM
    add  r1, r1, r0

    add  r1, r1, r5, lsl #1 @ X * 2

    mov  r8, #0              @ Coluna = 0

digito_coluna:

    cmp  r8, #5
    bge  digito_proxima_linha

    @ Testar bit correspondente
    mov  r0, #0x10
    mov  r0, r0, lsr r8

    tst  r3, r0
    beq  digito_pixel_transparente

    @ Pixel branco
    ldr  r0, =0x7FFF
    strh r0, [r1]

digito_pixel_transparente:

    add  r1, r1, #2
    add  r8, r8, #1

    b    digito_coluna


digito_proxima_linha:

    add  r4, r4, #1
    b    digito_linha


digito_fim:

    pop  {r4-r8, pc}


@ =====================================================
@ DESENHAR PONTUACAO
@ Mostra 00 a 10 no canto superior esquerdo
@ =====================================================

desenhar_pontuacao:
    push {r4-r6, lr}

    @ Limpar fundo do contador
    bl   limpar_area_pontos

    @ Ler pontuacao
    ldr  r0, =pontuacao
    ldr  r4, [r0]

    @ Separar dezenas e unidades
    mov  r5, #0
    mov  r6, r4

    cmp  r4, #10
    blt  pontuacao_separada

    mov  r5, #1
    sub  r6, r4, #10

pontuacao_separada:

    @ Desenhar dezenas
    mov  r0, r5
    mov  r1, #7
    mov  r2, #6
    bl   desenhar_digito

    @ Desenhar unidades
    mov  r0, r6
    mov  r1, #14
    mov  r2, #6
    bl   desenhar_digito

    pop  {r4-r6, pc}

@ =====================================================
@ LIMPAR AREA DO CONTADOR
@ Mode 3 - framebuffer 240x160, 16 bits
@ =====================================================

limpar_area_pontos:
    push {r4-r7, lr}

    mov  r4, #4              @ Y inicial
    mov  r7, #12             @ Altura

limpar_pontos_y:

    cmp  r4, #16
    bge  limpar_pontos_fim

    @ Calcular endereco da linha: Y * 480
    mov  r6, r4, lsl #9
    sub  r6, r6, r4, lsl #5

    ldr  r0, =VRAM
    add  r6, r6, r0

    add  r6, r6, #(4 * 2)   @ X inicial = 4

    mov  r5, #0

limpar_pontos_x:

    cmp  r5, #20
    bge  limpar_pontos_proxima_linha

    mov  r0, #0              @ Preto
    strh r0, [r6]

    add  r6, r6, #2
    add  r5, r5, #1

    b    limpar_pontos_x


limpar_pontos_proxima_linha:

    add  r4, r4, #1
    b    limpar_pontos_y


limpar_pontos_fim:

    pop  {r4-r7, pc}

@ =====================================================
@ DESENHAR TEMPO (segundos restantes, 00 a 99)
@ Canto superior direito (X = 211 e 218, Y = 6)
@ =====================================================

.global desenhar_tempo
desenhar_tempo:
    push {r4-r6, lr}

    bl   limpar_area_tempo

    @ segundos = (tempo_frames + 59) / 60  (arredonda para cima)
    ldr  r0, =tempo_frames
    ldr  r4, [r0]
    add  r4, r4, #59
    mov  r5, #0
tempo_div60:
    cmp  r4, #60
    blt  tempo_div60_fim
    sub  r4, r4, #60
    add  r5, r5, #1
    b    tempo_div60
tempo_div60_fim:

    @ r4 = dezenas, r5 = unidades
    mov  r4, #0
tempo_div10:
    cmp  r5, #10
    blt  tempo_div10_fim
    sub  r5, r5, #10
    add  r4, r4, #1
    b    tempo_div10
tempo_div10_fim:

    mov  r0, r4
    mov  r1, #211
    mov  r2, #6
    bl   desenhar_digito

    mov  r0, r5
    mov  r1, #218
    mov  r2, #6
    bl   desenhar_digito

    pop  {r4-r6, pc}

@ Limpa a area do tempo (X 208..227, Y 4..15) com preto
limpar_area_tempo:
    push {r4-r6, lr}

    mov  r4, #4
limpar_tempo_y:
    cmp  r4, #16
    bge  limpar_tempo_fim

    mov  r6, r4, lsl #9
    sub  r6, r6, r4, lsl #5          @ Y * 480
    ldr  r0, =VRAM
    add  r6, r6, r0
    add  r6, r6, #(208 * 2)          @ X inicial = 208

    mov  r5, #0
limpar_tempo_x:
    cmp  r5, #20
    bge  limpar_tempo_prox
    mov  r0, #0
    strh r0, [r6]
    add  r6, r6, #2
    add  r5, r5, #1
    b    limpar_tempo_x
limpar_tempo_prox:
    add  r4, r4, #1
    b    limpar_tempo_y

limpar_tempo_fim:
    pop  {r4-r6, pc}