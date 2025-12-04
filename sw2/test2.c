#include <stdio.h>
#include "mtk_c.h"

void task1() {
    while (1) printf("task1 ");
}

void task2() {
    while (1) printf("task2 ");
}

int main() {
    printf("BOOTING\n");
    init_kernel();
    printf("[OK] init_kernel\n");

    set_task(task1);
    set_task(task2);

    printf("[START] begin_sch\n");
    printf("sizeof TCB_TYPE = %d\n", sizeof(TCB_TYPE));
    begin_sch();
}
