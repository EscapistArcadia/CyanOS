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
 * Temporarily, the OS relies on the FAT32 system, which is out-
 * dated, but I do not want to read much longer documentation.
 * In the future, I'll support more file systems.
 * 
 * The boot sector indicates FAT32 information starting at 0x03.
 * The first 3 sectors are for jmp instruction.
 */
fat32_jump_boot:
jmp _start      /* binary: 0xE9, 0x__, 0x90 */
nop

fat32_info:
    fat32_oem_name:                 .ascii "MSWIN4.1"   /* 8 bytes */
    fat32_bytes_per_sector:         .word 512
    fat32_sectors_per_cluster:      .byte 1
    fat32_reserved_sector_count:    .word 32            /* 1 for 12 and 16 */
    fat32_fat_table_count:          .byte 2             /* fixed */
    fat32_root_directory_count:     .word 0             /* fixed for 32 */
    fat32_total_sector_count_16:    .word 0
    fat32_media_mode:               .byte 0xF8          /* removable */
    fat32_fat_table_length_16:      .word 0
    fat32_sectors_per_track:        .word 63
    fat32_heads_per_cylindar:       .word 16
    fat32_hidden_sector_count:      .long 0
    fat32_total_sector_count:       .long 262144
    fat32_fat_table_length:         .long 2048
    fat32_extended_flags:           .word 0x0000
    fat32_version:                  .word 0x0000
    fat32_root_cluster:             .long 2
    fat32_info_block:               .word 1
    fat32_backup_boot_sector:       .word 6
    fat32_bs_reserved:              .long 0
                                    .long 0
                                    .long 0
    fat32_drive_number:             .byte 0x80
    fat32_bpb_reserved:             .byte 0x00
    fat32_boot_signature:           .byte 0x29
    fat32_volume_serial_number:     .long 0x66CC0BD0
    fat32_volume_label:             .ascii "NO NAME    "
    fat32_file_system_type:         .ascii "FAT32   "

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
    xorw %ax, %ax               /* we cannot assign immediate directly */
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    movb %dl, (boot_disk)       /* saves the boot disk */
    
    /* ************************************************************
     * *                     Setting Up Stack                     *
     * ************************************************************ */
    /* see https://wiki.osdev.org/Memory_Map_(x86), NOT RANDOMLY SELECTED */
setup_stack:
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
read_file_system_info:
    movl $1, %esi               /* start from sector #1 */
    movb $1, %cl                /* for fs info sector */
    movw $0x7E00, %bx           /* dest = 0x7E00 */
    call read_disk              /* 0x7C00 - 0x7E00: file system info sector */

read_root_dentry:               /* %esi = 32 + 2048 * 2 */
    movzwl fat32_reserved_sector_count, %esi
    addl fat32_fat_table_length, %esi
    addl fat32_fat_table_length, %esi

traverse_root_dentry:
    movb $8, %cl               /* count = 16 */
    movw $0xF000, %bx           /* dest = 0xE000 */
    call read_disk              /* 0xE000 - 0xFFFF: root dentries */

    cmpb $0x00, (%bx)           /* we reached the end */
    je kernel_not_found
    cmpb $0xE5, (%bx)           /* this dentry is free */
    je traverse_next_dentry

check_file_ext:
    leaw 8(%bx), %si
    movw $kernel_extension, %di /* %es:%di = "EXE" */
    movw $3, %cx
    repe cmpsb                  /* equivalent to: strncmp(%ds:%si, %es:%di, %cx) */
    jnz traverse_next_dentry    /* ZF is set if equal */

check_file_name:
    movw %bx, %si
    movw $kernel_name, %di
    movw $4, %cx
    repe cmpsb                  /* strncmp(dentry->name, "CYAN", 4) */
    jnz traverse_next_dentry

    jmp found_kernel

traverse_next_dentry:
    addw fat32_dentry_size, %bx
    jc traverse_next_group      /* 0x10000 -> 0x0, means we reached the end */
    jmp check_file_ext

traverse_next_group:
    addl $8, %esi               /* read the next 16 root dentries sectors */
    jmp traverse_root_dentry

/* good if we reach here, %ebx is the dentry */
found_kernel:
    movl $0xA000, %ecx          /* %ecx = kernel address */

    movzwl 20(%bx), %esi
    shll $16, %esi
    movw 26(%bx), %si           /* %esi = dentry->first_cluster */
    
read_kernel_executable:
    addl fat32_data_block_offset, %esi
    movb $1, %cl
    movl %ecx, %ebx
    call read_disk

read_fat_table:


halt:
    hlt
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
 * read_disk:
 * @brief read specified amount of sectors from a certain sector
 *        and write to certain address
 *
 * @param %esi    32bit LBA index
 * @param %cl     8 bit count
 * @param %es:%bx destination
 *
 * @return %dh = Head
 *         {%cx[7:6], %cx[15:8]} = Cylindar
 *         {%cx[5:0]} = Sector
 */
read_disk:
    pushl %esi
    pushw %ax
    pushw %dx
    pushw %cx

/**
 * lba_to_chs:
 * @brief transfer LBA format to CHS format
 *
 * @param %esi 32bit LBA index
 *
 * @return %dh = Head
 *         {%cx[7:6], %cx[15:8]} = Cylindar
 *         {%cx[5:0]} = Sector
 */
lba_to_chs:
    movw %si, %ax
    shrl $16, %esi
    movw %si, %dx
    pushw %bx

    movw fat32_sectors_per_track, %si
    divw %si                    /* %ax = quotient, %dx = remainder */
    addw $1, %dx
    andw $0b111111, %dx         /* sector index */
    movw %dx, %cx               /* %cx[5:0] = Sector */

    xorw %dx, %dx               /* clears the high 16 bits */
    movw fat32_heads_per_cylindar, %si
    divw %si
    shlw $8, %dx                /* %dh = Head */

    movb %al, %ch               /* %ch = cylindar[7:0] */
    movb %ah, %al
    shlb $6, %al
    orb %al, %cl                /* %cl[7:6] = %ch[7:6] = cylindar[9:8] */
    # ret

read_sectors:
    pushw %si
    movw %sp, %si
    movb 4(%si), %al            /* retrieves lower 8 bytes of %cx as count %al */
    movb $2, %ah                /* opcode for reading sector */
    popw %si
    popw %bx                    /* %bx = destination address */
    movb boot_disk, %dl
    addw $2, %sp                /* %cx */
    int $0x13
    jc kernel_not_found

    popw %dx
    popw %ax
    popl %esi
    ret

kernel_not_found:
    movw $kernel_not_found_message, %bx
    call print_message
    jmp halt

kernel_name:
    .ascii "CYAN"
kernel_extension:
    .ascii "EXE"

kernel_not_found_message:
    .string "Kernel not found!\r\n"

boot_disk:
    .byte 0x00

.align 4
fat32_dentry_size:
    .word 32
gdt32:
    .word gdt32_end - gdt32_begin - 1
    .long gdt32_begin

.align 16
gdt32_begin:
    .quad 0                     /* the first entry must be null */

gdt32_segments:                 /* segmentation is out-dated, and should retire immediately */
    .quad 0x00CF9A000000FFFF    /* why code and data segment is separated? */
    .quad 0x00CF92000000FFFF    /* kernel data */
    .quad 0x00CFFA000000FFFF    /* user code */
    .quad 0x00CFF2000000FFFF    /* user data */

gdt32_end:

fat32_data_block_offset:        /* 32 + 2048 * 2 */
    .long 4126

.org 0x1FE                      /* indicating the partition is bootable */
    .byte 0x55
    .byte 0xAA
