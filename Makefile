exec:
	as -o ./build/boot.o ./boot/boot.s
	ld -Ttext 0x7C00 --oformat binary -o ./build/boot.bin ./build/boot.o
	qemu-system-x86_64 -drive format=raw,file=./build/boot.bin

img:
	as -o ./build/boot.o ./boot/boot.s
	ld -Ttext 0x7C00 --oformat binary -o ./build/boot.bin ./build/boot.o

debug:
	# bootloader
	as --gstabs -o ./build/boot.o ./boot/boot.s
	ld -Ttext 0x7C00 --oformat binary -o ./build/boot.bin ./build/boot.o
	qemu-system-x86_64 -drive format=raw,file=./build/boot.bin -S -s

filesys:
	dd if=/dev/zero of=./build/filesys.img bs=512 count=4096
	mkfs.fat -F 12 -n "CyanOSFAT" ./build/filesys.img
	dd if=./build/boot.bin of=./build/filesys.img conv=notrunc
	# mcopy -i ./build/filesys.img ./build/kernel.bin "::kernel"

clean:
	rm -f ./build/*.o ./build/*.bin
