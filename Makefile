# architecture specification
ARCH    	:= x86_64

# directories specification
BOOT_DIR    := ./boot
BUILD_DIR   := ./build
KERNEL_DIR  := ./kernel

EFI_DIR		:= ./gnu-efi
EFI_ARCH	:= $(EFI_DIR)/$(ARCH)
EFI_INCLUDE := $(EFI_DIR)/inc

# compiler specification
CC      := gcc
LD		:= ld

# file specification
BOOT_SRCS += $(wildcard $(BOOT_DIR)/$(ARCH)/*.c)
BOOT_OBJS += $(patsubst $(BOOT_DIR)/$(ARCH)/%, $(BUILD_DIR)/%, $(BOOT_SRCS:.c=.o))

KERNEL_SRCS += $(shell find $(KERNEL_DIR) -name '*.c')
# KERNEL_OBJS += $(addprefix $(BUILD_DIR)/, $(subst /,_,$(subst $(KERNEL_DIR)/,,$(KERNEL_SRCS:.c=.o))))
KERNEL_OBJS += $(patsubst $(KERNEL_DIR)/%, $(BUILD_DIR)/%, $(KERNEL_SRCS:.c=.o))

BOOT_CFLAGS  += -nostdlib -fno-builtin -fpic -ffreestanding -fno-stack-protector -fno-stack-check -fshort-wchar -mno-red-zone -maccumulate-outgoing-args -I $(EFI_INCLUDE)

BOOT_LDFLAGS += -shared -Bsymbolic -L $(EFI_ARCH)/lib/ -L $(EFI_ARCH)/gnuefi/ -T $(EFI_DIR)/gnuefi/elf_$(ARCH)_efi.lds $(EFI_DIR)/$(ARCH)/gnuefi/crt0-efi-$(ARCH).o

KERNEL_CFLAGS += -g -Wall -fno-builtin -fno-stack-protector -mno-red-zone -nostdlib -m64

all: bootloader filesys kernimg

bootloader:
	$(CC) $(BOOT_CFLAGS) -c $(BOOT_SRCS) -o $(BOOT_OBJS)
	$(LD) $(BOOT_LDFLAGS) $(BOOT_OBJS) -o $(BUILD_DIR)/bootx64.so -lgnuefi -lefi
	objcopy -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym  -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-$(ARCH) --subsystem=10 $(BUILD_DIR)/bootx64.so $(BUILD_DIR)/bootx64.efi

filesys:
	dd if=/dev/zero of=$(BUILD_DIR)/filesys.img bs=512 count=524288
	mkfs.fat -F 32 $(BUILD_DIR)/filesys.img
	mmd -i $(BUILD_DIR)/filesys.img ::/EFI
	mmd -i $(BUILD_DIR)/filesys.img ::/EFI/BOOT
	mcopy -i $(BUILD_DIR)/filesys.img $(BUILD_DIR)/bootx64.efi ::/EFI/BOOT/BOOTX64.EFI

$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.c
	mkdir -p $(dir $@)
	$(CC) $(KERNEL_CFLAGS) -c $< -o $@

kernimg: $(KERNEL_OBJS)
	$(LD) -o $(BUILD_DIR)/cyan.elf -T $(KERNEL_DIR)/linker.ld $(KERNEL_OBJS)
	mcopy -i $(BUILD_DIR)/filesys.img $(BUILD_DIR)/cyan.elf ::/CYAN.EXE

run:
	qemu-system-$(ARCH) -drive format=raw,file=$(BUILD_DIR)/filesys.img -bios /usr/share/ovmf/OVMF.fd -S -s

clean:
	rm -rf $(BUILD_DIR)/*
