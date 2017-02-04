	.include "apicreg.def"
	.include "regs.def"
	.include "misc.def"
	.include "mem.inc"
	.global start
	.intel_syntax noprefix
	.code64
	.text
	.code64
start:
	.long	0x55aa66bb
	.long	boot2_end - start
	.quad	offset ap_entry			#offset ap_entry
	.quad	boot2_end
start.1:
	mov	rdi,kernel_virt_data_base
	mov	ecx,(8*1024*1024)/8
	xor	rax,rax
	rep	stosq
	
	mov	rdi,kernel_data_begin
	mov	r8,rdi
	movabs	rsi,offset gdt
	mov	ecx,temp_data0 - gdt
	rep	movsb

	lea	rsp,[r8+kernel_stk0]
	lea	rsi,[r8+kernel_gdtr]
	mov	[r8+0x48+2],r8			#gdt table address
	lgdt	[rsi]
	push	SEL_SCODE
	movabs	rax,offset start64
	push	rax
	retfq
start64:
	xor	eax,eax
	mov	ds,ax
	mov	es,ax
	mov	ss,ax
	mov	fs,ax
	mov	gs,ax

	movabs	rdi,kernel_idt
	mov	edx,0x188e
	movabs	rax,offset intx00
	mov	r8,rax
	mov	ebx,0x1fffff
	mov	ecx,20
s.2:
	shr	ebx,1
	jnc	s.3
	mov	[rdi],ax
	shr	rax,16
	mov	[rdi+int_gate_offset_31_16],ax
	shr	rax,16
	mov	[rdi+int_gate_offset_63_32],eax
	mov	[rdi+int_gate_seg_sel],dh
	mov	[rdi+int_gate_p_dpl_type],dl
	add	r8,4
	mov	rax,r8
s.3:
	lea	rdi,[rdi+16]
	loop	s.2

	movabs	rsi,offset idtr
	lidt	[rsi]

	push	rdx
#	mov	dh,SEL_UCODE
	mov	dl,0xee
	set_gate 0x40,int0x40
	pop	rdx
.if 0
	set_gate 0x20,timer
	set_gate 0x21,keyb
	set_gate 0xf0,apic_timer
	set_gate 0xf1,apic_err
	set_gate 0xf2,apic_ici
	set_gate 0xff,apic_svr	
.endif

#
#set TSS
#
	mov	rsi,kernel_data_begin+kernel_gdt+SEL_TSS
	mov	rdi,kernel_data_begin+kernel_tss
	mov	rax,rdi
	mov	[rsi+tss_desc_base_15_0],ax
	shr	rax,16
	mov	[rsi+tss_desc_base_23_16],al
	mov	[rsi+tss_desc_base_31_24],ah
	shr	rax,16
	mov	[rsi+tss_desc_base_63_32],eax

	mov	[rdi+tss_rsp0],rsp
	mov	al,-1
	mov	[rdi+tss_iomap_base],al

	mov	ax,SEL_TSS
	ltr	ax


	mov	rax,kernel_data_begin
	shld	rdx,rax,32
	mov	ecx,IA32_FSBASE
	wrmsr
	call	set_gs
	call	set_syscall
.if 1
#
#set int 0x15 vector
#
	movabs	rsi,offset user_task
	mov	edi,0x9e000
	cld
	mov	ecx,1024
	rep	movsb
	
	mov	r8,0x15*4		#int 0x15 vector address
	mov	ebx,[r8]		#orgi
	mov	[0x9e002],ebx
	mov	ax,0x9e00
	mov	[r8+2],ax
	xor	eax,eax
	mov	[r8],ax
	
	mov	eax,ebx
	mov	edi,0xb8000+160*8 + 64
	call	hex64
#	jmp	$
#
#复制VMX 和 测试代码到指定位置
#
	mov	edi,0x600
	push	rdi
	xor	eax,eax
	cld
	mov	ecx,4096/8
	rep	stosq
	pop	rdi

	movabs	rsi,offset guest_bin
	mov	ecx,[rsi+8]
	rep	movsb

	mov	rdi,vmx_begin
	push	rdi
	xor	eax,eax
	mov	ecx,(32*1024*1024)/8
	rep	stosq
	pop	rdi
	movabs	rsi,offset vmx_i
	mov	ecx,[rsi+4]
	rep	movsb
	movabs	eax,[vmx_i+8]
	mov	rbp,rsp
	call	rax

	vmlaunch
	ud2
.endif

wait.0:
	rep	nop
	jmp	wait.0
jmp_ring3:
	push	SEL_UDATA
	mov	rax,kernel_data_begin + kernel_stk3
	push	rax
	push	0x002
	push	SEL_UCODE
	movabs	rax,offset ring3
	push	rax
	iretq
ring3:
	nop
	jmp	$
