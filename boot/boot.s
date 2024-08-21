; Reference: https://wiki.osdev.org/MBR_(x86)

.code16
.globl _start

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
 * 
 * The boot sector indicates FAT12 information starting at 0x03.
 * The first 3 sectors are for jmp instruction.
 */
jmp _start      /* binary: 0xE9, 0x__, 0x90 */
nop

fat12_info:
    fat12_oem_name:                 .ascii "CyanFAT "   /* 8 bytes */
    fat12_bytes_per_sector:         .word 512
    fat12_sectors_per_cluster:      .byte 1
    fat12_reserved_sector_count:    .word 1
    fat12_fat_table_count:          .byte 2
    fat12_root_directory_count:     .word 0x00E0
    fat12_total_sector_count_16:    .word 2880
    fat12_media_mode:               .byte 0xF0
    fat12_fat_table_length:         .word 9
    fat12_sectors_per_track:        .word 18
    fat12_heads_per_cylindar:       .word 2
    fat12_hidden_sector_count:      .long 0
    fat12_total_sector_count:       .long 2880
    fat12_drive_number:             .byte 0x00
    fat12_reserved:                 .byte 0x00
    fat12_boot_signature:           .byte 0x29
    fat12_volume_serial_number:     .long 0x66CC0BD0
    fat12_volume_label:             .ascii "NO NAME    "
    .byte 0x00
    
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
    movb $33, %al               /* count of sectors */
    movb $0, %ch                /* cylinder index */
    movb $2, %cl                /* all sectors from fat to root directories */
    movb $0, %dh                /* head index */
    movb boot_disk, %dl         /* dl = drive index, given by BIOS */
    movw fat12_load_addr, %bx  /* es:bx = destination memory */
    int $0x13                   /* call routines */
    jc read_disk_err            /* CF = 1 -> error! checks AH, AL */

find_kernel:                    /* compares extension and file name */
    pushfl
    cld                         /* forces increment in string conversion */
    movw fat12_root_directory_offset, %ax
    mulw fat12_bytes_per_sector
    addw %ax, %bx               /* bx = root directory entry */

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
load_kernel_first_block:
    /* bx = kernel dentry in root */
    movw 26(%bx), %si
    
    movb $0x02, %ah
    movb $1, %al                /* count of sectors */
    call db_lba_to_chs          /* si -> int $0x13 */
    movb boot_disk, %dl         /* dl = drive index, given by BIOS */
    movw $0xE000, %bx           /* es:bx = destination memory */
    int $0x13
    jc read_disk_err

switch_mode:
    /* ************************************************************
     * *              Entering 32-bit Protected Mode              *
     * ************************************************************ */
    cli
    lgdt gdt32

    movl %cr0, %eax
    orl $1, %eax
    movl %eax, %cr0

    ljmp $8, $0xE000

halt:
    hlt
    jmp halt

read_disk_err:
    movw $read_disk_err_message, %bx
    call print_message
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
 * converts lba index at %si to chs
 *
 * @param %si the lba index
 * @param %dh output head index
 * @param %cx[5:0] sector index
 * @param %{cx[7,6], cx[15:8]} cylindar index
 */
db_lba_to_chs:
    addw fat12_data_block_offset, %si
    pushw %ax
    pushw %bx
    pushfl
    cld

    movw %si, %ax
    movw $1008, %bx
    divw %bx            /* quotient: cylindar */
    pushw %ax           /* stores cylindar index */
    andw $0, %dx

    movw %si, %ax
    movw $63, %bx
    divw %bx            /* remainder(%dx) + 1: sector */
    incw %dx

    andw $0b1111, %ax   /* quotient(%ax) % 16: head */
    movb %al, %dh

    popw %bx
    movb %bl, %ch
    andb $0b00000011, %bh
    shlb $6, %bh
    movb %bh, %cl
    orb %dl, %cl

    popfl
    popw %bx
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

kernel_name:
    .ascii "CYAN"
kernel_extension:
    .ascii "EXE"

fat12_fat_table_offset:
    .word 0

fat12_root_directory_offset:
    .word 18

fat12_data_block_offset:
    .word 31

fat12_load_addr:
    .word 0x7E00

boot_disk:
    .byte 0x00

.align 4
dentry_size:
    .word 32
gdt32:
    .word gdt32_end - gdt32_begin - 1
    .long gdt32_begin

.align 16
gdt32_begin:
    .quad 0                     /* the first entry must be null */

gdt32_segments:                 /* segmentation is out-dated, and should retire immediately */
    .quad 0x00CF9A000000FFFF    /* why code and data segment is separated? */
    .quad 0x00CF92000000FFFF
    .quad 0x00CFFA000000FFFF    /* user level */
    .quad 0x00CFF2000000FFFF

gdt32_end:
    
.org 0x1FE
    .byte 0x55
    .byte 0xAA
