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
    move.b MINC, %d0          | 分
    move.b SECC, %d1          | 秒

    move.w %d0, %d2
    divu    #10, %d2          | D2=分十, D3=分一
    move.w %d2, %d3
    swap    %d3

    move.w %d1, %d4
    divu    #10, %d4          | D4=秒十, D5=秒一
    move.w %d4, %d5
    swap    %d5

    moveq.l #0, %d6           | 行番号 0〜4
ROW_LOOP:
    moveq.l #0, %d7           | 文字カウンタ 0〜4
CHAR_LOOP:
    cmpi.b #5, %d7
    beq ROW_END

    move.b %d7, %d0
    move.l %d6, %d1           | 行番号
    bsr SEND_DIGIT_ROW

    addq.b #1, %d7
    bra CHAR_LOOP
ROW_END:
    ** 行末に改行をPUTSTRING **
    lea.l CRLF_BUF, %a0
    move.l #SYSCALL_NUM_PUTSTRING, %d0
    clr.l %d1
    move.l %a0, %d2
    move.l #2, %d3              | "\r\n" の長さ
    trap #0

    addq.l #1, %d6
    cmpi.l #5, %d6
    blt ROW_LOOP

    movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

****************************************************************
*** サブルーチン: SEND_DIGIT_ROW
*** %d0 = 文字番号 0〜10 (分十, 分一, コロン, 秒十, 秒一)
*** %d1 = 行番号 0〜4
*** DIGITSを5文字ずつPUTSTRING
****************************************************************
SEND_DIGIT_ROW:
    lea.l DIGITS, %a0
    move.l %a0, %a2

    mulu %d1, #7               | 各行7バイト固定（1文字7バイト）
    mulu %d0, #35              | 文字番号×35バイト
    adda.l %a2, %a2

    moveq #5, %d3              | 5文字送信カウンタ
SEND_LOOP:
    cmpi.b #0, %d3
    beq SEND_END

    move.l #SYSCALL_NUM_PUTSTRING, %d0
    clr.l %d1
    move.l %a2, %d2
    move.l #1, %d3              | 1文字送信
    trap #0

    addq.l #1, %a2
    subq.b #1, %d3
    bra SEND_LOOP
SEND_END:
    rts

.section .data
SECC: .dc.b 0
MINC: .dc.b 0

DIGITS:
.ascii "##### ","#   # ","#   # ","#   # ","##### "  | 0
.ascii "    # ","    # ","    # ","    # ","    # "  | 1
.ascii "##### ","    # ","##### ","#    ","##### "  | 2
.ascii "##### ","    # ","##### ","    # ","##### "  | 3
.ascii "#   # ","#   # ","##### ","    # ","    # "  | 4
.ascii "##### ","#    ","##### ","    # ","##### "  | 5
.ascii "##### ","#    ","##### ","#   # ","##### "  | 6
.ascii "##### ","    # ","    # ","    # ","    # "  | 7
.ascii "##### ","#   # ","##### ","#   # ","##### "  | 8
.ascii "##### ","#   # ","##### ","    # ","##### "  | 9
.ascii "  ","  ","  ","  ","  "                               | コロン

CRLF_BUF:
.ascii "\r\n"
