	.text
	.global start16, begin
	.intel_syntax noprefix
	.include "mem.inc"
begin:
	.long	0x12345678		#SIG 0
	.word	offset start16		#4
	.word	0x0			#6
	.long	tss_end - begin		#8
	.code16
start16:
	pushf
	pop	ax
#	jmp	bsd.1
	sti
main:
	jmp	bsd
bsd.1:
	cli
	lgdt	gdtr
	mov	eax,cr0
	or	al,1
	mov	cr0,eax
	ljmp	0x8,offset start32
	.code32
start32:
	mov	ax,0x10
	mov	ds,ax
	mov	es,ax
	mov	ss,ax
	mov	fs,ax
	mov	gs,ax
	mov	esp,0x200000
	push	2
	popf
	xor	eax,eax
	cpuid


.set	idt_addr,0x1000
	mov	ecx,4096
	xor	eax,eax
	mov	edi,idt_addr
	rep	stosd
	
	mov	edi,idt_addr
	mov	edx,0x88e
	mov	eax,offset intx00
	mov	esi,eax
	mov	ebx,0x1fffff
	mov	ecx,20
i.0:
	shr	ebx,1
	jnc	i.1
	mov	[edi],ax
	shr	eax,16
	mov	[edi+int_gate_offset_31_16],ax
	mov	[edi+int_gate_seg_sel],dh
	mov	[edi+int_gate_p_dpl_type],dl
	add	esi,4
	mov	eax,esi
i.1:
	lea	edi,[edi+8]
	loop	i.0

	lidt	idtr


	mov	edi,offset gdt16
	
	mov	eax,offset tss_seg
	mov	[edi+0x18+tss_desc_base_15_0],ax	
	shr	eax,16
	mov	[edi+0x18+tss_desc_base_23_16],al	
	mov	[edi+0x18+tss_desc_base_31_24],ah	
	
	mov	ax,0x18
	ltr	ax

.set	page_pde,0x2000
.set	page_pte,0x3000

	mov	edi,page_pde
	mov	eax,page_pte|7		# U/S R/W P
	xor	ebx,ebx
#	mov	ebx,(0xc0000000>>22)<<2
	mov	[edi+ebx],eax
	mov	edi,page_pte
	mov	eax,0x7
	mov	ecx,1024
p.0:
	stosd
	add	eax,0x1000
	loop	p.0

	mov	eax,page_pde
	mov	cr3,eax
	jmp	$+2

	mov	eax,cr0
	or	eax,0x80000000
	mov	cr0,eax
	
	jmp	$+2

	mov	edi,0xb8000+160*6-16
	mov	ebx,16*1024*1024
	mov	ebx,0x3fe00000
	mov	eax,[ebx-8]


	call	hex_32
	
	jmp	$
intx00:	
	push	0x0			# Int 0x0: #DE
	jmp	ex_noc			# Divide error
	push	0x1			# Int 0x1: #DB
	jmp	ex_noc			# Debug
	push	0x2			#RSV
	jmp	except			#
	push	0x3			# Int 0x3: #BP
	jmp	ex_noc			# Breakpoint
	push	0x4			# Int 0x4: #OF
	jmp	ex_noc			# Overflow
	push	0x5			# Int 0x5: #BR
	jmp	ex_noc			# BOUND range exceeded
	push	0x6			# Int 0x6: #UD
	jmp	ex_noc			# Invalid opcode
	push	0x7			# Int 0x7: #NM
	jmp	ex_noc			# Device not available
	push	0x8			# Int 0x8: #DF
	jmp	except			# Double fault
	push	0x9			# RSV
	jmp	except			# 
	push	0xa			# Int 0xa: #TS
	jmp	except			# Invalid TSS
	push	0xb			# Int 0xb: #NP
	jmp	except			# Segment not present
	push	0xc			# Int 0xc: #SS
	jmp	except			# Stack segment fault
	push	0xd			# Int 0xd: #GP
	jmp	except			# General protection
	push	0xe			# Int 0xe: #PF
	jmp	except			# Page fault
	push	0xf			# RSV
	jmp	except			# 
intx10:	push	0x10			# Int 0x10: #MF
	jmp	ex_noc			# Floating-point er
	push	0x11			
	jmp	except			#Alignment Check Exception
	push	18			
	jmp	ex_noc			#Machine Check Exception (#MC)
	push	19			
	jmp	ex_noc			#SIND Floating-point Exception (#XM)
	push	20			
#	jmp	ex_noc			#Viryualization Exception (#VE)

ex_noc:
	push	[esp]
	mov	dword ptr [esp+8],0x0
except:
	mov	edi,0xb8000+160*22
	mov	eax,[esp]
	call	hex_32

	jmp	$
hex_32:
	push	eax
	shr	eax,16
	call	hex_16
	pop	eax
hex_16:
	push	eax
	shr	ax,8
	call	hex_8
	pop	eax
hex_8:
	push	eax
	shr	al,4
	call	hex8_1
	pop	eax
hex8_1:
	and	al,0xf
	add	al,0x30
	cmp	al,0x39
	jbe	hex8_2
	add	al,0x7
hex8_2:
	mov	ah,2
	stosw		
	ret
	jmp	$
bsd:

.code16
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
gdt16:
	.quad	0x0
	.quad	0x00cf9a000000ffff
	.quad	0x00cf92000000ffff
#tss_sel
	.word	0x67			#limit	15-0
	.word	0			#base address 15 - 0 
	.byte	0x0			#base address 23 -16
	.byte	0x89			#p_dpl_type
	.byte	0x0			#G_0_0_AVL_LIMIT
	.byte	0x0			#BASE 31_24
gdtr:
	.word	4*8-1
	.long	offset gdt16
idtr:	.word	256*8-1
	.long	idt_addr
tss_seg:
	.fill	102,1,0
	.word	0xffff
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

tss_end:
#	V86 STACK
#------------------------
#|	old GS		|
#|	old FS		|
#|	old ES		|
#|	old ES		|
#|	old SS		|
#|	old ESP		|
#|	old EFLAGS	|
#|	old CS		|
#|	old EIP		|
#|----------------------|<----new esp
