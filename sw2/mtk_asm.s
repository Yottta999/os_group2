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
    movem.l (%SP)+, %D0-%D7/%A0-%A7

    * 4. ユーザタスクの起動（SR,PCの復帰）
    rte


.global swtch
swtch:
    * 1. SR をスタックに積んで，RTE で復帰できるようにする．
    move.w %SR, -(%SP) 

    * 2. 実行中のタスクのレジスタの退避
    movem.l %D0-%D7/%A0-%A7, -(%SP)

    * 3. SSPの保存
    move.l curr_task, %D1      | %D1.l = curr_task
    muls #SIZEOF_TCB_TYPE, %D1 | %D1.l = curr_task * SIZEOF_TCB_TYPE
    lea.l task_tab, %A1        | %A1.l = task_tab
    add.l %D1, %A1             | %A1.l = &task_tab[curr_task]
    move.l %SP, (%A1)          | *%A1 = %SP

    * 4. curr_task を変更
    move.l (next_task), (curr_task)

    * 5. 次のタスクの SSP の読み出し
    move.l curr_task, %D1      | %D1.l = curr_task
    muls #SIZEOF_TCB_TYPE, %D1 | %D1.l = curr_task * SIZEOF_TCB_TYPE
    lea.l task_tab, %A1        | %A1.l = task_tab
    add.l %D1, %A1             | %A1.l = &task_tab[curr_task]
    move.l %SP, (%A1)          | *%A1 = %SP
    * %SP(SSP) = &task_tab[curr_task]->stack_ptr
    move.l TCB_TYPE_STACK_PTR_OFFSET(%A1), %SP

    * 6. 次のタスクのレジスタの読み出し
    movem.l (%SP)+, %D0-%D7/%A0-%A7

    * 7. タスク切り替え 
    rte


.section .bss
.extern task_tab
.extern curr_task
.extern next_task
