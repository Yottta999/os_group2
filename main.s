TT:

	movem.l %d0-%d7/%a0-%a3,-(%sp)

	addq.w  #1, TTC
	cmpi.w  #3600, TTC
	beq     TTKILL

	lea.l SECC, %a0
	lea.l MINC, %a1
	
	addq.b  #1, (%a0)            | 秒++
	cmpi.b  #60, (%a0)
	bne    DISP_UPDATE
	clr.b  (%a0)
	
	addq.b  #1, (%a1)            | 分++
	cmpi.b  #60, (%a1)
	bne   DISP_UPDATE
	clr.b  (%a1)

DISP_UPDATE:
    lea.l   DIGITS,%a0        /* フォントテーブル先頭 */
    lea.l   DISP_BUF,%a1        /* 出力先バッファ */

    move.b  MINC,%d0            /* 分 (例: 12) */
    move.b  SECC,%d1            /* 秒 (例: 34) */

    /** 分(十の位・一の位)を分解 **/
    move.w  %d0,%d2
    divu    #10,%d2             /* 商=十の位(%d2), 余り=一の位(%d3) */
    move.w  %d2,%d3
    swap    %d3

    /** 秒(十の位・一の位)を分解 **/
    move.w  %d1,%d4
    divu    #10,%d4             /* 商=十の位(%d4), 余り=一の位(%d5) */
    move.w  %d4,%d5
    swap    %d5

    /** 行ループ: 0〜5行 **/
    moveq.l   #0,%d6
    lea.l   DISP_BUF,%a2

ROW_LOOP:
    move.b  %d2,%d7
    bsr     DRAW_DIGIT_ROW      /* 分の十の位 */
    move.b  %d3,%d7
    bsr     DRAW_DIGIT_ROW      /* 分の一の位 */
    move.b  #10,%d7
    bsr     DRAW_DIGIT_ROW      /* コロン */
    move.b  %d4,%d7
    bsr     DRAW_DIGIT_ROW      /* 秒の十の位 */
    move.b  %d5,%d7
    bsr     DRAW_DIGIT_ROW      /* 秒の一の位 */

    move.b  #'\r',(%a2)+
    move.b  #'\n',(%a2)+

    addq.w  #1,%d6
    cmpi.w  #6,%d6
	blt.s   ROW_LOOP

TTKILL:
	clr.w TTC
	
    movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

/****************************************************************
*** サブルーチン: DRAW_DIGIT_ROW
*** %d7 = 描画する文字番号 (0〜10)
*** %d6 = 行番号 (0〜4)
*** %a0 = FONT_TAB先頭
*** %a2 = DISP_BUFの現在行位置
****************************************************************/
DRAW_DIGIT_ROW:
    moveq   #25,%d0
    mulu    %d7,%d0             /* 文字番号×20バイト */
    move.l  %a0,%a3
    adda.l  %d0,%a3             /* 文字の先頭へ */
    adda.l  %d6,%a3             /* 行方向のオフセット */

    moveq   #5,%d1              /* 4列分ループ(0〜3) */
COL_LOOP:
    move.b  (%a3)+,%d2
    cmpi.b  #1,%d2
    beq.s   PUT_SHARP
    move.b  #' ',(%a2)+
    bra.s   NEXT_COL
PUT_SHARP:
    move.b  #'#',(%a2)+
NEXT_COL:
    dbra    %d1,COL_LOOP

    /** 各数字の間にスペース1つ **/
    move.b  #' ',(%a2)+
    rts

.section .data
SECC:	.dc.b 0
	.even
MINC:	.dc.b 0
	.even
TTC:	.dc.w 0
	.even

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
COLON:
dc.b 0,0,0,0,0, 0,0,1,0,0, 0,0,0,0,0, 0,0,1,0,0, 0,0,0,0,0

****************************************************************
*** 初期値の無いデータ領域
****************************************************************
.section .bss
DISP_BUF:
.ds.b 256
