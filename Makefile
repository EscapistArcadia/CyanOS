# architecture specification
ARCH    	:= x86_64

# directories specification
BOOT_DIR    := ./boot
BUILD_DIR   := ./build

EFI_DIR		:= ./gnu-efi
EFI_ARCH	:= $(EFI_DIR)/$(ARCH)
EFI_INCLUDE := $(EFI_DIR)/inc

# compiler specification
CC      := gcc
LD		:= ld

CFLAGS  += -fpic -ffreestanding -fno-stack-protector -fno-stack-check -fshort-wchar -mno-red-zone -maccumulate-outgoing-args -I $(EFI_INCLUDE)

LDFLAGS	+= -shared -Bsymbolic -L $(EFI_ARCH)/lib/ -L $(EFI_ARCH)/gnuefi/ -T $(EFI_DIR)/gnuefi/elf_$(ARCH)_efi.lds $(EFI_DIR)/$(ARCH)/gnuefi/crt0-efi-$(ARCH).o

# file specification
BOOT_SRCS += $(wildcard ./boot/x86_64/*.c)

all: bootloader filesys

bootloader:
	$(CC) $(CFLAGS) -c ./boot/x86_64/main.c -o ./build/main.o
	$(LD) $(LDFLAGS) ./build/main.o -o ./build/main.so -lgnuefi -lefi # these two flags have to be at the end, why?
	objcopy -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym  -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 --subsystem=10 ./build/main.so ./build/main.efi

filesys:
	dd if=/dev/zero of=$(BUILD_DIR)/filesys.img bs=512 count=524288
	mkfs.fat -F 32 $(BUILD_DIR)/filesys.img
	mmd -i $(BUILD_DIR)/filesys.img ::/EFI
	mmd -i $(BUILD_DIR)/filesys.img ::/EFI/BOOT
	mcopy -i $(BUILD_DIR)/filesys.img $(BUILD_DIR)/main.efi ::/EFI/BOOT/BOOTX64.EFI

run:
	qemu-system-$(ARCH) -drive format=raw,file=$(BUILD_DIR)/filesys.img -bios /usr/share/ovmf/OVMF.fd 

clean:
	rm -rf $(BUILD_DIR)/*
