arch ?= x86_64

BUILD_DIR = ./build
BOOT_DIR = ./boot#/$(arch)
KERNEL_DIR = ./kernel

all: bootloader image filesys

debug:
	as --gstabs -o $(BUILD_DIR)/boot.o $(BOOT_DIR)/boot.s
	ld -Ttext 0x7C00 --oformat binary -o $(BUILD_DIR)/boot.bin $(BUILD_DIR)/boot.o
	ld -Ttext 0x7C00 -o $(BUILD_DIR)/boot.elf $(BUILD_DIR)/boot.o
	as --gstabs -o $(BUILD_DIR)/cyan.o $(KERNEL_DIR)/main.s
	ld -Ttext 0xE000 --oformat binary -o $(BUILD_DIR)/cyan.bin $(BUILD_DIR)/cyan.o
	ld -Ttext 0xE000 -o $(BUILD_DIR)/cyan.elf $(BUILD_DIR)/cyan.o
	# objcopy -O binary $(BUILD_DIR)/kernel.o $(BUILD_DIR)/cyan.bin
	make filesys
	rm $(BUILD_DIR)/*.o
	qemu-system-x86_64 -drive format=raw,file=$(BUILD_DIR)/filesys.img -S -s

bootloader:
	as -o $(BUILD_DIR)/boot.o $(BOOT_DIR)/boot.s
	ld -Ttext 0x7C00 --oformat binary -o $(BUILD_DIR)/boot.bin $(BUILD_DIR)/boot.o
	rm $(BUILD_DIR)/*.o

image:
	as -o $(BUILD_DIR)/kernel.o $(KERNEL_DIR)/main.s
	objcopy -O binary $(BUILD_DIR)/kernel.o $(BUILD_DIR)/cyan.bin
	rm $(BUILD_DIR)/*.o

filesys:
	dd if=/dev/zero of=./build/filesys.img bs=512 count=2880
	mkfs.fat -F 12 -n "CyanOSFAT" ./build/filesys.img
	dd if=./build/boot.bin of=./build/filesys.img conv=notrunc
	mcopy -i ./build/filesys.img ./build/cyan.bin "::CYAN.EXE"

exec:
	qemu-system-x86_64 -drive format=raw,file=./build/filesys.img

clean:
	rm -rf $(BUILD_DIR)/*