set_gate1:
	mov	[rdi],ax
	shr	rax,16
	mov	[rdi+int_gate_offset_31_16],ax
	shr	rax,16
	mov	[rdi+int_gate_offset_63_32],eax
	mov	[rdi+int_gate_seg_sel],dh
	mov	[rdi+int_gate_p_dpl_type],dl
	ret
#
#APIC ID 作为索引 计算AP CPU的核数据地址
#
ap_entry:
	call	get_lapic_id
	mov	rsi,kernel_data_begin
	mov	edi,kernel_data_size
	imul	edi,eax
	add	rdi,rsi
	mov	r15,rdi
#
#FS 基地址设置成CPU 数据起始地址
#
	mov	rax,r15
	shld	rdx,rax,32
	mov	ecx,IA32_FSBASE
	wrmsr
	
	mov	ecx,kernel_tss - kernel_gdt
	rep	movsb			#复制GDT 和 GDTR

	lea	rax,[r15 + kernel_gdt]	
	mov	[r15 +kernel_gdtr +2 ],rax
	
	lea	rsp,[r15 +kernel_stk0]
#
#设置TSS描述符 和TSS段
#
	lea	rdx,[r15 + kernel_gdt + SEL_TSS]
	lea	r14,[r15+kernel_tss]
	mov	rax,r14
	mov	byte ptr [rdx+tss_desc_limit_15_0],0x67
	mov	byte ptr [rdx+tss_desc_p_dpl_type],0x89
	mov	[rdx+tss_desc_base_15_0],ax
	shr	rax,16
	mov	[rdx+tss_desc_base_23_16],al
	mov	[rdx+tss_desc_base_31_24],ah
	shr	rax,16
	mov	[rdx+tss_desc_base_63_32],eax
	
	mov	[r14+tss_rsp0],rsp
	mov	word ptr [r14+tss_iomap_base],0xffff

	lea	rsi,[r15+kernel_gdtr]
	lgdt	[rsi]
	push	SEL_SCODE
	movabs	rax,offset flush_ap
	push	rax
	retfq
flush_ap:

	movabs	rsi,offset idtr
	lidt	[rsi]
	mov	ax,SEL_TSS
	ltr	ax

	movabs	rsi,offset idtr
	lidt	[rsi]
	
	call	enable_apic
	call	set_gs	
	call	set_syscall
	movabs	rsi,offset ap_cpu
	inc	byte ptr [rsi]
	sti
1:
	pause
	jmp	1b
set_gs:
	call	get_lapic_id
	mov	rbx,kernel_data_begin + kernel_pcb
	mov	edx,kernel_data_size
	imul	rax,rdx
	add	rax,rbx
	shld	rdx,rax,32
	mov	ecx,IA32_KERNEL_GSBASE
	wrmsr
	xor	eax,eax
	xor	edx,edx
	mov	ecx,IA32_GSBASE
	wrmsr
	ret
set_syscall:
	mov	ecx,IA32_STAR
	xor	eax,eax
	mov	edx,0x00230018
	wrmsr
	mov	eax,0x202
	mov	ecx,IA32_FMASK
	wrmsr
	movabs	rax,offset sys_call
	shld	rdx,rax,32
	mov	ecx,IA32_LSTAR
	wrmsr
	ret
	
	.global	hex64,hex32
hex64:
	push	rax
	shr	rax,32
	call	hex32
	pop	rax
hex32:
	push	rax
	shr	rax,16
	call	hex16
	pop	rax
hex16:
	push	rax
	shr	ax,8
	call	hex8
	pop	rax
hex8:
	push	rax
	shr	al,4
	call	hex8.1
	pop	rax
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
idtr:
	.word	256*16
	.quad	kernel_idt
cpu_count:
	.byte	0x0
	.global	t_lock
t_lock:
	.byte	0x0
t_lock1:
	.byte	0x1
	.p2align 4
gdt:
	.quad	0x0			#0
	.quad	0x00cf9a000000ffff	#0x8
	.quad	0x00cf92000000ffff	#0x10
	.quad	0x00209a0000000000	#0x18
	.quad	0x0020920000000000	#0x20
	.quad	0x0020f20000000000	#0x28
	.quad	0x0020fa0000000000	#0x30
#
#TSS
#
	.word	0x67			#limit 0 -15
	.word	0x0			#base address
	.byte	0x0			#base address 16 -23
	.byte	0x89			#p_dpl_type
	.byte	0x00			#g_avl_limit-16-19
	.byte	0x0			#byte 24 - 31
	.long	0x0			#base 32 - 63
	.long	0x0			#RSV
	
gdtr:	.word	gdtr - gdt
	.quad	gdt
temp_data0:
	.word	0x0
	.quad	0x0
ap_cpu:
	.byte	0x0
	.global	cpu_flag
cpu_flag:
	.quad	0x0
	.global	msg1
msg1:	.asciz	"dadsadsdadsaads\n"
	.global	bound_test
bound_test:
	.quad	0x1
	.quad	0x0	
int0x15:
	hlt
	
int15_vector:			#real mode 
	.long	0x0
