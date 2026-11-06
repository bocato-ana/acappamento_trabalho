@ =====================================================================
@  main.s  -  GBA Modo 3  -  jogador + NPC + seta interativa + caixa
@  devkitARM / mGBA
@
@  ARQUITETURA:
@   - BG2 (bitmap Modo 3): cenário + NPC + caixa de diálogo.
@       Só é escrito em eventos (início, abrir/fechar caixa), nunca
@       por causa do movimento do jogador.
@   - OBJ 0: jogador (64x64, 8bpp)  -> movido só alterando a OAM
@   - OBJ 1: seta flutuante (8x8, 4bpp) -> idem
@ =====================================================================

.equ REG_DISPCNT,       0x04000000
.equ REG_VCOUNT,        0x04000006
.equ REG_DMA3SAD,       0x040000D4     @ SAD, DAD (+4), CNT (+8)
.equ REG_KEYINPUT,      0x04000130
.equ VRAM,              0x06000000

.equ DISPCNT_MODE3_BG2, 0x0403
.equ FORCED_BLANK,      0x0080
.equ DISPCNT_MODE3_BG2_OBJ, 0x1443     @ Modo 3 + BG2 + OBJ ligado + mapeamento 1D

@ --- Memória de OBJ ---
@ Nos modos bitmap (3-5) os tiles de OBJ só existem a partir de 0x06014000
@ (tile 512 em diante). Abaixo disso fica o framebuffer.
.equ OBJ_VRAM,          0x06014000
.equ OBJ_PALETTE,       0x05000200
.equ OAM,               0x07000000

.equ OBJ_TILE_INDEX,    512            @ Jogador: 0x06014000 (4096 bytes)
.equ SETA_VRAM,         0x06015000     @ Logo após o jogador
.equ SETA_TILE_INDEX,   640            @ (0x06015000 - 0x06010000) / 32
.equ SETA_PAL_BANK,     15             @ Entradas 240-255 da paleta de OBJ
.equ SETA_PAL_ADDR,     (OBJ_PALETTE + SETA_PAL_BANK * 32)

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
    mov  r4,  #0                    @ Estado: 0=Longe, 1=Perto(Seta), 2=Caixa Aberta

    @ --- Background: cenário + NPC (desenhados UMA vez) ---
    bl   carregar_cenario_inicial
    bl   desenhar_npc

    @ --- Sprites ---
    CHAMA inicializar_oam
    CHAMA carregar_jogador_obj
    CHAMA carregar_seta_obj

    mov  r0, r11
    mov  r1, r12
    CHAMA atualizar_jogador_obj

    ldr  r0, =REG_DISPCNT
    ldr  r1, =DISPCNT_MODE3_BG2_OBJ
    strh r1, [r0]                   @ Liga a tela (BG2 + OBJ)

@ =====================================================================
@  LOOP PRINCIPAL DO JOGO  (1 iteração = 1 frame)
@ =====================================================================
game_loop:
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

    @ --- Move o sprite do jogador (só escreve na OAM, o fundo não é tocado) ---
    mov  r0, r11
    mov  r1, r12
    CHAMA atualizar_jogador_obj

    @ --- Checagem de Proximidade com o NPC (|X-NPC_X| <= PROX e |Y-NPC_Y| <= PROX) ---
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
    beq  game_loop                  @ Ela está no BG: nada a redesenhar

    @ --- ESTADO 1: PERTO DO NPC (seta flutuando, sprite) ---
    mov  r4, #1

    @ Incrementa contador de animação da seta
    ldr  r0, =frame_contador
    ldr  r1, [r0]
    add  r1, r1, #1
    str  r1, [r0]

    @ Y oscilante: base + 0..3 (muda a cada 8 frames)
    lsr  r1, r1, #3
    and  r1, r1, #3
    add  r0, r1, #SETA_Y_BASE
    CHAMA mostrar_seta_obj          @ Só atualiza a OAM, sem apagar nada

    @ Checa se apertou a tecla X (Botão A)
    ldr  r0, =REG_KEYINPUT
    ldrh r1, [r0]
    tst  r1, #KEY_A                 @ Bit 0 = 0 quando pressionado
    bne  game_loop                  @ Se não apertou, volta pro loop

    @ --- APERTOU X: esconde a seta e desenha a caixa no BG (uma única vez) ---
    CHAMA esconder_seta_obj

    mov  r0, #BOX_X
    mov  r1, #BOX_Y
    ldr  r2, =caixa_texto
    CHAMA desenhar_caixa_dialogo
    mov  r4, #2                     @ Estado 2 (Caixa Aberta)
    b    game_loop

longe_do_npc:
    cmp  r4, #0
    beq  game_loop                  @ Já estava longe

    CHAMA esconder_seta_obj         @ Esconde a seta (estado 1 ou 2)

    @ Restaura o cenário sob a caixa (se estava no Estado 2)
    cmp  r4, #2
    bne  reset_estado
    mov  r0, #BOX_X
    mov  r1, #BOX_Y
    mov  r2, #BOX_W
    mov  r3, #BOX_H
    CHAMA apagar_retangulo

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
@  ROTINAS (EXECUTADAS NA IWRAM - RÁPIDAS)
@ =====================================================================
.section .iwram, "ax", %progbits
.arm
.align 2

