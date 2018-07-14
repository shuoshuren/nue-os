all: Image

.PHONY=clean run-qemu

run-qemu:Image
	- @qemu-system-x86_64 -boot a -fda Image

bootsect.o:bootsect.s
	- @as --32 bootsect.s -o bootsect.o

bootsect: bootsect.o ld-bootsect.ld
	- @ld -T ld-bootsect.ld bootsect.o -o bootsect
	- @objcopy -O binary -j .text bootsect

Image: bootsect setup binary
	- @dd if=bootsect of=Image bs=512 count=1
	- @dd if=setup of=Image bs=512 count=4 seek=1
	- @dd if=binary of=Image bs=512 seek=5
	- @echo "Image built done!"

setup:setup.o
	- @ld -T ld-bootsect.ld setup.o -o setup
	- @objcopy -O binary -j .text setup

binary:binary.o
	- @ld -T ld-bootsect.ld binary.o -o binary
	- @objcopy -O binary -j .text binary

setup.o:setup.s
	- @as --32 setup.s -o setup.o

binary.o:binary.s
	- @as --32 binary.s -o binary.o




clean:
	- rm -f *.o bootsect setup Image binary
