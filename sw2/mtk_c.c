#include <stdio.h>
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
        tcb->stack_ptr = (void *)(stacks[i].ustack + STKSIZE);
        tcb->priority = 0;
        tcb->status = TASK_UNDEF;
        tcb->next = NULLTASKID;
    }
    // readyキューを初期化する
    ready = NULLTASKID;
    // pv_handlerをTRAP #1の割り込みベクタに登録
    *(int *)(TRAP1_ID * 4) = (int)pv_handler;
    // セマフォの値を初期化する
    for (int i = 0; i < NUMSEMAPHORE; i++) {
        SEMAPHORE_TYPE *sema = &semaphore[i];
        sema->count = 1; // 1: 利用可能, <1: 待ちタスクがある
        sema->nst = 0;   // たぶんまだ使わない
        sema->task_list = NULLTASKID;
    }
}

void p_body(int ID) {
  // セマフォIDがスタックに積まれている
  // 1.セマフォの値を減らす
  SEMAPHORE_TYPE *sema = &semaphore[ID];
  sema->count -= 1;
  // 2.マフォが獲得できなけれれば sleep(セマフォの ID)
  if (sema->count < 0) {
    sleep(ID);
  } 
}

void v_body(int ID) {
  // セマフォIDがスタックに積まれている
  // 1.セマフォの値を増やす
  SEMAPHORE_TYPE *sema = &semaphore[ID];
  sema->count += 1;
  // 2.セマフォが空けば，wakeup(セマフォの ID) 
  if (sema->count <= 0) {
    wakeup(ID);
  } 
}

void sleep(int ch) {
  SEMAPHORE_TYPE *sema = &semaphore[ch];
  addq(&(sema->task_list), curr_task);
  task_tab[curr_task].status = TASK_SLEEP;
  sched();
  switch();    
}

void wakeup(int ch){
  SEMAPHORE_TYPE *sema = &semaphore[ch];
  TASK_ID_TYPE woken_task_id = removeq(&(sema->task_list));

  if (woken_task_id != NULLTASKID) {
    addq(&ready, woken_task_id);
    task_tab[woken_task_id].status = TASK_READY;
  }
}
