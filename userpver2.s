
****************************************************************
*** プログラム領域
****************************************************************
.section .text
.even
MAIN:
    ** 走行モードとレベルの設定 (「ユーザモード」への移行処理)
    move.w #0x0000, %SR   | USER MODE, LEVEL 0
    lea.l USR_STK_TOP,%SP | user stack の設定

    ** システムコールによる RESET_TIMER の起動
    move.l #SYSCALL_NUM_RESET_TIMER, %D0
    trap #0

    ** システムコールによる SET_TIMER の起動
    move.l #SYSCALL_NUM_SET_TIMER, %D0
    move.w #10000, %D1
    move.l #TT, %D2
    trap #0

    ** 初期画面表示
    move.l  #SYSCALL_NUM_PUTSTRING, %d0
    clr.l   %d1
    move.l  #DISP, %d2
    move.l   #6, %d3
    trap    #0

	
******************************
* 空ループ
******************************
LOOP:
    move.l #SYSCALL_NUM_GETSTRING, %D0
    move.l #0, %D1     | ch = 0
    move.l #BUF, %D2   | p = #BUF
    move.l #256, %D3   | size = 256
    trap #0

    move.b BUF, CHR    | 入力文字を表示用CHRに設定
    move.b CHR, %d0
    cmpi.b #' ', %d0
    bne LOOP   

    /* MODE変更 (0=簡易, 1=7セグ) */
    move.b MODE, %d0
    eor.b #1, %d0
    move.b %d0, MODE
    bra LOOP

********************************
* タイマ割込み処理（１秒ごと）
********************************
TT:

	movem.l %d0-%d7/%a0-%a3,-(%sp)

	addq.w  #1, TTC
	cmpi.w  #3600, TTC
	beq     TTKILL

	lea.l SECC, %a0
	lea.l MINC, %a1
	
	addq.b  #1, (%a0)            | 秒++
	cmpi.b  #60, (%a0)
	bne    DISPLAY_UPDATE
	clr.b  (%a0)
	
	addq.b  #1, (%a1)            | 分++
	cmpi.b  #60, (%a1)
	bne   DISPLAY_UPDATE
	clr.b  (%a1)

DISPLAY_UPDATE:
    cmpi.b #0, MODE
    beq SIMPLE_DISPLAY
    bra SEG7_DISPLAY


***************************************************************
SIMPLE_DISPLAY:
    lea.l NUM, %a2           | 数字テーブル
    lea.l DISP, %a3          | 出力先 "00:00\r"
    move.b  (%a1), %d0
    jsr     DISP_TWO_DIGITS
    move.b  #':', (%a3)+
    move.b  (%a0), %d0
    jsr     DISP_TWO_DIGITS

    move.l  #SYSCALL_NUM_PUTSTRING, %d0
    clr.l   %d1
    move.l  #DISP, %d2
    moveq   #6, %d3
    trap    #0
    bra TTEND

****************************************************************
*** SIMPLE_DISPLAY用2桁表示サブルーチン
*** D0 = 数値(0–99)
*** A2 = 数字テーブル("0123456789")
*** A3 = 出力位置
****************************************************************
DISP_TWO_DIGITS:
	andi.w #$00ff, %d0
	move.l  %d0, %d6
	divu    #10, %d6           | 商=tens, 余り=ones
	move.b  (%a2,%d6.w), (%a3)+  | tens
	swap    %d6
	move.b  (%a2,%d6.w), (%a3)+  | ones
	rts
******************************************************************


SEG7_DISPLAY:
    lea.l   DIGITS,%a2        
    lea.l   DISP_BUF,%a1        

    move.b  MINC,%d0          | %d0 = 分
    move.b  SECC,%d1          | %d1 = 秒

    /** 分(十の位・一の位)を分解 **/
    move.w  %d0,%d2
    divu    #10,%d2           | 商=%d2, 余り=%d3
    move.w  %d2,%d3
    swap    %d3

    /** 秒(十の位・一の位)を分解 **/
    move.w  %d1,%d4
    divu    #10,%d4           | 商=%d4, 余り=%d5
    move.w  %d4,%d5
    swap    %d5

    moveq.l   #0,%d6          | 行ループ 0～4

