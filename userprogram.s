/****************************************************************
 * PROGRAM AREA
 ****************************************************************/
.section .text
.even
MAIN:
	| 走行モードとレベルの設定 (「ユーザモード」への移行処理)
	move.w #0x0000, %SR | USER MODE, LEVEL 0
	lea.l USR_STK_TOP,%SP | user stack の設定
	| システムコールによる RESET_TIMER の起動
	move.l #SYSCALL_NUM_RESET_TIMER,%D0
	trap #0
	| システムコールによる SET_TIMER の起動
	move.l #SYSCALL_NUM_SET_TIMER, %D0
	move.w #10000, %D1    | 10000ms (10秒ごと) にタイマ割込み
	move.l #TT, %D2
	trap #0

	move.l #0x30303030, %d7

LOOP:
	bra LOOP

/****************************************************************
 * mm:ss アスキーアート描画（タイマ割込み）＋
 * キー入力で描画文字を切替えるユーザタスク
 ****************************************************************/

.section .text
.even

| -------------------------
| タイマ割込みハンドラ TT
| -------------------------
TT:
    movem.l %d0-%d7/%a0-%a3,-(%sp)   | D0-D7, A0-A3 の保存

	| ---------------------
	| 時間カウンタ更新ロジック (100回で1秒と仮定)
	| ---------------------
    addq.w  #1, TTC
    cmpi.w  #100, TTC             | 100回で1秒 (10000ms周期の割り込みであれば、10回で1秒が妥当)
    bne     TT_NO_SEC_UPDATE
    
    | 1秒経過
    clr.w   TTC
    addq.b  #1, SECC
    cmpi.b  #60, SECC
    bne     TT_NO_MIN_UPDATE

    | 1分経過 (SECC = 60)
    clr.b   SECC
    addq.b  #1, MINC
    cmpi.b  #60, MINC
    bne     TT_NO_MIN_UPDATE
    
    | 60分経過 (MINC = 60) -> タイマ停止
    bra     TTKILL

TT_NO_SEC_UPDATE:
TT_NO_MIN_UPDATE:

    | MINC/SECC から D4/D5 に分/秒をロード
    move.b MINC, %d4      | d4 = minutes (0-59)
    move.b SECC, %d5      | d5 = seconds (0-59)

    lea.l DIGITS_BITS, %a0     | a0 -> ビットパターン先頭 (GET_DIGIT_ROW_COPY用)
    lea.l LINEBUF, %a1        | a1 -> 出力バッファ

    moveq  #0, %d2            | d2 = row index 0..4

PRINT_ROWS:
    cmpi.w  #5, %d2
    beq     AFTER_PRINT_ROWS

    | バッファ先頭を指す
    lea.l LINEBUF, %a1

	| ---------------------
	| 描画処理の共通化
	| ---------------------
	| 分 (D4) の十の位と一の位の描画
    move.w %d4, %d6 | D6に描画対象(分)をセット
    jsr    DRAW_DIGIT_PAIR       
    move.b #':', (%a1)+         | 区切り文字コロン
    move.b #' ', (%a1)+

	| 秒 (D5) の十の位と一の位の描画
    move.w %d5, %d6 | D6に描画対象(秒)をセット
    jsr    DRAW_DIGIT_PAIR

    | 行終端 CR を付ける
    move.b  #'\r', (%a1)+

    | PUTSTRING 呼び出し（1行ずつ出す）
    move.l  #SYSCALL_NUM_PUTSTRING, %d0
    clr.l   %d1
    lea.l   LINEBUF, %d2
    move.l  %d2, %d2
    moveq   #40, %d3
    trap    #0

    addq.w  #1, %d2    | 次の行 index++ (D2 は row index)
    bra     PRINT_ROWS

AFTER_PRINT_ROWS:
TTEND:
    movem.l (%sp)+, %d0-%d7/%a0-%a3   | レジスタの復元
    rts

TTKILL:
    move.l #SYSCALL_NUM_RESET_TIMER, %d0
    trap #0
    bra     TTEND

| ----------------------------------------------------------------
| サブルーチン：DRAW_DIGIT_PAIR (共通化)
|   入力:
|     D6.w = 0-59 の値 (分または秒)
|     D2.w = row index (0..4)
|     A0 = DIGITS_BITS (base)
|     A1 = destination pointer (進められる)
|   動作:
|     D6を十の位と一の位に分解し、それぞれ描画する。桁間にスペースを挿入。
| ----------------------------------------------------------------
DRAW_DIGIT_PAIR:
	movem.l %d0/%d7,-(%sp) | temp regs D0, D7 を保存

	| --- 十の位の計算 (D6は破壊される)
	move.w %d6, %d7
	divu   #10, %d7           | D7.w = 十の位 (商)
    move.w %d7, %d6           | D6 = 十の位
	jsr    GET_DIGIT_ROW_COPY
	move.b #' ', (%a1)+ | 桁間のスペース

	| --- 一の位の計算 (D6は破壊される)
	move.w %d7, %d6
	swap   %d6                | D6.w = 一の位 (余り)
	jsr    GET_DIGIT_ROW_COPY
    
	movem.l (%sp)+, %d0/%d7 | 復元
	rts
    
