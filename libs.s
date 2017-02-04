	.include "apicreg.def"
	.include "regs.def"
	.include "misc.def"
	.global	putc
	.code64
	.intel_syntax noprefix
	.global	putc,puts,puts.0
puts:
	push	rdi
	push	rsi
	push	rax
	
	movabs	rdi,offset print_lock
	call	atomic_set
	pop	rax
	pop	rsi
	pop	rdi
puts.0:
	mov	r15,0xb8000
	call	get_cur
	shl	eax,1
	lea	rdi,[r15+rax]
	mov	ebx,160

	cld
	mov	ah,2
	call	putc
	call	put_cur
	
	movabs	rdi,offset print_lock
	btr	qword ptr [rdi],0
	ret
putc.0:
	cmp	al,0xa
	jne	putc.9
putc.1:
	sub	rdi,r15
	push	rax
	mov	eax,edi
	xor	edx,edx
	div	ebx
	mul	ebx
	add	eax,ebx
	cmp	eax,80*25*2
	jb	putc.8
putc.2:
.if 1
	push	rsi
	mov	esi,0xb8000+160
	mov	edi,0xb8000
	mov	ecx,80*24*2/8
	rep	movsq
	pop	rsi
	mov	ecx,160/8
	mov	rax,0x0220022002200220
	rep	stosq
	sub	edi,ebx
	sub	rdi,r15
	mov	eax,edi
.endif
	
putc.8:
	mov	edi,eax
	add	rdi,r15
	pop	rax
	jmp	putc
putc.9:
	stosw
putc:
	lodsb
	test	al,al
	jnz	putc.0
putc_end:	
	sub	rdi,r15
	shr	edi,1
	mov	eax,edi
	ret

	.global	get_cur,put_cur
get_cur:
	push	rdx
	push	rbx
	mov	edx,0x3d4
	mov	al,0xe
	out	dx,al
	inc	dl
	in	al,dx
	mov	bh,al
	dec	dl
	mov	al,0xf
	out	dx,al
	inc	dl
	in	al,dx
	mov	bl,al
	movzx	eax,bx
	pop	rbx
	pop	rdx
	ret

put_cur:
	push	rbx
	push	rdx
	mov	ebx,eax
	mov	edx,0x3d4
	mov	al,0xe
	mov	ah,bh
	out	dx,ax
	mov	al,0xf
	mov	ah,bl
	out	dx,ax
	pop	rdx
	pop	rbx
	ret
	.global	test_and_set
#
#edi
#esi
#edx
#
	.global	test_and_set
test_and_set:
	push	rbx
	mov	ebx,esi
t.1:
	mov	eax,edx
	lock
	cmpxchg	[rdi],bl
	jz	t.1
	
	pop	rbx
	ret
#
#rsi
#rdi
#rax
#
tas:
	push	rbx
	mov	ebx,1
tas.0:
	lock
	cmpxchg	[rdi],bl
	jz	tas.0
	pop	rbx	
	ret

	.global	atomic_set
atomic_set:
a.set1:
	lock
	bts	qword ptr [rdi],0
	jc	a.set1
	ret
	.global	hexasc,hexasc32
hexasc:
	push	rax
	shr	rax,32
	call	hexasc32
	pop	rax
hexasc32:
	push	rax
	shr	eax,16
	call	hex16
	pop	rax
hex16:
hex16.1:
	push	rax
	shr	eax,8
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
	stosb		
	ret

	.global	print_lock
print_lock:
	.quad	0x0
#
#GCC 参数少于7个时，参数从左到右放入寄存器->RDI RSI RDX RCX r8 r9
#参数7个以上时，前6个按上面的方法依次放入寄存器，后面依次从右到左
#放入堆栈。
#
#extren void memcpy (void *dest,const *src,size_t n);
#
	.global	memcpy
memcpy:
	push	rdx
	xchg	rdi,rdx
	test	rdx,rdx
	jz	m.10
	mov	rcx,rdx
	cld
	shr	rcx,3
	test	rcx,rcx
	jz	m.9
	rep	movsq
m.9:
	mov	rcx,rdx
	and	rcx,7
	test	ecx,ecx
	jz	m.10
	rep	movsb
m.10:
	pop	rax
	ret
	.global	dump_cpu
dump_cpu:
	push	rbp
	push	rax
	push	rdx
	push	rcx
	mov	rbp,rsp

	mov	ecx,IA32_FSBASE
	rdmsr
	shl	rax,32
	shrd	rax,rdx,32
	push	rax
	mov	ecx,IA32_GSBASE
	rdmsr
	shl	rax,32
	shrd	rax,rdx,32
	push	rax
.if 1
	mov	rax,cr4
	push	rax
	mov	rax,cr3
	push	rax
	mov	rax,cr2
	push	rax
	mov	rax,cr0
	push	rax
	xor	eax,eax
	mov	ax,es
	push	rax
	mov	ax,ds
	push	rax
	mov	ax,ss
	push	rax
	mov	ax,cs
	push	rax
.endif
	lea	rax,[rbp+4*8]
	push	rax
