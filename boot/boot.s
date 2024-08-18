; Reference: https://wiki.osdev.org/MBR_(x86)

.code16
.globl _start

jmp _start

/* 
* ************************************************************
* *                  File System Inforation                  *
* ************************************************************
* 
* The bootloader loaded by BIOS is originally in a partition of
* the hard disk. It not only stores bootloader, but also stores
* basic information about the entire file system. Therefore, to
* successfully load the kernel from the file system, we need to
* contain these data.
*
* Temporarily, the OS relies on the FAT12 system, which is out-
* dated, but I do not read much longer documentation. In the future,
* I'll support more file systems.
*/

.org 0x0B      /* the first 11 bytes is ignored by FAT 12 */
fat12_info:
    .word 512   /* bytes per sector */
    .byte 1     /* sector per cluster */
    .word 1     /* reserved sectors count */
    .byte 2     /* count of tables, each takes 9 sectors */
    .word 0xE0  /* max root directories count, 0xE0 is the max */
    .word 2880  /* total sector count */
    .byte 0xF0  /* ignored */                   /* WHY */
    .word 9     /* FAT length in sector */      /* WHY */
    .word 18    /* track length in sector */    /* WHY */
    .word 2     /* head count */                /* WHY */
    .long 0     /* ignored */
    .long 2880  /* sector count */
    .word 0     /* ignored */
    .byte 0x29  /* boot signature */
    .long 0xECEBECEB        /* volume label */
    .ascii "CyanOSFat "    /* must be 11 bytes, whitespace */
    .byte 0

_start:
    /* 
     * ************************************************************
     * *                       Segmentation                       *
     * ************************************************************
     * 
     * Compared to 32-bit and 64-bit mode, segmentation in 16-bit mode
     * is much simpiler. The maximum accessible address is 0xFFFF.
     * The accessed memory is (%sr * 16) + address, which enables us
     * to prepare for kernel environment in much more location.
     * To make bootloader simple, we make all processor-defined segments
     * to use 0.
     */
    movw $0, %ax                /* we cannot assign immediate directly */
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    movb %dl, (boot_disk)       /* saves the boot disk */
    
    /* ************************************************************
     * *                     Setting Up Stack                     *
     * ************************************************************ */
    /* see https://wiki.osdev.org/Memory_Map_(x86), NOT RANDOMLY SELECTED */
    movw $0x7C00, %bp           /* call pushes %eip, ret pops it */
    movw %bp, %sp

    movw %dx, %bx
    call print_hex
    
    /* 
     * ************************************************************
     * *               Load Kernel From File System               *
     * ************************************************************
     * 
     * We need to load the kernel from the file systems, which is
     * stored in the root directory of the file system. We have to
     * traverse it and load if it returns true.
     */
read_sectors:
    movb $0x02, %ah             /* Opcode for read sector(s) from hard disk */
    movb $13, %al               /* read all root directories */
    movb $0, %ch                /* cylinder index */
    movb $20, %cl               /* sector index of root directories */
    movb $0, %dh                /* head index */
    movb boot_disk, %dl         /* dl = drive index, given by BIOS */
    movw $0x8000, %bx           /* es:bx = destination memory */
    int $0x13                   /* call routines */
    jc read_disk_err

find_kernel:                    /* compares extension and file name */
    pushfl
    popw %ax                    /* saves the flag */
    cld

find_kernel_ext:
    cmpb $0xE5, (%bx)           /* current dentry is free */
    je find_kernel_iter
    cmpb $0x00, (%bx)           /* reaches the end */
    je kernel_not_found_err_message
    movw $3, %cx                /* length of comparision */
    leaw 8(%bx), %si
    movw $kernel_extension, %di
    repe cmpsb
    jnz find_kernel_iter        /* not equal, next iteration */

find_kernel_name:
    movw %bx, %si
    movw $kernel_name, %di
    repe cmpsb
    jz load_kernel
    
find_kernel_iter:
    addw $0x20, %bx             /* next dentry */
    jmp find_kernel_ext

load_kernel:
    movw $kernel_found_message, %bx
    call print_message

halt:
    hlt
    jmp halt

read_disk_err:
    movw $read_disk_err_message, %bx
    call print_message
    movw $0, %bx
    movb %ah, %bl
    call print_hex
    movb %al, %bl
    call print_hex
    jmp halt

find_disk_err:
    movw $kernel_not_found_err_message, %bx
    call print_message
    jmp halt

/**
 * @brief prints null-terminated string starting at %bx
 * 
 * @param %bx the null-terminated string
 * @return none
 */
print_message:
    pushw %ax
    movb $0x0E, %ah             # opcode, write char on screen
print_message_loop:
    movb (%bx), %al
    cmpb $0, %al                # till \0
    je print_message_end

    int $0x10

    addw $1, %bx
    jmp print_message_loop
print_message_end:
    popw %ax
    ret

/**
 * @brief prints the hex format of number in %bx
 * 
 * @param %bx the input number
 * @return none
 */
print_hex:
    pushw %ax
    pushw %di
    
    movb $0x0E, %ah
    movb $'0', %al
    int $0x10
    movb $'x', %al
    int $0x10

    movw %bx, %di
    andw $0xF000, %di
    shr $12, %di
    movb hex_map(%di), %al
    int $0x10

    movw %bx, %di
    andw $0x0F00, %di
    shr $8, %di
    movb hex_map(%di), %al
    int $0x10

    movw %bx, %di
    andw $0x00F0, %di
    shr $4, %di
    movb hex_map(%di), %al
    int $0x10

    movw %bx, %di
    andw $0x000F, %di
    movb hex_map(%di), %al
    int $0x10

    movb $0x0D, %al
    int $0x10
    movb $0x0A, %al
    int $0x10

    popw %di
    popw %ax
    ret

boot_message:
    .ascii "OS is booting, please wait ^_^"
    .byte 0x0D
    .byte 0x0A
    .byte 0x00

read_disk_err_message:
    .ascii "Failed to read hard disk!"
    .byte 0x0D
    .byte 0x0A
    .byte 0x00

kernel_not_found_err_message:
    .ascii "Cannot find kernel!"
    .byte 0x0D
    .byte 0x0A
    .byte 0x00

kernel_found_message:
    .ascii "Kernel Found!"
    .byte 0x0D
    .byte 0x0A
    .byte 0x00

hex_map:
    .ascii "0123456789ABCDEF"

kernel_name:
    .ascii "CYAN"
kernel_extension:
    .ascii "EXE"

boot_disk:
    .byte 0x00


.align 4
dentry_size:
    .word 32
gdt:
    .word gdt_end - gdt_begin - 1
    .long gdt_begin

.align 16
gdt_begin:
    .quad 0
    .quad 0
    .quad 0
gdt_end:
    
.org 0x1FE
    .byte 0x55
    .byte 0xaa
