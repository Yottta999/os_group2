
.section .text
/*D0の値で呼び出すサブルーチンを決めている。ここでは何を呼び出しているかを分かりやすくするためにシンボルに数値を定義している(室原)*/
.equ SYSCALL_NUM_GETSTRING,   1 |文字列入力（GETSTRING）（ここからコメント鴻上）|
.equ SYSCALL_NUM_PUTSTRING,   2 |文字列出力(PUTSTRING)|
.equ SYSCALL_NUM_RESET_TIMER, 3 |タイマリセット|
.equ SYSCALL_NUM_SET_TIMER,   4 |タイマセット|
/*
 * syscall_handler
 * %d0: syscall number
 * %dx: syscall argument
	*/
******************************************
**syscall_handlerはTRAP #0により呼びだされるシステムコール共通ハンドラ（鴻上）
**D0レジスタの値によってどのサブルーチンをよぶかを分岐する
**入力D0.l :システムコール番号（上記定義のいづれか）
**D1~D7/A0~A6:各システムコールに応じた引数
**出力
**必要に応じてD0に戻り値を格納（鴻上）
*****************************************	
	
syscall_handler:
	movem.l %D1-%D7/%A0-%A6, -(%SP)
	cmpi.l #SYSCALL_NUM_GETSTRING, %D0   |D0==1?（鴻上）|
	beq CALL_GETSTRING                   |→GETSTRING処理へ|

	cmpi.l #SYSCALL_NUM_PUTSTRING, %D0   |D0==2?|
	beq CALL_PUTSTRING                   |→PUTSTRING処理へ|
	cmpi.l #SYSCALL_NUM_RESET_TIMER, %D0 |D0==3?|
	beq CALL_RESET_TIMER                 |RESET_TIMER処理へ|
	cmpi.l #SYSCALL_NUM_SET_TIMER, %D0   |D0==4?|
	beq CALL_SET_TIMER                   |CALL_SET_TIMER処理へ|
**********************
** いずれのシステムコール番号にも該当しない
**********************	
END_SYSCALL_HNDR:
    movem.l (%SP)+, %D1-%D7/%A0-%A6
	rte
**********
**各システムコール処理の分岐先
*********	
/*各サブルーチンを呼び出すための場所、サブルーチン呼出し後はシステムコールハンドラーの終了処理に移る(室原)*/	
CALL_GETSTRING:
	jsr GETSTRING
	bra END_SYSCALL_HNDR

CALL_PUTSTRING:
	jsr PUTSTRING
	bra END_SYSCALL_HNDR
	
CALL_RESET_TIMER:
	jsr RESET_TIMER
	bra END_SYSCALL_HNDR
CALL_SET_TIMER:
	jsr SET_TIMER
	bra END_SYSCALL_HNDR
