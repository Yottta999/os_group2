#include <stdio.h>
#include "mtk_c.h"

void task1() {
    while (1) printf("task1 ");
}

void task2() {
    while (1) printf("task2 ");
}

void dump_queue() {
    printf("[DEBUG] dump ready queue\n");
    for (TASK_ID_TYPE id = ready; id != NULLTASKID; id = task_tab[id].next) {
        TCB_TYPE *cur = &task_tab[id];
        printf("[DEBUG] task id = %d, task_addr = %d\n", id, (int) cur->task_addr);
    }
}

int main() {
    printf("BOOTING\n");
    init_kernel();
    printf("[OK] init_kernel\n");

    set_task(task1);
    set_task(task2);

    printf("[DEBUG] sizeof TCB_TYPE = %ld\n", sizeof(TCB_TYPE));
    printf("[DEBUG] ready = %d\n", ready);
    dump_queue();

    begin_sch();
}