#	push	rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	r11
	push	r10
	push	r9
	push	r8
	push	rdi
	push	rsi
	mov	rax,[rbp+24]
	push	rax		#RBP的值
	mov	rdx,[rbp+8]
	push	rdx
	mov	rcx,[rbp]
	push	rcx
	push	rbx
	mov	rax,[rbp+16]
	push	rax
	call	get_lapic_id
	push	rax
dump.0:
	movabs	rsi,offset msg
	movabs	rdi,offset boot2_end
dump.01:
	mov	r15,rdi
	cld
	jmp	dump.1
dump.0a:
	stosb
dump.1:
	lodsb
	test	al,al		
	jz	dump.11		#是0，结束
	test	al,0x80		#是控制符？
	jz	dump.0a		#不是

	mov	cl,al
	mov	al,'='
	stosb
	pop	rax
	test	cl,0x1		#16bit?
	jz	dump.2		#不是
	call	hex16
	jmp	dump.7
dump.2:
	test	cl,0x2		#32bit?
	jz	dump.3
	call	hexasc32
	jmp	dump.7
dump.3:
	call	hexasc
dump.7:
	test	cl,0x8		#是换行？
	jz	dump.8		#不是
	mov	al,0xa		#写换行符
	stosb
	jmp	dump.1
dump.8:
	mov	ax,0x2020
	stosw
	jmp	dump.1
dump.11:
	stosb
dump.12:
	mov	rsi,r15
	call	puts
	lea	rsp,[rsp+4*8]
	ret	
#
#1 = word
#2 = long
#4 = quad
#8 = end of line
#0x80 = 控制符
#
	.set	B16,1
	.set	B32,2
	.set	B64,4
	.set	EOL,8
	.global	msg
msg:
	.ascii	"APIC_ID"
	.byte	0x80|EOL|B32
	.ascii	"RAX"
	.byte	0x80
	.ascii	"RBX"
	.byte	0x80|EOL
	.ascii	"RCX"
	.byte	0x80
	.ascii	"RDX"
	.byte	0x80|EOL
	.ascii	"RBP"
	.byte	0x80
	.ascii	"RSI"
	.byte	0x80|EOL
	.ascii	"RDI"
	.byte	0x80
	.ascii	" R8"
	.byte	0x80|EOL
	.ascii	" R9"
	.byte	0x80
	.ascii	"R10"
	.byte	0x80|EOL
	.ascii	"R11"
	.byte	0x80
	.ascii	"R12"
	.byte	0x80|EOL
	.ascii	"R13"
	.byte	0x80
	.ascii	"R14"
	.byte	0x80|EOL
	.ascii	"R15"
	.byte	0x80
	.ascii	"RSP"
	.byte	0x80|EOL

	.ascii	"CS"
	.byte	0x80|B16
	.ascii	"SS"
	.byte	0x80|B16
	.ascii	"DS"
	.byte	0x80|B16
	.ascii	"ES"
	.byte	0x80|B16|EOL

	.ascii	"CR0"
	.byte	0x80
	.ascii	"CR2"
	.byte	0x80|EOL
	.ascii	"CR3"
	.byte	0x80
	.ascii	"CR4"
	.byte	0x80|EOL
	.ascii	"GS_BASE"
	.byte	0x80
	.ascii	"FS_BASE"
	.byte	0x80|EOL
	.byte	0x0

#RAX=0000000000000000  RBX=00000000000000a0
#RCX=00000000c0000082  RDX=0000000000000000
#RSP=fffffff803805000  RBP=0000000000000000
#RSI=fffffff8020009b4  RDI=fffffff8020009a2
# R8=fffffff803802000   R9=0000000000000000
#R10=0000000000000000  R11=0000000000000000
#R12=0000000000000000  R13=0000000000000000
#R14=0000000000000000  R15=00000000000b8000
#IOPL=0 id vip vif ac vm rf nt of df IF tf sf zf af pf cf
#EG sltr(index|ti|rpl)     base    limit G D
#CS:0018( 0003| 0|  0) 00000000 00000000 0 0
#DS:0000( 0000| 0|  0) 00000000 00000000 0 0
#SS:0000( 0000| 0|  0) 00000000 00000000 0 0
#ES:0000( 0000| 0|  0) 00000000 00000000 0 0
#FS:0000( 0000| 0|  0) 03802000 00000000 0 0
#GS:0000( 0000| 0|  0) 00000000 00000000 0 0
#MSR_FS_BASE:fffffff803802000
#MSR_GS_BASE:0000000000000000
#RIP=fffffff80200021e (fffffff80200021e)
#CR0=0x80000031 CR2=0x0000000000000000
#CR3=0x1d000000 CR4=0x00002220
fmt:
buf:
	.global	vmx_i
vmx_i:
	.incbin "vmx"
	.global	user_task
user_task:
	.incbin "taska"
	.global	guest_bin
guest_bin:
	.incbin	"guest"
	.global	boot2_end
boot2_end:
	.global	disp_buff
	.bss
disp_buff:
