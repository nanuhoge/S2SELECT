;SCSI2バスプロトコルのような挙動をさせるテスト
;
	.include IOCSCALL.MAC
	.include DOSCALL.MAC

MAGIC_NO1	equ	'SCSI'
MAGIC_NO2	equ	'*LUN'

MPUTYPE		equ	$0CBC
PAGE_SIZE	equ	(8*1024)
SCSI030		equ	$00ffccb8

	.cpu	68000

;------------------------------------------------------------
; デバイスドライバ
;------------------------------------------------------------
	.text
device_top:
		dc.l	-1
		dc.w	$8000
		dc.l	strategy
		dc.l	interrupt
		dc.l	MAGIC_NO1
		dc.l	MAGIC_NO2

request:	dc.l	0

strategy:	move.l	a5,request
		rts

interrupt:	movem.l	d0-d7/a0-a6,-(sp)
		movea.l	(request,pc),a5
		tst.b	(2,a5)
		beq.s	device_exec
illegal_system:
		move.w	#$1003,d0
device_exit:
		move.b	d0,(3,a5)
		lsr.w	#8,d0
		move.b	d0,(4,a5)
		movem.l	(sp)+,d0-d7/a0-a6
		rts

device_bottom:
;------------------------------------------------------------
;デバイスドライバの初期化処理
;------------------------------------------------------------
device_exec:
		pea	(devicenameMsg,pc)
		DOS	_PRINT
		addq.l	#4,sp
		
		move.l	(18,a5),a1
@@:		tst.b	(a1)+
		bne	@b
		
1:		move.b	(a1)+,d0
		bne	2f
		move.b	(a1)+,d0
		beq	3f
2:		bsr	check_param
		bra	1b
3:		
		bsr	patch_exec
		tst.l	d0
		bne	illegal_system
		move.l	#device_bottom,(14,a5)
		bra	device_exit

;------------------------------------------------------------
;コマンドラインからの実行
;------------------------------------------------------------
command_exec:
		pea	(cmdnameMsg,pc)
		DOS	_PRINT
		addq.l	#4,sp
		
		tst.b	(a2)+
		beq	3f
1:		move.b	(a2)+,d0
		beq	3f
		bsr	check_param
		bra	1b
3:		
		clr.l	-(sp)
		DOS	_SUPER
		move.l	d0,(sp)
		
		bsr	patch_exec
		
		DOS	_SUPER
		addq.l	#4,sp
		
		DOS	_EXIT

;------------------------------------------------------------
check_param:
		cmpi.b	#'!',d0
		bne	@f
		st	(dbFlag)
		bra	9f
@@:		subi.b	#'0',d0
		bcs	9f
		cmpi.b	#7,d0
		bhi	9f
		bset.b	d0,(targetID+1)
9:		rts

;------------------------------------------------------------
;初期化処理の下請け
;------------------------------------------------------------
patch_exec:
		bsr	patch_system
		subq.l	#1,d0
		beq	targetganai
		addq.l	#1,d0
		bne	patchdekinai
		
		move.b	(dbFlag),d0
		beq	@f
		pea	(dbMsg,pc)
		DOS	_PRINT
		addq.l	#4,sp
@@:		
		pea	(targetMsg,pc)
		DOS	_PRINT
		addq.l	#4,sp
		
		moveq	#0,d1
1:		btst.b	d1,(targetID+1)
		beq	2f
		pea	(IDMsg,pc)
		DOS	_PRINT
		move.w	d1,(sp)
		addi.w	#'0',(sp)
		DOS	_PUTCHAR
		addq.l	#4,sp
2:		addq.b	#1,d1
		cmpi.b	#7,d1
		bls	1b
		
		pea	(crlfMsg,pc)
		DOS	_PRINT
		addq.l	#4,sp
9:		
		moveq	#0,d0
		rts

targetganai:
		pea	(notargetMsg,pc)
		bra	@f
patchdekinai:
		pea	(illegalenvMsg,pc)
@@:		DOS	_PRINT
		addq.l	#4,sp
		moveq	#-1,d0
		rts

illegalenvMsg:	dc.b	'この環境には対応していません',13,10,0
notargetMsg:	dc.b	'ターゲットの指定がありません',13,10,0
devicenameMsg:	dc.b	13,10
cmdnameMsg:	dc.b	'SCSI2 IDENTIFY message patch version 0.50 Copyright 1997,2017 じゃぎゅあ'
crlfMsg:	dc.b	13,10,0
targetMsg:	dc.b	'IDENTIFY message target',0
IDMsg:		dc.b	' ID:',0
dbMsg:		dc.b	'ﾊﾟｯﾁ ｱﾄﾞﾚｽ:'
paddrMsg:	dc.b	'qawsedrf ｺｰﾄﾞ:'
pcodeMsg:	dc.b	'tgyhujik',13,10,0

	.even