@ ---------------------------------------------------------------------
@ Esconde os 128 objetos (OAM zerada = sprites 8x8 visíveis em (0,0))
@ ---------------------------------------------------------------------
.global inicializar_oam
inicializar_oam:
    ldr  r0, =OAM
    mov  r1, #128
    mov  r2, #0x200                 @ Atributo 0: bit 9 = objeto desabilitado
1:  strh r2, [r0], #8
    subs r1, r1, #1
    bne  1b
    bx   lr

.pool

@ ---------------------------------------------------------------------
@ Jogador: copia tiles e paleta para a memória de OBJ
@ ---------------------------------------------------------------------
.global carregar_jogador_obj
carregar_jogador_obj:
    push {r4, lr}

    @ Copia os graficos: 4096 bytes = 1024 palavras
    ldr  r0, =REG_DMA3SAD
    ldr  r1, =sprite_jogador_obj_tiles
    ldr  r2, =OBJ_VRAM
    ldr  r3, =0x84000400
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]

    @ Copia a paleta: 124 cores = 124 halfwords
    ldr  r1, =sprite_jogador_obj_palette
    ldr  r2, =OBJ_PALETTE
    mov  r3, #124
    ldr  r4, =0x80000000
    orr  r3, r3, r4
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]

    pop  {r4, pc}

.pool

@ ---------------------------------------------------------------------
@ Seta: 1 tile 4bpp (32 bytes) + 3 cores na paleta do banco 15
@ ---------------------------------------------------------------------
.global carregar_seta_obj
carregar_seta_obj:
    @ Tile: 8 palavras
    ldr  r0, =REG_DMA3SAD
    ldr  r1, =seta_tile
    ldr  r2, =SETA_VRAM
    ldr  r3, =0x84000008            @ Enable | 32-bit | 8 palavras
    str  r1, [r0]
    str  r2, [r0, #4]
    str  r3, [r0, #8]

    @ Paleta (banco 15): 0=transparente, 1=preto, 2=amarelo
    ldr  r0, =SETA_PAL_ADDR
    mov  r1, #0
    strh r1, [r0]
    strh r1, [r0, #2]               @ Preto
    ldr  r1, =0x03FF
    strh r1, [r0, #4]               @ Amarelo
    bx   lr

.pool

@ ---------------------------------------------------------------------
@ OAM: jogador = objeto 0
@ ---------------------------------------------------------------------
.global atualizar_jogador_obj
atualizar_jogador_obj:
    @ Entrada: r0 = X, r1 = Y

    ldr  r2, =OAM

    @ Atributo 0: Y + modo de cor 8bpp
    orr  r3, r1, #0x2000
    strh r3, [r2]

    @ Atributo 1: X + tamanho 64x64
    ldr  r3, =0xC000
    orr  r3, r3, r0
    strh r3, [r2, #2]

    @ Atributo 2: índice inicial dos tiles
    ldr  r3, =OBJ_TILE_INDEX
    strh r3, [r2, #4]

    bx   lr

.pool

@ ---------------------------------------------------------------------
@ OAM: seta = objeto 1  (8 bytes após o objeto 0)
@ ---------------------------------------------------------------------
.global mostrar_seta_obj
mostrar_seta_obj:
    @ Entrada: r0 = Y
    ldr  r2, =OAM
    and  r0, r0, #0xFF
    strh r0, [r2, #8]               @ Attr0: Y, 4bpp, quadrado, visível
    mov  r3, #SETA_X
    strh r3, [r2, #10]              @ Attr1: X, tamanho 8x8
    ldr  r3, =(SETA_TILE_INDEX | (SETA_PAL_BANK << 12))
    strh r3, [r2, #12]              @ Attr2: tile + banco de paleta
    bx   lr

.global esconder_seta_obj
esconder_seta_obj:
    ldr  r2, =OAM
    mov  r3, #0x200                 @ Desabilita o objeto
    strh r3, [r2, #8]
    bx   lr

.pool

@ ---------------------------------------------------------------------
@ Restaura um retângulo do cenário (usado só ao fechar a caixa)
@ r0=x, r1=y, r2=largura, r3=altura
@ ---------------------------------------------------------------------
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

@ ---------------------------------------------------------------------
@ Desenha sprite (bitmap RGB555 com magenta transparente) no BG
@ Usado só no carregamento inicial (NPC)
@ ---------------------------------------------------------------------
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

@ ---------------------------------------------------------------------
@ Copia a caixa de diálogo para o BG (chamada só ao abrir)
@ ---------------------------------------------------------------------
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
@  VARIÁVEIS E GRÁFICOS AUXILIARES
@ =====================================================================
.data
.align 2

frame_contador:
    .word 0

@ Seta 8x8, 4bpp (1 tile = 8 palavras, 1 palavra por linha, pixel 0 = nibble baixo)
@ Índices: 0 = transparente, 1 = preto, 2 = amarelo
.align 2
seta_tile:
    .word 0x11111111                @ Linha 0: 1 1 1 1 1 1 1 1
    .word 0x01222210                @ Linha 1: 0 1 2 2 2 2 1 0
    .word 0x01222210                @ Linha 2
    .word 0x00122100                @ Linha 3: 0 0 1 2 2 1 0 0
    .word 0x00122100                @ Linha 4
    .word 0x00011000                @ Linha 5: 0 0 0 1 1 0 0 0
    .word 0x00000000                @ Linha 6
    .word 0x00000000                @ Linha 7
    