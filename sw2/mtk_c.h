#define NULLTASKID    0 // キューの終端
#define NUMTASK       5 // 最大タスク数
#define STKSIZE    1024 // スタックサイズ
#define NUMSEMAPHORE  2 // セマフォの数

#define TASK_UNDEF    0
#define TASK_CURRENT  1
#define TASK_FINISHED 2
#define TASK_READY    3
#define TASK_SLEEP    4 

typedef int TASK_ID_TYPE;

#define TRAP1_ID 33
extern void pv_handler(void);

typedef struct {
    int count;
    int nst;
    TASK_ID_TYPE task_list;
} SEMAPHORE_TYPE;

typedef struct {
    void (*task_addr)();
    void *stack_ptr;
    int priority;
    int status;
    TASK_ID_TYPE next;
} TCB_TYPE;
extern TCB_TYPE task_tab[NUMTASK + 1];

typedef struct {
    char ustack[STKSIZE];
    char sstack[STKSIZE];
} STACK_TYPE;
extern STACK_TYPE stacks[NUMTASK];

extern TASK_ID_TYPE curr_task;
extern TASK_ID_TYPE new_task;
extern TASK_ID_TYPE next_task;
extern TASK_ID_TYPE ready;
extern SEMAPHORE_TYPE semaphore[NUMSEMAPHORE];

/* multi task */
void init_kernel();
void set_task();
void init_stack();
void begin_sch();
void addq();
void removeq();
void sched();

/* semaphore */
void sleep();
void wakeup();
void p_body();
void v_body();
