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
LOOP1:
    move.l #SYSCALL_NUM_GETSTRING, %D0
    move.l #0, %D1 | ch = 0
    move.l #BUF, %D2 | p = #BUF
    move.l #256, %D3 | size = 256
    trap #0
    move.b BUF, %d4
    cmpi.b #'c', %d4
    bne LOOP1   
    bra CHANGE_MODE
LOOP2:
    move.l #SYSCALL_NUM_GETSTRING, %D0
    move.l #0, %D1
    move.l #BUF, %D2
    move.l #256, %D3
    trap #0
    move.b BUF, %d4
    cmpi.b #'v', %d4
    bne LOOP2
	
CHANGE_MODE:	
    /* MODE変更 (0=簡易, 1=7セグ) */
    move.b MODE, %d0
    eor.b #1, %d0
    move.b %d0, MODE
    cmpi.b #0, %d0
    beq LOOP1
    bra LOOP2
	
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
    bra LED_DISPLAY

TTKILL:
	clr.w TTC
	clr.b MINC
	move.b #0xff, SECC


TTEND:
    movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

**************************************************************}
*** 
***************************************************************
SIMPLE_DISPLAY:
    move.b #0x20,LED0
    move.b #0x20,LED1
    move.b #0x20,LED2
    move.b #0x20,LED3
    move.b #0x20,LED4
    move.b #0x20,LED5
    move.b #0x20,LED6
    move.b #0x20,LED7
    lea.l NUM, %a2           | 数字テーブル
    lea.l DISP, %a3          | 出力先 "00:00\r"
    move.b  (%a1), %d0
    jsr     CALC_OFFSET
    move.b  (%a2,%d5.w), (%a3)+  | tens
    move.b  (%a2,%d6.w), (%a3)+  | ones

    move.b  #':', (%a3)+

    move.b  (%a0), %d0
    jsr     CALC_OFFSET
    move.b  (%a2,%d5.w), (%a3)+  | tens
    move.b  (%a2,%d6.w), (%a3)+  | ones


    move.l  #SYSCALL_NUM_PUTSTRING, %d0
    clr.l   %d1
    move.l  #DISP, %d2
    moveq   #6, %d3
    trap    #0
    bra TTEND


***************************************************************
*** 
***************************************************************
LED_DISPLAY:
    move.l  #SYSCALL_NUM_PUTSTRING, %d0
    clr.l   %d1
    move.l  #DELETE, %d2
    moveq   #6, %d3
    trap    #0

    lea.l NUM, %a2           | 数字テーブル
    move.b  (%a1), %d0
    jsr     CALC_OFFSET
    move.b  (%a2, %d5.w), LED5
    move.b  (%a2, %d6.w), LED4

    move.b  #':', LED3

    move.b  (%a0), %d0
    jsr     CALC_OFFSET
    move.b  (%a2, %d5.w), LED2
    move.b  (%a2, %d6.w), LED1

    bra TTEND

****************************************************************
*** 2桁表示サブルーチン
*** D0 = 数値(0–99)
*** A2 = 数字テーブル("0123456789")
*** A3 = 出力位置
****************************************************************
CALC_OFFSET:
	move.l  %d0, %d6
	divu    #10, %d6           | 商=tens, 余り=ones
        move.w  %d6, %d5
	swap    %d6
	rts



**************************************************
** データ領域
**************************************************
.section .data
NUM:    .ascii "0123456789"
        .even
DISP:   .ascii "00:00\r"
        .even
DELETE:  .ascii "     \r"
        .even
SECC:	.dc.b 0
	.even
MINC:	.dc.b 0
	.even
TTC:	.dc.w 0
	.even
MODE:   .dc.b 0       | 0=画面, 1=LED
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
