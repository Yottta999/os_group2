.section .text

.equ SIZEOF_TCB_TYPE, 20
.equ TCB_TYPE_STACK_PTR_OFFSET, 4

.global first_task
.even
first_task:
    * 1. TCB 先頭番地の計算：curr_task の TCB のアドレスを見つける
    move.l curr_task, %D1      | %D1.l = curr_task
    muls #SIZEOF_TCB_TYPE, %D1 | %D1.l = curr_task * SIZEOF_TCB_TYPE
    lea.l task_tab, %A1        | %A1.l = task_tab
    add.l %D1, %A1             | %A1.l = &task_tab[curr_task]

    * 2. SSPの値の回復
    * %SP(SSP) = &task_tab[curr_task]->stack_ptr
    move.l TCB_TYPE_STACK_PTR_OFFSET(%A1), %SP

    * 3. USPを含めた、残りの全レジスタの回復
    * !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! TODO: これでUSPが復帰するのか後でチェックする
    movem.l (%SP)+, %D0-%D7/%A0-%A7

    * 4. ユーザタスクの起動（SR,PCの復帰）
    rte


.section .bss
.extern task_tab
.extern curr_task
