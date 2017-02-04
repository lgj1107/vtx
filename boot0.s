	.global start
	.code16
	.intel_syntax noprefix
start:
start.1:
	cli
	xor	cx,cx
	mov	ds,cx
	mov	es,cx
	mov	ss,cx
	mov	sp,0x7c00
	mov	si,sp
	mov	di,0x600
	inc	ch
	cld
	rep	movsw
	ljmp	0:main -start+0x600
main:
	sti
	test	dl,0x80
	jz	read_floppy
	push	ds
	mov	dl,0x80
	lea	si,disk_pack
	mov	ah,0x42
	int	0x13
	jmp	main.9

read_floppy:
	push	ds
	push	es

	mov	ax,0x1000
	mov	es,ax
	mov	si,8
	call	intx13
main.9:
	mov	ax,0x1000
	mov	ds,ax
	pop	es	
	mov	di,0x800
	xor	si,si
	mov	cx,(512*17+512*18*3)/2
	cld
	rep	movsw
	pop	ds
main.10:
	mov	bx,0x800
	jmp	bx
	.att_syntax prefix
	jmp	*(%bx)
	.intel_syntax noprefix
	jmp	.
	

/*
 * BIOS call "INT 0x13 Function 0x2" to read sectors from disk into memory
 *	Call with	%ah = 0x2
 *			%al = number of sectors
 *			%ch = cylinder
 *			%cl = sector (bits 6-7 are high bits of "cylinder")
 *			%dh = head
 *			%dl = drive (0x80 for hard disk, 0x0 for floppy disk)
 *			%es:%bx = segment:offset of buffer
 *	Return:
 *			%al = 0x0 on success; err code on failure
 */
intx13:
	xor	bx,bx
#	mov	dh,bl
	mov	al,17
	mov	cx,2
int.1:
	mov	dh,[head]
	mov	ch,[cyl]
	xor	byte ptr [head],1
	jnz	int.2
	inc	byte ptr [cyl]
int.2:
	mov	ah,2
	int	0x13

	mov	al,18
	mov	cl,1
	mov	bx,[load_addr]
	mov	di,0x512*18
	add	[load_addr],di
	dec	si
	jnz	int.1
	ret	
head:
	.byte	0x0
cyl:
	.byte	0x0
load_addr:
	.word	512*17
count:
	.byte	0x4
wheel:
	.byte	'|
	.byte	'\\
	.byte	'-
	.byte	'/

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

#
#BIOS int 0x13 ah=0x42 disk address packet structure
#
	.p2align 4
disk_pack:
	.byte	0x10		#struct size (always 16 bytes ??)
	.byte	0		#reserved  0
	.word	18*4		#sector count read ,on some BIOS you can specify only
				#up to 127 sector (0x7f).BIOS int 0x13 places here number of 
				#sectors actually read
	.word	0x0		#offset
	.word	0x1000		#segment
	.long	0x1		#sector number to read 
	.long	0x0		#use only in LBA48
.org	0x1be
	.byte	0x80		#活动分区标志，80激活分区
	.byte	0x20		#分区起始磁头号
	.byte	0x21		#
	.byte	0x00
	.byte	0x0C		#系统标志,1=fat12,4=fat16,0xc=win95 fat32
	.byte	0xfe,0xff,0xff
	.byte	0x00,0x08,0x00,0x00	#本分区前面的扇区数，
	.byte	0x0,0x10,0xdd,0x1	#本分区总扇区数

	.fill	0x40-16,1,0	
	.org	510
	.word	0xaa55

