	.intel_syntax noprefix
	.code16
	.global	start
#
#INT 0x15 0x88 0xE801 0xE802
#现代PC很多用这中断探测内存容量，但是在VT中这影响内存管理，因此拦截掉
#本例中只允许0x88执行，其他2个直接废掉，
#0x88返回最大内存64M，因此EPT映射了64M 这样简单处理 一切正常，
#目前只试用了NETBSD 1.0和2.0 能正常启动！

	.text
start:
	jmp	s0.0
orgi:	.long	0x0
s0.0:
	push	ds
	push	cs
	pop	ds		#CS = DS
	mov	[r_edx],edx
	mov	[r_cx],cx
	mov	[r_ax],ax
	pushf
	pop	ax		#save eflags reg
	
	mov	[r_flag],ax
	pop	ax
	mov	[r_ds],ax

	mov	ax,[r_ax]
	cmp	ah,0x88
	je	s.9
	cmp	ax,0xe801
	je	s.0
#	cmp	ax,0xe802
	cmp	ah,0xe8
	jne	s.9
	
s.0:
	push	es
	push	di
	mov	cx,0xb800
	mov	es,cx
	mov	di,160*9
	call	hex16
	pop	di
	pop	es

	mov	ax,[r_ds]
	mov	ds,ax
	pop	dx
	pop	cx
	popf
	stc
	pushf
	push	cx
	push	dx
	mov	edx,[r_edx]
	xor	bx,bx
	mov	ah,0x86
	mov	cx,[r_cx]
	iret
	jmp	$
s.9:
	mov	ax,[orgi+2]
	push	ax
	mov	ax,[orgi]
	push	ax

	mov	ax,[r_ds]
	mov	ds,ax

	mov	ax,cs:[r_flag]
	push	ax
	popf
	mov	ax,cs:[r_ax]
.if 1
	push	cx
	push	es
	push	di
	push	ax
	pushf
	mov	cx,0xb800
	mov	es,cx
	mov	ax,cs:[r_ax]
	mov	di,160*10 + 64
	call	hex16
	popf
	pop	ax
	pop	di
	pop	es
	pop	cx
.endif
	retf

	jmp	$
start.0:

hex16:
	push	ax
	shr	ax,8
	call	hex8
	pop	ax
hex8:
	push	ax
	shr	al,4
	call	hex8.1
	pop	ax
hex8.1:
	and	al,0xf
	add	al,0x30
	cmp	al,0x39
	jbe	hex8.2
	add	al,0x7
hex8.2:
	mov	ah,2
	stosw		
	ret
r_ax:	.word	0x0
r_cx:	.word	0x0
r_edx:	.long	0x0
r_ds:	.word	0x0
r_es:	.word	0x0
r_flag:	.word	0x0
.org	1024
