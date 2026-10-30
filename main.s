@ =====================================================================
@  main.s  -  GBA Modo 3  -  jogador + NPC + seta interativa + caixa
@  devkitARM / mGBA
@ =====================================================================

.equ REG_DISPCNT,       0x04000000
.equ REG_VCOUNT,        0x04000006
.equ REG_DMA3SAD,       0x040000D4     @ SAD, DAD (+4), CNT (+8)
.equ REG_KEYINPUT,      0x04000130
.equ VRAM,              0x06000000

.equ DISPCNT_MODE3_BG2, 0x0403
.equ FORCED_BLANK,      0x0080

.equ KEY_A,             0x0001         @ Botão A do GBA (Tecla X no mGBA)
.equ KEY_RIGHT,         0x0010
.equ KEY_LEFT,          0x0020
.equ KEY_UP,            0x0040
.equ KEY_DOWN,          0x0080

.equ SCREEN_W,          240
.equ SCREEN_H,          160
.equ SPR_W,             40             @ Largura do jogador
.equ SPR_H,             48             @ Altura do jogador
.equ MAX_X,             200            @ SCREEN_W - SPR_W
.equ MAX_Y,             112            @ SCREEN_H - SPR_H

.equ NPC_X,             55
.equ NPC_Y,             35
.equ PROX,              35             @ Distância em pixels para interagir

.equ SETA_X,            68             @ Posição X da seta (centralizada no NPC)
.equ SETA_Y_BASE,       18             @ Posição Y base da seta (acima do NPC)

.equ BOX_X,             20
.equ BOX_Y,             112
.equ BOX_W,             200
.equ BOX_H,             42
.equ BOX_OVERLAP_Y,     (BOX_Y - SPR_H)

.equ DMA_CENARIO,       0x84004B00

@ Macro para chamadas de longa distância entre ROM e IWRAM
.macro CHAMA rotina
    ldr  r8, =\rotina
    mov  lr, pc
    bx   r8
.endm

@ =====================================================================
@  CÓDIGO PRINCIPAL (ROM)
@ =====================================================================
.section .text
.arm
.align 2
.global main

main:
    ldr  r0, =REG_DISPCNT
    ldr  r1, =(DISPCNT_MODE3_BG2 | FORCED_BLANK)
    strh r1, [r0]                   @ Tela em branco durante carga inicial

    mov  r11, #120                  @ Jogador X inicial
    mov  r12, #70                   @ Jogador Y inicial
    mov  r4,  #0                   @ Estado: 0=Longe, 1=Perto(Seta), 2=Caixa Aberta

    bl   carregar_cenario_inicial
    bl   desenhar_npc

    mov  r0, r11
    mov  r1, r12
    ldr  r2, =sprite_jogador
    CHAMA desenhar_sprite

    ldr  r0, =REG_DISPCNT
    ldr  r1, =DISPCNT_MODE3_BG2
    strh r1, [r0]                   @ Liga a tela

@ =====================================================================
@  LOOP PRINCIPAL DO JOGO
@ =====================================================================
game_loop:
    mov  r9,  r11                   @ Guarda X antigo
    mov  r10, r12                   @ Guarda Y antigo

    @ --- Leitura do D-Pad ---
    ldr  r0, =REG_KEYINPUT
    ldrh r1, [r0]

    tst  r1, #KEY_UP
    subeq r12, r12, #1
    tst  r1, #KEY_DOWN
    addeq r12, r12, #1
    tst  r1, #KEY_LEFT
    subeq r11, r11, #1
    tst  r1, #KEY_RIGHT
    addeq r11, r11, #1

    @ --- Limites da Tela ---
    cmp  r11, #0
    movlt r11, #0
    cmp  r11, #MAX_X
    movgt r11, #MAX_X
    cmp  r12, #0
    movlt r12, #0
    cmp  r12, #MAX_Y
    movgt r12, #MAX_Y

    @ Se o jogador moveu OU se a seta está flutuando (r4 == 1), renderiza o frame
    cmp  r11, r9
    bne  renderizar_frame
    cmp  r12, r10
    bne  renderizar_frame
    cmp  r4, #1
    beq  renderizar_frame
    b    game_loop

renderizar_frame:
    @ ---------------- Sincronização VBlank ----------------
    ldr  r0, =REG_VCOUNT
espera_vblank_fim:
    ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    bge  espera_vblank_fim
espera_vblank_inicio:
    ldrh r1, [r0]
    cmp  r1, #SCREEN_H
    blt  espera_vblank_inicio

    @ 1. Restaura fundo na posição antiga do jogador (se ele se moveu)
    cmp  r11, r9
    bne  limpar_jogador_antigo
    cmp  r12, r10
    beq  passo_npc
limpar_jogador_antigo:
    mov  r0, r9
    mov  r1, r10
    mov  r2, #SPR_W
    mov  r3, #SPR_H
    CHAMA apagar_retangulo

