.text

.extern task_tab
.extern curr_task

.even
.global first_task
first_task:
    * 1. TCB 先頭番地の計算：curr_task の TCB のアドレスを見つける
    * 2. USP，SSP の値の回復
    * 3. 残りの全レジスタの回復
    * 4. ユーザタスクの起動
    rte
