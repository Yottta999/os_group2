.section .bss
task_p:	.ds.b 4 /*タイマ割り込みで実行するプログラムの先頭アドレスを格納*/

/*タイマルーチン*/

.section .text

/*
タイマ1コントロールレジスタ
TCTL1 
    bit 4  : Interrupt Request Enable（比較割り込み） 0=disable, 1=enable
    bit 3-1: Clock Source 001 = 入力は SYSCLK．010 = 入力は SYSCLK/16．011 = 入力は TIN．1xx = 入力は CLK32．
    bit 0  : Timer Enable. 0=disable. 1=enable
（楠田・鴻上）
*/


/* RESET_TIMER
 *   タイマ割り込みを不可に。タイマを停止。（楠田・鴻上）
 */
RESET_TIMER:
	move.w #0x0004, TCTL1 | TCTL1=0b0_010_0
	rts

/* SET_TIMER:
 *   タイマ割り込み時に起動するサブルーチンを設定
 *   t * 0.1 msec 秒毎に割り込みが発生するように設定
 * 
 * %D1.W: タイマ割り込み発生周期 t
 * %D2.L: 割り込み時に起動するルーチンの先頭アドレス p
 * （楠田・鴻上）
 */
SET_TIMER:
	move.l %D2, task_p  /* 割り込み時に呼び出すサブルーチンのアドレスをtask_pにセット（楠田・鴻上） */
	move.w #206, TPRER1 /*カウンタ周波数を10000にする-> 周期0.1msec*/
	move.w %D1, TCMP1   /* TCMP1 = t （楠田・鴻上） */
	move.w #0x0015, TCTL1 /*比較割り込み許可, 1/16周期, タイマ許可*/
                          /* TCTL1 = 0b1_010_1 （楠田・鴻上）*/
	rts

/* CALL_RP:
 *   タイマ割り込み時に処理すべきルーチンを呼び出す
 * （楠田・鴻上）
 */
CALL_RP:
	movea.l task_p, %A0 /*task_pを使ってジャンプできないためA0レジスタにアドレスを入れてサブルーチンにジャンプさせる*/
	jsr  (%A0)  /* 割り込み時に起動するルーチンに遷移（楠田・鴻上） */
	rts