passo_npc:
    @ 2. Redesenha NPC se o jogador passou por cima dele
    ldr  r0, =sprite_monitor
    ldrh r5, [r0]
    ldrh r6, [r0, #2]
    add  r7, r5, #NPC_X
    cmp  r9, r7
    bge  npc_intacto
    add  r7, r9, #SPR_W
    cmp  r7, #NPC_X
    ble  npc_intacto
    add  r7, r6, #NPC_Y
    cmp  r10, r7
    bge  npc_intacto
    add  r7, r10, #SPR_H
    cmp  r7, #NPC_Y
    ble  npc_intacto
    bl   desenhar_npc
npc_intacto:

    @ 3. Desenha o jogador na nova posição
    mov  r0, r11
    mov  r1, r12
    ldr  r2, =sprite_jogador
    CHAMA desenhar_sprite

    @ 4. Checagem de Proximidade com o NPC (|X-NPC_X| <= PROX e |Y-NPC_Y| <= PROX)
    sub  r0, r11, #NPC_X
    cmp  r0, #0
    rsblt r0, r0, #0
    cmp  r0, #PROX
    bgt  longe_do_npc

    sub  r1, r12, #NPC_Y
    cmp  r1, #0
    rsblt r1, r1, #0
    cmp  r1, #PROX
    bgt  longe_do_npc

@ =====================================================================
@  INTERAÇÃO COM O NPC (ESTADOS DE PROXIMIDADE)
@ =====================================================================
pertode_npc:
    cmp  r4, #2                     @ Caixa de texto já aberta?
    beq  caixa_ja_visivel

    @ --- ESTADO 1: PERTO DO NPC (Mostra seta flutuando) ---
    mov  r4, #1

    @ Incrementa contador de animação da seta
    ldr  r0, =frame_contador
    ldr  r1, [r0]
    add  r1, r1, #1
    str  r1, [r0]

    @ Apaga o retângulo antigo da seta para não deixar rastro
    mov  r0, #SETA_X
    mov  r1, #SETA_Y_BASE
    mov  r2, #8
    mov  r3, #12
    CHAMA apagar_retangulo

    @ Desenha a seta na posição Y oscilante
    mov  r0, #SETA_X
    ldr  r1, =frame_contador
    ldr  r1, [r1]
    lsr  r1, r1, #3                 @ Deslocamento a cada 8 frames
    and  r1, r1, #3                 @ Oscila de 0 a 3 pixels
    add  r1, r1, #SETA_Y_BASE
    ldr  r2, =sprite_seta
    CHAMA desenhar_sprite

    @ Checa se apertou a tecla X (Botão A)
    ldr  r0, =REG_KEYINPUT
    ldrh r1, [r0]
    tst  r1, #KEY_A                 @ Bit 0 = 0 quando pressionado
    bne  game_loop                  @ Se não apertou, volta pro loop

    @ --- APERTOU X: Apaga a seta e abre a caixa ---
    mov  r0, #SETA_X
    mov  r1, #SETA_Y_BASE
    mov  r2, #8
    mov  r3, #12
    CHAMA apagar_retangulo

    mov  r0, #BOX_X
    mov  r1, #BOX_Y
    ldr  r2, =caixa_texto
    CHAMA desenhar_caixa_dialogo
    mov  r4, #2                     @ Atualiza para Estado 2 (Caixa Aberta)
    b    game_loop

caixa_ja_visivel:
    @ Mantém a caixa renderizada se o jogador andar em cima dela
    cmp  r12, #BOX_OVERLAP_Y
    bgt  redesenhar_caixa
    cmp  r10, #BOX_OVERLAP_Y
    ble  game_loop
redesenhar_caixa:
    mov  r0, #BOX_X
    mov  r1, #BOX_Y
    ldr  r2, =caixa_texto
    CHAMA desenhar_caixa_dialogo
    b    game_loop

longe_do_npc:
    cmp  r4, #0
    beq  game_loop                  @ Já estava longe

    @ Apaga a seta (se estava no Estado 1)
    mov  r0, #SETA_X
    mov  r1, #SETA_Y_BASE
    mov  r2, #8
    mov  r3, #12
    CHAMA apagar_retangulo

    @ Apaga a caixa de texto (se estava no Estado 2)
    cmp  r4, #2
    bne  reset_estado
    mov  r0, #BOX_X
    mov  r1, #BOX_Y
    mov  r2, #BOX_W
    mov  r3, #BOX_H
    CHAMA apagar_retangulo

    @ Redesenha o jogador caso ele tenha sido cortado ao apagar a caixa
    mov  r0, r11
    mov  r1, r12
    ldr  r2, =sprite_jogador
    CHAMA desenhar_sprite

reset_estado:
    mov  r4, #0                     @ Volta para Estado 0 (Longe)
    b    game_loop

@ ---------------------------------------------------------------------
carregar_cenario_inicial:
    ldr  r0, =REG_DMA3SAD
    ldr  r1, =cenario_map
    ldr  r2, =VRAM
    ldr  r3, =DMA_CENARIO
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]
    nop
    nop
    bx   lr