ROW_LOOP:
    lea.l DIGITS, %a0
    lea.l   DISP_BUF,%a2
    move.l  %d6, %d1
    mulu    #32,%d1             | 1行32バイト間隔
    adda.l  %d1,%a2

    move.b  %d2,%d7
    bsr     DRAW_DIGIT_ROW      | 分の十の位 
    move.b  %d3,%d7
    bsr     DRAW_DIGIT_ROW      | 分の一の位 
    move.b  #10,%d7
    bsr     DRAW_DIGIT_ROW      | コロン
    move.b  %d4,%d7
    bsr     DRAW_DIGIT_ROW      | 秒の十の位
    move.b  %d5,%d7
    bsr     DRAW_DIGIT_ROW      | 秒の一の位

    move.b  #'\r',(%a2)+
    move.b  #'\n',(%a2)+

    addq.l  #1,%d6
    cmpi.l  #5,%d6
    blt.s   ROW_LOOP

    /* カーソルをホームに */
    move.l  #SYSCALL_NUM_PUTSTRING, %d0
    clr.l   %d1
    move.l  #ESC_HOME, %d2
    moveq   #3, %d3      
    trap    #0

    /* 時間更新 */
    move.l  #SYSCALL_NUM_PUTSTRING, %d0
    clr.l   %d1
    move.l  #DISP_BUF, %d2
    move.l  #160, %d3
    trap    #0
    bra TTEND

TTKILL:
    clr.w TTC
    move.l #SYSCALL_NUM_RESET_TIMER, %d0
    trap #0
TTEND:
    movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

****************************************************************
*** サブルーチン: DRAW_DIGIT_ROW
*** %d7 = 描画する文字番号 (0〜10)
*** %d6 = 行番号 (0〜4)
*** %a0 = FONT_TAB先頭
*** %a2 = DISP_BUFの現在行位置
****************************************************************
DRAW_DIGIT_ROW:
    moveq   #25,%d0
    mulu    %d7,%d0             | 文字番号×25バイト
    move.l  %a0,%a3
    adda.l  %d0,%a3             | 文字の先頭へ
    adda.l  %d6,%a3             | 行方向のオフセット

    moveq   #4,%d1 
COL_LOOP:
    move.b  (%a3)+,%d2
    cmpi.b  #1,%d2
    beq.s   PUT_SHARP
    move.b  #' ',(%a2)+
    bra.s   NEXT_COL
PUT_SHARP:
    move.b CHR, %d2
    move.b  %d2,(%a2)+
NEXT_COL:
    dbra    %d1,COL_LOOP

    move.b  #' ',(%a2)+          | 数字間スペース
    rts

**************************************************
** データ領域
**************************************************
.section .data
NUM:    .ascii "0123456789"
        .even
DISP:   .ascii "00:00\r"
        .even
SECC:	.dc.b 0
	.even
MINC:	.dc.b 0
	.even
TTC:	.dc.w 0
	.even
MODE:   .dc.b 0       | 0=簡易, 1=7セグ
        .even
CHR:    .dc.b 0x23
        .even

/* 数字とコロンのフォントデータ */
DIGITS:
/* 0 */
dc.b 1,1,1,1,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1
/* 1 */
dc.b 0,0,1,0,0, 0,1,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,1,1,1,0
/* 2 */
dc.b 1,1,1,1,1, 0,0,0,0,1, 1,1,1,1,1, 1,0,0,0,0, 1,1,1,1,1
/* 3 */
dc.b 1,1,1,1,1, 0,0,0,0,1, 0,1,1,1,1, 0,0,0,0,1, 1,1,1,1,1
/* 4 */
dc.b 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1, 0,0,0,0,1, 0,0,0,0,1
/* 5 */
dc.b 1,1,1,1,1, 1,0,0,0,0, 1,1,1,1,1, 0,0,0,0,1, 1,1,1,1,1
/* 6 */
dc.b 1,1,1,1,1, 1,0,0,0,0, 1,1,1,1,1, 1,0,0,0,1, 1,1,1,1,1
/* 7 */
dc.b 1,1,1,1,1, 0,0,0,0,1, 0,0,0,1,0, 0,0,1,0,0, 0,0,1,0,0
/* 8 */
dc.b 1,1,1,1,1, 1,0,0,0,1, 1,1,1,1,1, 1,0,0,0,1, 1,1,1,1,1
/* 9 */
dc.b 1,1,1,1,1, 1,0,0,0,1, 1,1,1,1,1, 0,0,0,0,1, 1,1,1,1,1
/* コロン*/
dc.b 0,0,0,0,0, 0,0,1,0,0, 0,0,0,0,0, 0,0,1,0,0, 0,0,0,0,0

ESC_HOME: .ascii "\x1b[H"

/* 初期表示 */
DISP_BUF:
.ascii "##### #####       ##### ##### \r\n"
.ascii "#   # #   #   #   #   # #   # \r\n"
.ascii "#   # #   #       #   # #   # \r\n"
.ascii "#   # #   #   #   #   # #   # \r\n"
.ascii "##### #####       ##### ##### \r\n"

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
