.include "defs.s"
.global outbyte

.text
.even
outbyte:
    # link.w %FP, #0
    movem.l %D1-%D3, -(%SP)
outbyte_retry:
    move.l #SYSCALL_NUM_PUTSTRING, %D0
    move.l #0, %D1
    # move.l %FP, %D2
    # addi.l #11, %D2
    move.l %SP, %D2
    addi.l #19, %D2
    move.l #1, %D3
    trap #0
    cmpi.l #0, %D0
    beq outbyte_retry
    movem.l (%SP)+, %D1-%D3
    # unlk %FP
    rts