;------------------------------------------------------------
	.offset	4+4*4
mad:		ds.l	1
mdt:		ds.l	1
	.text
hexout:
		movem.l	d0-d2/a0,-(sp)
		movea.l	(mad,sp),a0
		move.l	(mdt,sp),d0
		moveq	#8-1,d2
@@:		rol.l	#4,d0
		moveq	#$f,d1
		and.b	d0,d1
		move.b	(@f,pc,d1.w),(a0)+
		dbra	d2,@b
		movem.l	(sp)+,d0-d2/a0
		rts
@@:		dc.b	'0123456789ABCDEF'

;------------------------------------------------------------
setWPmode:	movem.l	d0-d2/d7/a1,-(sp)
		lea	($00ff0000),a1
		moveq	#$10000/PAGE_SIZE-1,d7
1:
		moveq	#-1,d2
		move.w	#$f002,d1
		IOCS	$ac			;ページ状態を取得
		move.w	d0,d2
		
		bset.l	#2,d2			;set WP bit
		tst.l	d3
		bne	@f
		bclr.l	#2,d2			;clr WP bit
@@:		
		move.w	#$f002,d1
		IOCS	$ac			;ページ状態を設定
		
		lea	(PAGE_SIZE,a1),a1
		dbra	d7,1b
		movem.l	(sp)+,d0-d2/d7/a1
		rts

;------------------------------------------------------------
;パッチを行う本体
;------------------------------------------------------------
patch_system:
		move.b	(MPUTYPE),d7
		cmpi.b	#3,d7
		bcs	patch_schdisk
		
		SCSI	$0a			;一応SCSI ROMの確認
		cmp.l	d1,d0
		bne	illegalenv
		
		move.w	#$8000,d1
		IOCS	$ac			;0x0SYSpatchのバージョン取得
		tst.l	d0
		bmi	illegalenv
		
		move.l	($00ff0000),d1		;システムパッチ識別コード
		cmpi.b	#3,d7
		bne	check_040sys
check_030sys:
		cmpi.l	#'X030',d1		;030SYSpatch.x
		bne	illegalenv
		cmpi.l	#'0.40',d0
		bra	@f
check_040sys:
		cmpi.l	#'040T',d1		;040turbo
		bne	illegalenv
		cmpi.l	#'2.60',d0
@@:		bcs	illegalenv
** X68030の場合
patch_x68030:
		lea	(SCSI030),a6
		lea	(rom_030,pc),a2
		
		moveq	#0,d3
		bsr	setWPmode		;ライトプロテクト解除
		
		bsr	insert_code
		
		moveq	#1,d3
		bsr	setWPmode		;ライトプロテクト再設定
		
		rts

** SCHDISKの場合
patch_schdisk:
		cmpi.l	#$00C00000,($f5*4+$400)	;SCSI IOCSのベクタ値を確認
		bcc	illegalenv
		
		;NUL検索
		lea	($6800-2),a6		;頭の位置(仮)
@@:		addq.l	#2,a6
		cmpi.w	#$8024,(4,a6)		;NUL device attribute
		bne	@b
		cmpi.l	#'NUL ',(14,a6)
		bne	@b
		cmpi.l	#'    ',(18,a6)
		bne	@b
		
		;SCHDISK検索
@@:		movea.l	(a6),a6			;リンクポインタをたどる
		cmpi.w	#$4000,(4,a6)
		bne	1f
		cmpi.l	#$01<<24|'SCH',(14,a6)
		bne	1f
		cmpi.l	#'DISK',(18,a6)
		beq	2f
1:		cmp.l	#-1,(a6)		;終端か？
		bne	@b			;次のドライバへ
		bra	illegalenv		;発見に至らず
2:		
		SCSI	$0a			;SCSI IOCSのバージョンのような物を取得
		moveq	#4,d1
		cmp.l	d1,d0			;SCHDISK 1.04かな？
		lea	(ram_schdisk103,pc),a2
		bne	nazonoschdisk
		lea	(ram_schdisk104,pc),a2
nazonoschdisk:
		lea	(a6),a1
		adda.w	(a2)+,a1
		cmpm.l	(a2)+,(a1)+		;SCHDISKバージョン文字列比較
		bne	illegalenv