desenhar_npc:
    push {lr}
    mov  r0, #NPC_X
    mov  r1, #NPC_Y
    ldr  r2, =sprite_monitor
    CHAMA desenhar_sprite
    pop  {pc}

.pool

@ =====================================================================
@  ROTINAS DE VRAM (EXECUTADAS NA IWRAM - RÁPIDAS)
@ =====================================================================
.section .iwram, "ax", %progbits
.arm
.align 2

.global apagar_retangulo
apagar_retangulo:
    push {r4, r5, r6, r7, lr}
    mov  r6, #SCREEN_W
    mla  r4, r1, r6, r0
    lsl  r4, r4, #1
    ldr  r5, =cenario_map
    add  r5, r5, r4
    ldr  r6, =VRAM
    add  r4, r4, r6
    orr  r2, r2, #0x80000000        @ DMA: Enable | 16-bit
    ldr  r7, =REG_DMA3SAD
1:  str  r5, [r7]
    str  r4, [r7, #4]
    str  r2, [r7, #8]
    add  r5, r5, #(SCREEN_W * 2)
    add  r4, r4, #(SCREEN_W * 2)
    subs r3, r3, #1
    bne  1b
    pop  {r4, r5, r6, r7, pc}

.pool

.global desenhar_sprite
desenhar_sprite:
    push {r4, r5, r6, r7, r8, r9, r10, lr}
    ldrh r3, [r2], #2              @ Largura
    ldrh r4, [r2], #2              @ Altura

    ldr  r5, =VRAM
    mov  r6, #SCREEN_W
    mla  r7, r1, r6, r0
    lsl  r7, r7, #1
    add  r5, r5, r7

    mov  r8, #SCREEN_W
    sub  r8, r8, r3
    lsl  r8, r8, #1
    ldr  r10, =0x7C1F               @ Magenta (Transparente)

sprite_loop_y:
    mov  r7, r3
sprite_loop_x:
    ldrh r9, [r2], #2
    cmp  r9, r10
    beq  1f
    strh r9, [r5]
1:  add  r5, r5, #2
    subs r7, r7, #1
    bne  sprite_loop_x

    add  r5, r5, r8
    subs r4, r4, #1
    bne  sprite_loop_y

    pop  {r4, r5, r6, r7, r8, r9, r10, pc}

.pool

.global desenhar_caixa_dialogo
desenhar_caixa_dialogo:
    push {r4, r5, r6, r7, lr}
    ldrh r3, [r2], #2              @ Largura
    ldrh r4, [r2], #2              @ Altura

    mov  r6, #SCREEN_W
    mla  r5, r1, r6, r0
    lsl  r5, r5, #1
    ldr  r6, =VRAM
    add  r5, r5, r6

    lsl  r0, r3, #1
    orr  r3, r3, #0x80000000
    ldr  r7, =REG_DMA3SAD
1:  str  r2, [r7]
    str  r5, [r7, #4]
    str  r3, [r7, #8]
    add  r2, r2, r0
    add  r5, r5, #(SCREEN_W * 2)
    subs r4, r4, #1
    bne  1b

    pop  {r4, r5, r6, r7, pc}

.pool

@ =====================================================================
@  VARIÁVEIS E SPRITES AUXILIARES
@ =====================================================================
.data
.align 2

frame_contador:
    .word 0

@ Sprite da Seta (Triângulo Amarelo com Borda Preta - 8x8)
.align 2
sprite_seta:
    .hword 8, 8                     @ Largura = 8, Altura = 8
    @ Linha 0 (Topo - Borda preta)
    .hword 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
    @ Linha 1 (Borda preta nas pontas, amarelo no meio)
    .hword 0x7C1F, 0x0000, 0x03FF, 0x03FF, 0x03FF, 0x03FF, 0x0000, 0x7C1F
    @ Linha 2
    .hword 0x7C1F, 0x0000, 0x03FF, 0x03FF, 0x03FF, 0x03FF, 0x0000, 0x7C1F
    @ Linha 3 (Afunilando)
    .hword 0x7C1F, 0x7C1F, 0x0000, 0x03FF, 0x03FF, 0x0000, 0x7C1F, 0x7C1F
    @ Linha 4
    .hword 0x7C1F, 0x7C1F, 0x0000, 0x03FF, 0x03FF, 0x0000, 0x7C1F, 0x7C1F
    @ Linha 5 (Ponta inferior)
    .hword 0x7C1F, 0x7C1F, 0x7C1F, 0x0000, 0x0000, 0x7C1F, 0x7C1F, 0x7C1F
    @ Linha 6 (Transparente)
    .hword 0x7C1F, 0x7C1F, 0x7C1F, 0x7C1F, 0x7C1F, 0x7C1F, 0x7C1F, 0x7C1F
    @ Linha 7 (Transparente - espaço para animação de flutuação)
    .hword 0x7C1F, 0x7C1F, 0x7C1F, 0x7C1F, 0x7C1F, 0x7C1F, 0x7C1F, 0x7C1F

    