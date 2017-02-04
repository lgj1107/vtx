	.include "apicreg.def"
	.include "regs.def"
	.include "misc.def"
	.include "mem.inc"
	.global	intx00
	.intel_syntax noprefix
	.code64
#
#stack 
#
	.set	stk_int,0
	.set	stk_err_code,8
	.set	stk_rip,16
	.set	stk_cs,24
	.set	stk_rflags,32
	.set	stk_rsp,40
	.set	stk_ss,48
	.set	stk_size,56
#
#  Exception jump table.
#
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
	push	[rsp]
	mov	qword ptr [rsp+8],0x0
except:
	mov	edi,0xb8000+160*22
	mov	rax,[rsp]
	call	hex64
	add	edi,2
	mov	rax,[rsp+8]
	call	hex64
	add	edi,2
	mov	rax,[rsp+16]
	call	hex64
	add	edi,2
	mov	rax,[rsp+24]
	call	hex64
	add	edi,2
	mov	rax,[rsp+32]
	call	hex64
	add	edi,2
	mov	rax,[rsp+40]
	call	hex64
	add	edi,2
	mov	rax,[rsp+48]
	call	hex64
	
	jmp	$
.if 1
	.global	timer,keyb,apic_timer,apic_err,apic_svr,apic_ici
timer:
	push_fram
	pop_fram
	xor	eax,eax
	mov	[APIC_EOI],eax
	iretq
keyb:
	push_fram
	mov	esi,IOAPIC_REG_SEL
	mov	edi,IOAPIC_WIN
	mov	eax,IOAPIC_REDTBL2	#timer
	mov	[rsi],eax
	mov	eax,[rdi]
	in	al,0x60
	mov	edi,0xb8000+160*10+128
	call	hex64
	pop_fram
	xor	eax,eax
	mov	[APIC_EOI],eax
	iretq
apic_timer:
	push_fram
#	rdtsc
#	print_hex 8+32
	pop_fram
	xor	eax,eax
	mov	[APIC_EOI],eax
	iretq
apic_err:
	xor	eax,eax
	mov	[APIC_EOI],eax
	iretq
apic_svr:
	push_fram
	movabs	rdx,offset svr_count
	mov	rax,[rdx]
	inc	rax
	push	rax
	print_hex 21-64
	pop	rax
	mov	[rdx],rax
	pop_fram
	iretq
svr_count:
	.quad	0x0
#
#rdi  rsi  rdx
#
#hexasc rdi 输出缓冲 rsi是要转换的数字
#
	.global	int0x40
int0x40:
	push_fram
	cmp	al,1
	je	puts0
	cmp	al,0
	je	hexasc0
int0x40.9:
	pop_fram
	iretq
puts0:
	mov	rsi,rdi
	call	puts
	jmp	int0x40.9
hexasc0:
	mov	rax,rsi
	call	hexasc
	jmp	int0x40.9
intable:
	.quad	offset hexasc
	.quad	offset puts
	.quad	0x0
	.quad	0x0
	.global	apic_ici
apic_ici:
	push_fram
	movabs	rsi,offset cpu_flag
	mov	rax,[rsi]
	
#	movabs	rax,offset ap_vmx
	mov	[rsp+14*8],rax
	jmp	a.9
#	jne	a.9

	movabs	rsi,offset user_task
	mov	rdi,[rsi]
	mov	r14,rdi

	mov	ecx,1024
	cld
	rep	movsb
	
	swapgs
	mov	gs:[pcb_rsp0],rsp
	swapgs

	mov	ecx,IA32_FSBASE
	rdmsr
	mov	edi,0xb8000+160*11-16
	call	hex32
	mov	edi,0xb8000+160*12-32
	mov	rax,rsp
	call	hex64

	push	SEL_UDATA
	lea	rax,[r14 + 0x1000]
	push	rax
	push	0x202
	push	SEL_UCODE
	lea	rax,[r14+16]
	push	rax
	jmp	a.10
a.9:
	pop_fram
a.10:
	xor	eax,eax
	mov	[APIC_EOI],eax
	iretq
	.global	sys_call
sys_call:
	swapgs
	mov	gs:[pcb_rsp3],rsp
	mov	rsp,gs:[pcb_rsp0]
	push	rcx		#rip
	push	r13
	push	r11		#RFLAGS
	movabs	rax,offset call_table
	mov	rax,[rax+rdi*8]
	call	rax

	pop	r11
	pop	r13
	pop	rcx
	mov	gs:[pcb_rsp0],rsp
	mov	rsp,gs:[pcb_rsp3]
	swapgs
	sysretq

call_table:
	.quad	0x0
	.quad	0x0
	.quad	0x0
	.quad	offset puts 
	.quad	0x0
	.global	cpu0_cur,cpu2_cur,use_scr
cpu0_cur:
	.2byte	0x0
cpu2_cur:
	.2byte	0x0
use_scr:
	.byte	0x0
	.global	cpu_disp,cpu2_disp
cpu_disp:
	.long	0xb8000
cpu2_disp:
	.long	0xb8fa0
cpu2_stk:
	.fill	5*8,1,0
	.set	B16,1
	.set	B32,2
	.set	B64,4
	.set	EOL,8
	.global	int_fmt
int_fmt:
	.ascii	"INT"
	.byte	0x80|B16
	.ascii	"ERR"
	.byte	0x80|B16|EOL
	.ascii	"RIP"		#
	.byte	0x80
	.ascii	" CS"		#
	.byte	0x80|B16
	.ascii	"EFL"		#eflage =
	.byte	0x80|B32|EOL
	.ascii	"RSP"		#
	.byte	0x80
	.ascii	" SS"		#
	.byte	0x80|B16|EOL
		
	.global	hex_64,hex_32
hex_64:
	push	rax
	shr	rax,32
	call	hex_32
	pop	rax
hex_32:
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
	call	hex_8.1
	pop	rax
hex_8.1:
	and	al,0xf
	add	al,0x30
	cmp	al,0x39
	jbe	hex_8.2
	add	al,0x7
hex_8.2:
	stosb		
	ret	
	.set	rsp_int,0
	.set	rsp_err,8
	.set	rsp_rip,16
	.set	rsp_cs,24
	.set	rsp_efl,32
	.set	rsp_rsp,40
	.set	rsp_ss,48
.endif
