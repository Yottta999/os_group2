.section .text

** ここからデータ領域までのコメント：河野
*****************キューの初期化処理*******************************************************************
Init_Q:
	movem.l %d0-%d4/%a0-%a3,-(%sp)
	moveq 	#0, %d0			/* d0: キュー番号かつカウンタ */
	lea.l	Q_INFO, %a1		/* a1: Q_INFOの開始地点 */
	lea.l	Q0_START, %a2 		/* a2: Q0の先頭番地 */
	move.w	#B_SIZE, %d2		/* d2: 256 */
	move.w	#Q_INFO_SIZE, %d3	/* d3: 20 (キュー１個分の情報量) */

LOOP_Init:				/* d4: 計算用 */
	move.l	%d0,	%d4
	mulu	%d3,	%d4		/* d4 = d0 * Q_INFO_SIZE */
	move.l	%d4,	%a0
	add.l	%a1,	%a0		/* a0 = Q_INFO + d0 * Q_INFO_SIZE(各キュー情報の先頭) */
	
	move.l	%d0,	%d4			
	mulu	%d2,	%d4		/* d4 = d0 * B_SIZE */
	move.l	%d4,	%a3
	add.l	%a2,	%a3		/* a3 = Q0_START + d0 * B_SIZE(各キューの先頭) */

	move.l	%a3,	TOP_OFS(%a0)	
	move.l	%a3,	OUT_OFS(%a0)
	move.l	%a3,	IN_OFS(%a0)	/* TOP=OUT=IN=キューの先頭 */
	
	adda.l	#B_SIZE_MINUS,	%a3	/* a3=255 */
	move.l	%a3,	BOTTOM_OFS(%a0) /* BOTTOM=キューの末尾 */
	move.l	#0,	S_OFS(%a0)	/* S = 0(キューの要素は最初０ */

	addq	#1,	%d0		/* Q1にも同様の操作 */
	cmp	#2,	%d0
	bne	LOOP_Init		/* キュー2つ分繰返し */
	
end_Init:	
	movem.l (%sp)+, %d0-%d4/%a0-%a3
	rts
****************************************************************************************************


******INTERPUT*************************************************************************************
** 入力：d1.l（チャンネル）
** チャネル ch の送信キューからデータを一つ取り出し，実際に送信	
INTERPUT:
	movem.l %d0-%d2,-(%sp)
	
	/* (1) */
	move.w  #0x2700, %sr
	/* (2) */
	cmpi #0, %d1
	bne	End_INTERPUT		|ch=0以外なら何もしない
	/* (3) */
	moveq	#1, %d0
	jsr	OUTQ			|送信キューからデータを一つ取り出し
	*出力１：d0(失敗 0/ 成功 1 )
	*出力２：d1（取り出した8bitデータ）
	/* (4) */
	cmpi #0, %d0
	beq	INTERPUT_MASK		|取り出し失敗なら、送信割り込みをマスク（禁止）
	/* (5) */
	/* d1をUTX1に代入（下位８bit） */
	ori #0x0800, %D1                | ヘッダを代入
	move.w %D1, UTX1                | 送信
	bra	End_INTERPUT
INTERPUT_MASK:
	/* (4)' */		|送信失敗した場合、送信割り込み禁止
	move.w	USTCNT1, %d2
	andi.w	#0xFFFB, %d2	| 0xFFFB = 1111111111111011 
	move.w	%d2,	USTCNT1 | USTCNT1のTXEEを0にする 
	bra End_INTERPUT
End_INTERPUT:
	movem.l (%sp)+, %d0-%d2
	rts

	
******************************************************************************************************	

*********PUTSTRING************************************************************************************
** データを送信キューに格納し，送信割り込みを開始	
** 入力１：チャネル ch → %D1.L
** 入力２：データ読み込み先の先頭アドレス p → %D2.L
** 入力３：送信するデータ数 size → %D3.L
** 出力  ：実際に送信したデータ数 sz → %D0.L
	
PUTSTRING:
	movem.l %d1-%d6/%a0,-(%sp)
	/* (1) */
	cmpi 	#0, %d1		
	bne	End_PUTSTRING	| ch=0以外なら何もしない
	/* (2) */
	moveq	#0, %d4  	| d4 = sz = 0 
	movea.l	%d2, %a0 	| a0 = i = p 
	/* (3) */
	cmpi 	#0, %d3		| 送信サイズが０のとき
	beq	PUTSTRING_10
LOOP_PUTSTRING:	
	/* (4) */
	cmp	%d3, %d4	| 送信サイズ == 送信した数？
	beq	PUTSTRING_9
	/* (5) */
	moveq	#1, %d0
	move.b	(%a0), %d1	| a0:データ読み込み先の先頭アドレス
	jsr	INQ
	*d0 :キュー番号
	*d1 :8bitデータ
	*出力：d0(失敗 0/ 成功 1 )
	/* (6) */
	cmpi 	#0, %d0		| INQ失敗？
	beq	PUTSTRING_9	
	/* (7) */
	addq	#1, %d4		| 送信した数に１を足す
	addq	#1, %a0		| 読み込むデータを次に
	/* (8) */
	bra 	LOOP_PUTSTRING	| 全て送信 or INQ失敗まで続ける
PUTSTRING_9:
	/* (9) */
	move.w	USTCNT1, %d6
	ori.w	#0x0004, %d6	| 0xFFFB = 0000000000000100 
	move.w	%d6,	USTCNT1 | 送信割込み許可 
PUTSTRING_10:
	/* (10) */
	move.l	%d4, %d0	| d0(出力) = sz(送信した数)
End_PUTSTRING:
	movem.l (%sp)+, %d1-%d6/%a0
	rts
******************************************************************************************************

	
**********INQ**********************************************************************
** 入力１：d0（キュー番号）
** 入力２：d1（8bitデータ）
** 出力　：d0(失敗 0/ 成功 1 )
INQ:
	/* (1) */
	move.w %sr, -(%sp)
	movem.l %d2-%d7/%a0-%a6,-(%sp)

	/* (2) */
	move.w #0x2700,%sr

	** キューd0について、キュー情報の先頭・キューの先頭のアドレスをそれぞれ取得
	******************************************************************************************
	lea.l	Q_INFO, %a1		/* a1: Q_INFOの開始地点 */
	lea.l	Q0_START, %a2 		/* a2: Q0の先頭番地 */
	move.w	#B_SIZE, %d2		/* d2: 256 */
	move.w	#Q_INFO_SIZE, %d3	/* d3: 20 (キュー１個分の情報量) */
	
	move.l	%d0,	%d4
	mulu	%d3,	%d4		/* d4 = d0 * Q_INFO_SIZE */
	move.l	%d4,	%a0
	add.l	%a1,	%a0		/* a0 = Q_INFO + d0 * Q_INFO_SIZE(各キュー情報の先頭) */
	
	move.l	%d0,	%d4			
	mulu	%d2,	%d4		/* d4 = d0 * B_SIZE */
	move.l	%d4,	%a3
	add.l	%a2,	%a3		/* a3 = Q0_START + d0 * B_SIZE(各キューの先頭) */
	******************************************************************************************

	/* (3) */
	move.l	S_OFS(%a0), %d4
	cmpi.l	#256, %d4		| s==256?（満杯のキューに入れようとしているか？）
	beq	INQ_Failure	
	bra	INQ_Step1
INQ_Failure:
	moveq	#0, %d0
	bra	END_INQ			| 0（失敗）を出力し、終了
INQ_Step1:
	/* (4) */
	move.l	IN_OFS(%a0), %a4	| a4:キュー中、データを入れるべき番地
	move.b	%d1, (%a4)		| m[in] = data

	/* (5) */ ** inがキューの終端に来たら、循環させる
	movea.l	IN_OFS(%a0), %a4	| a4 = in
	movea.l	BOTTOM_OFS(%a0), %a5	| a5 = bottom
	cmpa.l	%a4, %a5		| in == bottom?
	beq	BACK_IN			
	movea.l	IN_OFS(%a0), %a4
	addq	#1, %a4
	move.l	%a4, IN_OFS(%a0)	| in++
	bra	INQ_Step2
BACK_IN:
	movea.l	TOP_OFS(%a0), %a4
	move.l	%a4, IN_OFS(%a0)	| in = top