| ----------------------------------------------------------------
| サブルーチン：GET_DIGIT_ROW_COPY (変更なし)
| ----------------------------------------------------------------
GET_DIGIT_ROW_COPY:
    movem.l %d0-%d1/%a2,-(%sp)   | temp regs の保存

    | offset_bytes = (digit * 5 + row) * 1
    move.w  %d6, %d0              | d0 = digit
    move.l  %d0, %d1
    lsl.l   #2, %d1               | d1 = digit * 4
    add.l   %d0, %d1              | d1 = digit * 5
    move.w  %d2, %d0              | d0 = row
    add.l   %d0, %d1              | d1 = digit*5 + row (byte index)
    move.l  %a0, %a2              | a2 = base address
    add.l   %d1, %a2              | a2 -> address of pattern byte
    | read pattern byte
    move.b  (%a2), %d0            | d0.b = pattern (low 4 bits used)

    | prepare: shift pattern so that leftmost column goes to bit7
    lsl.b   #4, %d0               | 4-bit patternをハイニブルへ

    moveq   #4, %d7               | 4 columns to output

COPY_LOOP:
    btst    #7, %d0
    beq     COPY_SPACE
    move.b  CHAR_DRAW, (%a1)+ | 描画文字を出力
    bra     NEXT_BIT
COPY_SPACE:
    move.b  #' ', (%a1)+ | スペースを出力
NEXT_BIT:
    lsl.b   #1, %d0 | 次のビットをビット7にシフト
    dbra    %d7, COPY_LOOP

    movem.l (%sp)+, %d0-%d1/%a2   | 復元
    rts

| -------------------------
| ユーザメインタスク: start (変更なし)
| -------------------------
.section .text
.even
.global start
start:
    movem.l %d0-%d2/%a0-%a2,-(%sp) | レジスタ保存

POLL_LOOP:
    move.l  #0, %d0        | QueueOutG は d0==0 のとき内部で受信処理を行う
    jsr     QueueOutG
    cmp.l   #0, %d0
    beq     NO_INPUT       | d0==0 -> 取得失敗（キュー空）
    | 成功時：d0==1, 受信バイトは d1 に入っている
    move.b  %d1, %d0
    | 受信文字が改行・CRなら無視
    cmpi.b  #'\r', %d0
    beq     NO_INPUT
    cmpi.b  #'\n', %d0
    beq     NO_INPUT

    | 受信文字を描画文字として登録
    move.b  %d0, CHAR_DRAW

NO_INPUT:
    bra     POLL_LOOP

    movem.l (%sp)+, %d0-%d2/%a0-%a2 | レジスタ復元
    rts

| -------------------------
| データ領域
| -------------------------
.section .data
| 描画文字（1バイト） 初期は '#'
CHAR_DRAW:
    .dc.b '#' 
    .even

| DIGITS_BITS: 各数字 0..9 を 5行×4列でビット表現（1=描画,0=空白）
| 各行は 1 バイトに格納（下位4ビットを使用: bit3..bit0 = 左..右）
DIGITS_BITS:
    | 0
    .dc.b 0x0F, 0x09, 0x09, 0x09, 0x0F
    | 1
    .dc.b 0x01, 0x01, 0x01, 0x01, 0x01
    | 2
    .dc.b 0x0F, 0x01, 0x0F, 0x08, 0x0F
    | 3
    .dc.b 0x0F, 0x01, 0x0F, 0x01, 0x0F
    | 4
    .dc.b 0x09, 0x09, 0x0F, 0x01, 0x01
    | 5
    .dc.b 0x0F, 0x08, 0x0F, 0x01, 0x0F
    | 6
    .dc.b 0x0F, 0x08, 0x0F, 0x09, 0x0F
    | 7
    .dc.b 0x0F, 0x01, 0x01, 0x01, 0x01
    | 8
    .dc.b 0x0F, 0x09, 0x0F, 0x09, 0x0F
    | 9
    .dc.b 0x0F, 0x09, 0x0F, 0x01, 0x0F
.even

| ラインバッファ
LINEBUF:
    .space 64
.even

| カウンタ変数
DISP:   .ascii "00:00\r" | 古い互換フィールド
.even
SECC:   .dc.b 0 | 秒カウンタ
.even
MINC:   .dc.b 0 | 分カウンタ
.even
TTC:    .dc.w 0 | タイマカウント
.even

.section .bss
USR_STK:
    .ds.b 0x4000
.even
USR_STK_TOP:
