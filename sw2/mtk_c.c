#include <stdio.h>
#include <stdint.h>
#include "mtk_c.h"

TASK_ID_TYPE curr_task;
TASK_ID_TYPE new_task;
TASK_ID_TYPE next_task;
TASK_ID_TYPE ready;
TCB_TYPE task_tab[NUMTASK + 1];
STACK_TYPE stacks[NUMTASK];
SEMAPHORE_TYPE semaphore[NUMSEMAPHORE];

void init_kernel() {
    // TCB配列を初期化する
    for (int i = 0; i < NUMTASK; i++) {
        TCB_TYPE *tcb = &task_tab[i + 1];
        tcb->task_addr = NULL;
        tcb->stack_ptr = NULL;
        tcb->priority = 0;
        tcb->status = TASK_UNDEF;
        tcb->next = NULLTASKID;
    }
    // readyキューを初期化する
    ready = NULLTASKID;
    // pv_handlerをTRAP #1の割り込みベクタに登録
    *(int *)(TRAP1_ID * 4) = (int)(uintptr_t)pv_handler;
    // セマフォの値を初期化する
    for (int i = 0; i < NUMSEMAPHORE; i++) {
        SEMAPHORE_TYPE *sema = &semaphore[i];
        sema->count = 1; // 1: 利用可能, <1: 待ちタスクがある
        sema->nst = 0;   // たぶんまだ使わない
        sema->task_list = NULLTASKID;
    }
}

void set_task(void (*task_addr)()) {
    // タスクIDの決定
    TASK_ID_TYPE task_id = NULLTASKID;
    for (int i = 0; i < NUMTASK; i++) {
        TCB_TYPE *tcb = &task_tab[i + 1];
        if (tcb->status == TASK_UNDEF || tcb->status == TASK_FINISHED) {
            task_id = i + 1;
            break;
        }
    }
    if (task_id == NULLTASKID) return; // 空きがない
    new_task = task_id; // 空いていたTCBのIDをnew_tabに代入

    TCB_TYPE *tcb = &task_tab[new_task];
    tcb->task_addr = task_addr;    // task_addrを登録
    tcb->status = TASK_INUSE;      // statusを登録
    tcb->stack_ptr = init_stack(new_task); // stack_ptrを登録
    ready = new_task;
}

void *init_stack(TASK_ID_TYPE id) {
    char *ustack_top = stacks[id - 1].ustack + STKSIZE;
    char *sstack = stacks[id - 1].sstack;
    int *ssp = (int *)(sstack + STKSIZE);
    *(--ssp) = (int)task_tab[id].task_addr;
    short *ssp_s = (short*)ssp;
    *(--ssp_s) = (short)0x0000;
    ssp = (int*)ssp_s;
    ssp -= 15;
    *(--ssp) = (int)ustack_top;
    return NULL;
}

void begin_sch() {
    curr_task = removeq(&task_tab[ready]); // 最初のタスクの決定
    init_timer(); // タイマの設定
    first_task(); // 最初のタスクへ遷移
}

void addq(TCB_TYPE* q_ptr, int task_id) {
    int next;
    for (int i = 1; i < NUMTASK + 1; i++) {
        next = (*q_ptr).next;
	if (next == NULLTASKID) {      // キュー末尾なら
	    (*q_ptr).next = task_id;   // 末尾にtask_idのTCBを登録
	    if (task_tab[task_id].next != NULLTASKID) { 
	        task_tab[task_id].next = NULLTASKID;  // task_tab[task_id]がキューの末尾であることを示す
	    }
            return;
	}
	q_ptr = &task_tab[next];   // ポインタを次のタスクに進める
    }
}