insert_code:
		lea	(patchcode,pc),a0
		lea	(a6),a1
		adda.w	(a2)+,a1		;a1 = 隙間領域のアドレス
		
		lea	(targetID+1,pc),a3
		move.b	(a3),d0
		cmpi.w	#$ffff,(a1)		;使用済み？
		bne	@f
		tst.b	d0
		bne	9f			;未使用かつターゲット指定がある
		moveq	#1,d0			;未使用かつターゲット未指定
		rts
@@:		
		cmpi.l	#MAGIC_NO1,(a1)
		bne	illegalenv		;あの領域が既に何かに使われている
		cmpi.l	#MAGIC_NO2,(4,a1)
		bne	illegalenv		;あの領域が既に何かに使われている
		tst.b	d0			;ターゲットの指定状況確認
		bne	9f
		move.b	(MAGIC_LEN+1,a1),(a3)	;現状の設定を表示をするための下処理
		sf	(dbFlag)
		moveq	#0,d0			;正常終了の体で戻る
		rts
9:		
		pea	(MAGIC_LEN,a1)
		
		pea	(pcodeMsg,pc)
		bsr	hexout
		addq.l	#4,sp
		
		moveq	#patchsize/2-1,d0
1:		move.w	(a0)+,d1
		cmpi.w	#$fffe,d1		;patchcode内容変更時★バイナリ再確認
		bne	@f
		move.w	(a2)+,d1		;オフセット値の取得
		ext.l	d1
		add.l	a6,d1
		sub.l	a1,d1			;($xxxx,pc)の計算
@@:		move.w	d1,(a1)+
		dbra	d0,1b
		
		move.l	(sp)+,d1		;パッチ処理先アドレス
		lea	(a6),a1
		adda.w	(a2)+,a1
		
		pea	(a1)
		pea	(paddrMsg,pc)
		bsr	hexout
		addq.l	#8,sp
		
		addq.l	#2,a1			;パッチへ飛ぶ bsr.w
		sub.l	a1,d1
		move.w	d1,(a1)			;($xxxx,pc)
		
		cmpi.b	#3,d7
		bcs	@f
		
		lea	($00ffccd2),a1		;念のためブロックする小細工
		move.w	(2,a1),d1		;この対策はSCHDISKで不要
		addq.b	#2,d1
		move.w	d1,(a1)			;bra.s	$00ffcd02
		
		moveq	#3,d1
		IOCS	$ac			;cache flush
@@:		
		moveq	#0,d0
		rts
illegalenv:
		moveq	#-1,d0
		rts

;------------------------------------------------------------
; パッチのオフセットなど
;------------------------------------------------------------
ram_schdisk104:
		dc.w	$0e04		;'1.04'のアドレス
		dc.l	'1.04'
		dc.w	$1e78		;パッチ格納アドレス
		dc.w	$28c0		;S_SELECT
		dc.w	$28a0		;S_SELECT with ATN
		dc.w	$2b68		;S_MSGOUT
		dc.w	$2e52		;パッチする場所

ram_schdisk103:
		dc.w	$0bc4		;'1.03'のアドレス
		dc.l	'1.03'
		dc.w	$1c20		;パッチ格納アドレス
		dc.w	$2744		;S_SELECT
		dc.w	$2724		;S_SELECT with ATN
		dc.w	$29de		;S_MSGOUT
		dc.w	$2cc8		;パッチする場所

rom_030:
		dc.w	$00ffcdce-SCSI030	;パッチ格納アドレス
		dc.w	$00ffcefc-SCSI030	;S_SELECT
		dc.w	$00ffced6-SCSI030	;S_SELECT with ATN
		dc.w	$00ffd126-SCSI030	;S_MSGOUT
		dc.w	$00ffd4e6-SCSI030	;パッチする場所

;------------------------------------------------------------
; 転送するもの
;------------------------------------------------------------
patchcode:
		dc.l	MAGIC_NO1
		dc.l	MAGIC_NO2
MAGIC_LEN	equ	$-patchcode
targetID:	moveq	#0,d0			;***
		btst.l	d4,d0
		beq.w	$			;***S_SELECT
		move.b	#$ff,($09,a6)		;INTS(SCHDISKで必須)
		bsr.w	$			;***S_SELECT with ATN
		tst.l	d0
		bne	9f
		move.l	a1,-(sp)
		swap	d4
		tas	d4			;set IDENTIFY bit
		move.b	d4,-(sp)
		clr.b	d4			;LUNフィールドを消去
		swap	d4
		lea	(sp),a1
		bsr.w	$			;***S_MSGOUT
		addq.l	#2,sp
		movea.l	(sp)+,a1
9:		rts
patchsize	equ	$-patchcode

	.bss

dbFlag:		ds.b	1

	.end	command_exec
