	.set	mp_trampoline,0x9f000

	.include "regs.def"
	.include "misc.def"
	.include "apicreg.def"
	.include "mem.inc"
	.code16
	
	.global	start
	.intel_syntax noprefix
start:
	cli
	
.if 0
	mov	al,-1
	out	0x21,al
	jmp	$+2
	out	0xa1,al
.endif	
	in	al,0x92
	or	al,2
	out	0x92,al
	
	lgdt	gdtr
	mov	eax,cr0
	or	al,1
	mov	cr0,eax
	ljmp	0x8,offset start32
	.code32
start32:
	mov	eax,0x10
	mov	ds,ax
	mov	es,ax
	mov	ss,ax
	mov	esp,0x1000

	xor	eax,eax
	mov	edi,kernel_phy_addr
	mov	esi,edi
	mov	ecx,(64*1024*1024)/4
	rep	stosd
	
	mov	edi,kernel_base_begin
	mov	esi,offset boot1_end
	mov	ecx,[esi+4]
	shr	ecx,2
	rep	movsd

	mov	edi,PAGE_PML4
	mov	edi,PAGE_BASE
	mov	eax,PAGE_PDPTE|PG_P|PG_RW|PG_US
	mov	edx,((reloc >> 39) & 0x1ff) << 3
	mov	[edi+edx],eax
	mov	[edi],eax

	
	mov	edi,PAGE_PDPTE
	mov	eax,PAGE_KNL_PDE|PG_P|PG_RW|PG_US
	mov	edx,((reloc >> 30) & 0x1ff) << 3
	mov	[edi+edx],eax				#核的PDE
	mov	eax,PAGE_TEMP_PDE|PG_P|PG_RW|PG_US
	mov	[edi],eax

	mov	eax,PAGE_APIC_PDE|PG_P|PG_RW
	mov	edx,((IO_APIC_BASE >> 30) & 0x1ff) << 3
	mov	[edi+edx],eax	
#	mov	[edi+0x18],eax	

	mov	edi,PAGE_KNL_PDE
	mov	eax,kernel_phy_addr|PG_P|PG_RW|PG_PS
	mov	ecx,32
	mov	ebx,PG_2M
p.1:
	mov	[edi],eax
	lea	edi,[edi+8]
	add	eax,ebx
	loop	p.1

	mov	edi,PAGE_TEMP_PDE
	mov	eax,0x0|PG_P|PG_RW|PG_PS|PG_US
	mov	ecx,64
	mov	ebx,PG_2M
p.2:
	mov	[edi],eax
	lea	edi,[edi+8]
	add	eax,ebx
	loop	p.2

	mov	edi,PAGE_TEMP_PDE
	mov	edx,(((vmx_begin&0x3fe00000)>>21)<<3)
	mov	eax,0x1a000000|PG_P|PG_RW|PG_PS
	mov	ecx,16
	mov	ebx,PG_2M
	lea	edi,[edi+edx]
p.3:
	mov	[edi],eax
	lea	edi,[edi+8]
	add	eax,ebx
	loop	p.3
.if 1
	mov	edi,PAGE_TEMP_PDE
	mov	eax,0x3fe00000|PG_P|PG_RW|PG_PS
	mov	[edi+0xff8],eax
.endif
	mov	edi,PAGE_APIC_PDE +(((IO_APIC_BASE &0x3fe00000)>>21)<<3)
	mov	eax,IO_APIC_BASE|PG_P|PG_RW|PG_PS|PG_US
	mov	ecx,2
	mov	ebx,PG_2M
p.4:
	mov	[edi],eax
	lea	edi,[edi+8]
	add	eax,ebx
	loop	p.4


	mov	eax,cr4
	or	eax,CR4_FXSR|CR4_PAE|CR4_VMXE
	mov	cr4,eax

	mov	ecx,MSR_EFER
	rdmsr
	or	eax,EFER_SCE|EFER_LME
	wrmsr
	
	mov	eax,PAGE_BASE
	mov	cr3,eax

	mov	eax,cr0
	and	eax,~0x60000000
	or	eax,0x80000020
	mov	cr0,eax

	jmp	0x28:start64
.if 1
hex32:
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
.endif
	.code64
start64:
	xor	eax,eax
	mov	ds,ax
	mov	es,ax
	mov	fs,ax
	mov	gs,ax
	mov	ss,ax
	mov	rsp,0x90000
	push	2
	popfq
	mov	rax,reloc + (2*16*1024 *1024)  + 24
	jmp	rax
	jmp	$
	

	.code64
	.if 0
	.global	hex64,hex32
hex64:
	push	rax
	shr	rax,32
	call	hex32
	pop	rax
hex32:
	push	rax
	shr	rax,16
	call	hex_16
	pop	rax
hex_16:
	push	rax
	shr	ax,8
	call	hex_8
	pop	rax
hex_8:
	push	rax
	shr	al,4
	call	hex8_1
	pop	rax
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
	.endif
	.code16
bootmp:
	mov	ax,cs
	mov	ds,ax
	mov	es,ax
	mov	ss,ax
	mov	sp,0xa00
	cli
	mov	eax,gdt - bootmp + mp_trampoline
	mov	di,gdtr - bootmp
	mov	[di+2],eax
	lgdt	[di]

.if 0
	mov	si,di
	mov	ax,0xb800
	mov	es,ax
	mov	ax,[si]
	mov	di,160*4
	call	hex16
	jmp	h.1
#
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
.endif
h.1:	
	mov	eax,cr4
	or	eax,CR4_FXSR|CR4_PAE|CR4_VMXE|CR4_MCE
#	or	eax,CR4_FXSR|CR4_PAE
	mov	cr4,eax

	mov	ecx,MSR_EFER
	rdmsr
	or	eax,EFER_SCE|EFER_LME
	wrmsr
	
	mov	eax,PAGE_BASE
	mov	cr3,eax

	mov	eax,cr0
	or	eax,0x80000021
	mov	cr0,eax
	.byte	0x66
	.byte	0x67
	.byte	0xea
	.long	ap64-bootmp + mp_trampoline
	.word	0x28
	.code64
ap64:
	xor	eax,eax
	mov	ds,ax
	mov	es,ax
	mov	ss,ax
	mov	rsp,mp_trampoline
	push	2
	popfq
	mov	rax,0x243034105410642
	mov	edi,0xb8000+160*11-8
	mov	[rdi],rax
	mov	rax,[boot1_end + 8]
	jmp	rax
	jmp	$

	.code32
gdtr:
	.word	7*8
	.long	offset gdt
	.long	0x0
gdt:
	.quad	0x0
	.quad	0x00cf9a000000ffff
	.quad	0x00cf92000000ffff
	.quad	0x00009a000000ffff
	.quad	0x000092000000ffff
	.quad	0x00209a0000000000
	.quad	0x0000920000000000
bootmp_end:
int15_map:


data_end:	
	.org 2048
boot1_end:
