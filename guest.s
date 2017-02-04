	.text
	.global start16, begin
	.intel_syntax noprefix
	.include "mem.inc"
begin:
	.long	0x12345678		#SIG 0
	.word	offset start16		#4
	.word	0x0			#6
	.long	512			#8
	.code16
start16:
	sti

	mov	ah,2
	mov	al,1
	mov	cl,1		#
	mov	ch,0
	mov	bx,0x7c00
	xor	dx,dx
	mov	es,dx
	mov	dl,0x1
#	mov	dl,0x80
	int	0x13

.if 0	
	xor	ax,ax
	mov	es,ax
	mov	ds,ax
	lea	si,disk_pack
	mov	ah,0x42
	mov	dx,0x80
	int	0x13
.endif

	ljmp	0:0x7c00
	.intel_syntax noprefix
	.global	hex16
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
	mov	ah,6
	stosw		
	ret
	.global	putc.1
putc.1:
	mov	bx,7
	mov	ah,0xe
	int	0x10
putc:
	lodsb
	test	al,al
	jnz	putc.1
	ret
#
#BIOS int 0x13 ah=0x42 disk address packet structure
#
	.p2align 4
disk_pack:
	.byte	0x10		#struct size (always 16 bytes ??)
	.byte	0		#reserved  0
	.word	1		#sector count read ,on some BIOS you can specify only
				#up to 127 sector (0x7f).BIOS int 0x13 places here number of 
				#sectors actually read
	.word	0x7c00		#offset
	.word	0x0000		#segment
	.long	0x0		#sector number to read 
	.long	0x0		#use only in LBA48

	.org 512
