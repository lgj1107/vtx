all:new
inc=misc.def regs.def apicreg.def vmcs.def mem.inc
OBJS =boot2.o apic.o int.o libs.o
OBJS2=boot0 boot1 boot2  #taska
libs.o:vmx guest taska
%.o:%.s $(inc)
	as  -o $@ $<
boot0:boot0.o
	ld -N -e start -Ttext=0x600 -o boot0.out boot0.o
	objcopy -S -O binary boot0.out $@
boot1:boot1.o
	ld -N -e start -Ttext=0x800 -o boot1.out boot1.o
	objcopy -S -O binary boot1.out $@
boot2:$(OBJS)
	ld -N -T ld.src -o boot2.out $(OBJS)
	objcopy -S -O binary boot2.out $@
guest:guest.o
	ld -N -e begin -Ttext=0x600 -o guest.out guest.o
	objcopy -S -O binary guest.out $@
taska:taska.o
	ld -N -e start  -Ttext=0x00000 -o taska.out  taska.o
	objcopy -S -O binary taska.out $@
vmx:vmx.o
	ld -N -e start_vmx  -Ttext=0x1a000000 -o vmx.out vmx.o
	objcopy -S -O binary vmx.out $@
new:$(OBJS2) 
	cat $(OBJS2)> new
clean:
	rm -f boot[0-9].o boot[0-9].out boot[0-9] real.iso task[a-b].o task[a-b].out  $(OBJS) guest.o guest vmx.o vmx *.out
mmc:
	dd if=new of=/dev/sdb conv=sync
	sync
	eject /dev/sdb
img:
	dd if=msdos.img of=/dev/sdb conv=sync
	sync
iso:
	losetup /dev/loop0 disk.img
	dd if=msdos.img of=/dev/loop0 conv=sync
	sleep 0.5
	losetup -d /dev/loop0
	genisoimage -o real.iso -R -J -b disk.img  .
cimg:	
	losetup /dev/loop0 c.img
	dd if=new of=/dev/loop0 conv=sync
	sleep 0.5
	losetup -d /dev/loop0
