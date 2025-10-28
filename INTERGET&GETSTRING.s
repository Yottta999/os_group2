.section .text

***************************
** %d1.l = ch
** %d2.b = 受信データ  data
** 戻り値  なし
***************************
INTERGET:
	cmpi.l #0, %d1                        
	bne INTERGET_END 
	move.b %d2, %d1
	moveq.l #0, %d0                
	jsr INQ                            

INTERGET_END:
	rts
	
**********************************************
** %d1.l = ch
** %d2.l = 書き込み先の先頭アドレス p
** %d3.l = 取り出すデータ数  size
** 戻り値  %d0.l = 実際に取り出したデータ数  sz 
**********************************************
GETSTRING:
	movem.l %d4/%a0, -(%sp)
	cmp.l #0, %d1            /*  */                  
	bne GETSTRING_END        /*  */
	moveq.l #0, %d4          /*  */                    
	movea.l %d2, %a0                          

GETSTRING_STEP1:
	cmp.l %d0, %d3           /*  */               
	beq GETSTRING_STEP2
	moveq.l #0, %d0        /**/
	jsr OUTQ                   /**/      
	cmpi.l #0, %d0                /**/           
	beq GETSTRING_STEP2        /**/
	move.b %d1, (%a0)+             /**/                               
	addq.l #1, %d4                     /**/      
	bra GETSTRING_STEP1         /**/

GETSTRING_STEP2:
	move.l %d4, %d0                 /**/  

GETSTRING_END:
	movem.l (%sp)+, %d4/%a0
	rts