INQ_Step2:
	/* (6) */
	move.l	S_OFS(%a0), %d4
	addq.l	#1, %d4			
	move.l	%d4, S_OFS(%a0)		| s++
	moveq	#1, %d0			| d0 = 1（成功）
	
END_INQ:	
	/* (7) */
	movem.l (%sp)+, %d2-%d7/%a0-%a6
	move.w (%sp)+, %sr
	rts

***********************************************************************************


**********OUTQ**********************************************************************
** 入力　：d0（キュー番号）
** 出力１：d0(失敗 0/ 成功 1 )
** 出力２：d1（取り出した8bitデータ）

OUTQ:
	/* (1) */
	move.w %sr, -(%sp)
	movem.l %d2-%d7/%a0-%a6,-(%sp) 

	/* (2) */
	move.w #0x2700,%sr

	** キューd0について、キュー情報の先頭・キューの先頭のアドレスをそれぞれ取得
	******************************************************************************************
	lea.l	Q_INFO, %a1		/* a1: Q_INFOの開始地点 */
	lea.l	Q0_START, %a2 		/* a2: Q0の先頭番地 */
	move.w	#B_SIZE, %d2		/* d2: 256 */
	move.w	#Q_INFO_SIZE, %d3	/* d3: 20 (キュー１個分の情報量) */
	
	move.l	%d0,	%d4
	mulu	%d3,	%d4		/* d4 = d0 * Q_INFO_SIZE */
	move.l	%d4,	%a0
	add.l	%a1,	%a0		/* a0 = Q_INFO + d0 * Q_INFO_SIZE(各キュー情報の先頭) */
	
	move.l	%d0,	%d4			
	mulu	%d2,	%d4		/* d4 = d0 * B_SIZE */
	move.l	%d4,	%a3
	add.l	%a2,	%a3		/* a3 = Q0_START + d0 * B_SIZE(各キューの先頭) */
	******************************************************************************************

	/* (3) */
	move.l	S_OFS(%a0), %d4
	cmpi.l	#0, %d4
	beq	OUTQ_Failure		| s == 0?（空のキューから取り出そうとしている？）
	bra	OUTQ_Step1
OUTQ_Failure:
	moveq	#0, %d0
	bra	END_OUTQ
OUTQ_Step1:
	/* (4) */
	move.l	OUT_OFS(%a0), %a4	| a4 = out
	move.b	(%a4), %d1		| d1 = m[out]

	/* (5) */
	movea.l	OUT_OFS(%a0), %a4	| a4 = out
	movea.l	BOTTOM_OFS(%a0), %a5	| a5 = bottom
	cmpa.l	%a4, %a5		| out == bottom?（取り出し場所のポインタが、キューの末尾に到達？）
	beq	BACK_OUT
	movea.l	OUT_OFS(%a0), %a4
	addq	#1, %a4
	move.l	%a4, OUT_OFS(%a0)	| out++
	bra	OUTQ_Step2
BACK_OUT:
	movea.l	TOP_OFS(%a0), %a4
	move.l	%a4, OUT_OFS(%a0)	| out = top
OUTQ_Step2:
	/* (6) */
	move.l	S_OFS(%a0), %d4		
	subq.l	#1, %d4
	move.l	%d4, S_OFS(%a0)		| s--
	moveq	#1, %d0			| d0 = 1（成功）
	
END_OUTQ:	
	/* (7) */
	movem.l (%sp)+, %d2-%d7/%a0-%a6
	move.w (%sp)+, %sr
	rts

***********************************************************************************


	
.section .data
***********************************
** キュー用のメモリ領域確保と定数定義
***********************************
	.equ	B_SIZE, 	256
	.equ	B_SIZE_MINUS,	255
	.equ	Q_NUM,		2
	
	.equ	TOP_OFS,	0
	.equ	OUT_OFS,	4
	.equ	IN_OFS,		8
	.equ	BOTTOM_OFS,	12
	.equ	S_OFS,		16
	.equ	Q_INFO_SIZE,	20

	.even
Q0_START: 	.ds.b	B_SIZE
Q1_START: 	.ds.b	B_SIZE
	.even
Q_INFO:
	.ds.b	Q_INFO_SIZE * Q_NUM
