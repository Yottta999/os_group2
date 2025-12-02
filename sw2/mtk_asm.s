// TODO: implement
.include "defs.s"
.section .text
//タイマ関連のサブルーチン
hard_clock:
	**movem.l (レジスタ), -(%SP) /*実行中のタスクのレジスタ退避*/
	jsr addq /*addqの呼び出し*/
	jsr sched /*schedの呼びだし*/
	jsr swtch /*swtchの呼び出し*/
	**movem.l (%SP)+, (レジスタ)/*レジスタの復帰*/
	rts
init_timer:
	/*タイマのリセットをする*/
	move.l #SYSCALL_NUM_RESET_TIMER, %D0
	trap #0
	/*タイマのセットをする*/
	move.l #SYSCALL_NUM_SET_TIMER, %D0
	move.w #10000, %D1 /*1秒に設定*/
	move.l #hard_clock, %D2 /*hard_clockを呼び出すよう設定*/
	trap #0
