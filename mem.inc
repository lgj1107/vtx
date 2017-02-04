#---------------------------	 PHY_ADDR		VIRT_ADDR
#---------------------------
#	核数据空间(长度8M）
#----------------------------	 0x3800_0000	0xffff_fff8_3800_0000
#	KERNEL SPACE(长度24M）       
#----------------------------	 0x2000_0000	0xffff_fff8_2000_0000
#	PAGE TABLE(长度16M）     
#----------------------------	 0x1d00_0000	0xffff_fff8_1d00_0000
#   ???    EPT_TABLE(长度16M）
#----------------------------	 0x1c00_0000	0xffff_fff8_1c00_0000	
#	VMX_CODE		 0x1a00_0000(416M)
#----------------------------
#
#核起始于物理地址0x1c00_0000(448M)处，
#系统页表在0x1c00_0000(448M),长度16MB
#
#内核代码从0x1e00_0000(480M)到512MB结束
#线性地址0xffff_fff8_0000_0000从物理地址0x1c00_0000(448M)映射
#内核代码的链接地址是0xffff_fff8_0200_0000
#页表加上核共占用64MB内存，核数据位于56MB处
#
#重新调整了页表的物理地址改到0x1C00_0000处，EPT的页表移走,因为有些VMX
#指令要求古怪必须是物理地址，并且这些指令还描述的不是很清晰，比如
#VMXON VMCLEAR等他们是使用64位内存操作数，是一个指针，含的值必须是一个
#物理地址，因此VMX代码全部移走，放到32位线性地址空间去
#0x1d00_0000 到 0x1e00_000 这一部分内存现在空闲。
#
#EPT代码放到线性地址0x1a000000 物理地址0x1a000000
#64位下的编译器 在处理bit 31 时要符号扩展 因此物理地址改到这里
#EPT这部分全部在物理地址中 分页是1：1映射
#
#感觉还是很乱 ！！！！VMX有很多理解得不够好
#EPT 违规不知道怎么处理 比如客户软件不停的读写超出指定的物理内存，这该怎么处理！？
#我最初的想法是通过EPT分配一个固定的物理内存区域就不管了，现在看来还不行阿！
#
#memory map
#
	.set	max_memory,512*1024*1024		#512MB
	.set	reloc,0xfffffff800000000
	.set	kernel_phy_addr,0x1c000000		#448M
	.set	kernel_base_begin,kernel_phy_addr + (32*1024*1024) #!!!!!!!!!!!!!!!!!!

	#.set	PAGE_EPT,kernel_phy_addr			#EPT
	#.set	PAGE_EPT,0x0					#EPT

	.set	PAGE_BASE,kernel_phy_addr 			#page table @
	.set	PAGE_PML4,PAGE_BASE
	.set	PAGE_PDPTE,PAGE_BASE + 0x1000*1
	.set	PAGE_APIC_PDE,PAGE_BASE+0x1000*2
	.set	PAGE_PDE,PAGE_BASE + 0x1000*3
	.set	PAGE_KNL_PDE,PAGE_BASE + 0x1000*4
	.set	PAGE_VMX_PDE,PAGE_BASE + 0x1000*5
	.set	PAGE_TEMP_PDE,PAGE_BASE+0x1000*6
	

	.set	kernel_size,32*1024*1024
	.set	kernel_virt_data_base,reloc +56*1024*1024	#
	.set	cpu_comm_data_area,kernel_virt_data_base
	.set	comm_data_size,0x1000
	#	.set	mem_bitmap,cpu_comm_data_area
	#	.set	mem_bitmap_size,256/8			#内存固定在512MB,每个位代表2M

	.set	kernel_idt,cpu_comm_data_area + comm_data_size
	.set	idt_size,256*16
	.set	kernel_data_begin,kernel_idt + idt_size		#FS 基地址指向这里
	.set	kernel_gdt,0
	.set	kernel_gdtr,9*8
	.set	kernel_tss,kernel_gdtr+10
	.set	tss_size,104
	.set	kernel_pcb,kernel_tss +tss_size
	.set	kernel_stk0,0x3000
	.set	kernel_vmxon_region,0x3000
	.set	kernel_vmcs_guest,0x4000
	.set	kernel_stk3,0x6000
	.set	kernel_cpu_data_size,0x6000
	.set	kernel_data_size,0x6000

#-----------------------> 0x6000
#	kernel_stack3
#-----------------------> 0x5000
#	kernel_vmcs_guest
#-----------------------> 0x4000
#	kernel_vmxon_region
#-----------------------> 0x3000
#	kernel_stack0
#-----------------------> 0x2000
#	kernel_PCB
#-----------------------> 0xba
#	TSS
#-----------------------> 0x52
#	GDTR
#-----------------------> 0x48
#	GDT
#-----------------------> 0x0

	.set	vmx_begin,0x1a000000

#
#64 bit gate desc
#	

	.set	int_gate_offset_15_0,0
	.set	int_gate_seg_sel,2
	.set	int_gate_ist,4			#IST--> interrupt stack table
	.set	int_gate_p_dpl_type,5
	.set	int_gate_offset_31_16,6
	.set	int_gate_offset_63_32,8
	.set	int_gate_rsv,12
#
#tss descriptor (LDT)
#
	.set	tss_desc_limit_15_0,0
	.set	tss_desc_base_15_0,2
	.set	tss_desc_base_23_16,4
	.set	tss_desc_p_dpl_type,5
	.set	tss_desc_g_avl_limit,6
	.set	tss_desc_base_31_24,7
	.set	tss_desc_base_63_32,8
	.set	tss_desc_rsv,12
#
#
#page table 
#
	.set	PG_P,0x1
	.set	PG_RW,0x2
	.set	PG_US,0x4
	.set	PG_PWT,0x10
	.set	PG_PCD,0x20
	.set	PG_PS,0x80	#page size;must be 1 (2M page)
	.set	PG_PAT,0x800	#
	.set	PG_2M,0x200000
#
#intel extended page table (EPT) bit 
#
	.set	EPT_READ,0x1
	.set	EPT_WRITE,0x2
	.set	EPT_EXECUTE_ACCESS,0x4
	.set	EPT_2M_PAGE,0x80		#EPT page-directory entry (PDE), 2M page must be 1 

	.set	EPT_MEMORY_TYPE_UC,0<<3
	.set	EPT_MEMORY_TYPE_WC,1<<3
	.set	EPT_MEMORY_TYPE_WT,4<<3
	.set	EPT_MEMORY_TYPE_WP,5<<3
	.set	EPT_MEMORY_TYPE_WB,6<<3

	.set	EPTP_MEMORY_TYPE_UC,0
	.set	EPTP_MEMORY_TYPE_WB,6

