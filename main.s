.section .text
.even
MAIN:
    move.w #0x0000, %SR           | USER MODE
    lea.l USR_STK_TOP, %SP        | スタック設定

    ** タイマー初期化 **
    move.l #SYSCALL_NUM_RESET_TIMER, %D0
    trap #0
    move.l #SYSCALL_NUM_SET_TIMER, %D0
    move.w #10000, %D1
    move.l #TT, %D2
    trap #0

MAIN_LOOP:
    bra MAIN_LOOP                  | メインはタイマー割り込みで描画

****************************************************************
*** タイマー割り込み TT
****************************************************************
TT:
    movem.l %d0-%d7/%a0-%a3,-(%sp)

    addq.b  #1, SECC
    cmpi.b  #60, SECC
    bne DISP_UPDATE
    clr.b   SECC
    addq.b  #1, MINC
    cmpi.b  #60, MINC
    bne DISP_UPDATE
    clr.b   MINC

DISP_UPDATE:
    move.b MINC, %d0              | 分
    move.b SECC, %d1              | 秒

    move.w %d0, %d2
    divu    #10, %d2              | D2=分十, D3=分一
    move.w %d2, %d3
    swap    %d3

    move.w %d1, %d4
    divu    #10, %d4              | D4=秒十, D5=秒一
    move.w %d4, %d5
    swap    %d5

    moveq.l #0, %d6               | 行番号 (0〜4)
ROW_LOOP:
    ** 各行に対して5文字を順に出力 **
    move.b %d2, %d0
    move.l %d6, %d1
    bsr SEND_DIGIT_ROW            | 分十

    move.b %d3, %d0
    move.l %d6, %d1
    bsr SEND_DIGIT_ROW            | 分一

    move.b #10, %d0
    move.l %d6, %d1
    bsr SEND_DIGIT_ROW            | コロン

    move.b %d4, %d0
    move.l %d6, %d1
    bsr SEND_DIGIT_ROW            | 秒十

    move.b %d5, %d0
    move.l %d6, %d1
    bsr SEND_DIGIT_ROW            | 秒一

    ** 改行を出力 **
    move.l #SYSCALL_NUM_PUTSTRING, %d0
    clr.l %d1
    move.l #CRLF_BUF, %d2
    move.l #2, %d3
    trap #0

    addq.l #1, %d6
    cmpi.l #5, %d6
	blt ROW_LOOP
	
    move.l #SYSCALL_NUM_PUTSTRING, %d0
    clr.l %d1
    move.l #TOP, %d2
    move.l #4, %d3
	trap #0
	
    movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

****************************************************************
*** サブルーチン: SEND_DIGIT_ROW
*** %d0 = 文字番号 (0〜9, 10=コロン)
*** %d1 = 行番号 (0〜4)
*** 各文字は 6文字×5行 固定配置
****************************************************************
SEND_DIGIT_ROW:
    movem.l %d2-%d7/%a2,-(%sp)      | 呼び出しで使うレジスタを保存

    lea.l DIGITS, %a2               | a2 = base address
    move.l %d0, %d2                 | d2 = 文字番号
    mulu #30, %d2                   | d2 = 文字番号 * 30
    add.l %d2, %a2                  | a2 -> DIGITS + 文字番号*30

    move.l %d1, %d3                 | d3 = 行番号
    mulu #6, %d3                    | d3 = 行番号 * 6
    add.l %d3, %a2                  | a2 -> DIGITS + 文字番号*30 + 行番号*6

    move.l #SYSCALL_NUM_PUTSTRING, %d0
    clr.l  %d1
    move.l %a2, %d2
    move.l #6, %d3                  | 6バイト出力
    trap    #0

    movem.l (%sp)+, %d2-%d7/%a2
    rts


	
.section .data
SECC: .dc.b 0
	.even
MINC: .dc.b 0
	.even
DIGITS:
.ascii "##### ","#   # ","#   # ","#   # ","##### "  | 0
.ascii "    # ","    # ","    # ","    # ","    # "  | 1
.ascii "##### ","    # ","##### ","#     ","##### "  | 2
.ascii "##### ","    # ","##### ","    # ","##### "  | 3
.ascii "#   # ","#   # ","##### ","    # ","    # "  | 4
.ascii "##### ","#     ","##### ","    # ","##### "  | 5
.ascii "##### ","#     ","##### ","#   # ","##### "  | 6
.ascii "##### ","    # ","    # ","    # ","    # "  | 7
.ascii "##### ","#   # ","##### ","#   # ","##### "  | 8
.ascii "##### ","#   # ","##### ","    # ","##### "  | 9
.ascii "      ","  #   ","      ","  #   ","      "                               | コロン
TOP:
	.ascii "\x1b[5A"
	.even
CRLF_BUF:
	.ascii "\r\n"
	.even

****************************************************************
*** 初期値の無いデータ領域
****************************************************************
.section .bss
BUF:
.ds.b 256 | BUF[256]
.even
USR_STK:
.ds.b 0x4000 | ユーザスタック領域
.even
USR_STK_TOP: | ユーザスタック領域の最後
