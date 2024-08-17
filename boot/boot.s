; Reference: https://wiki.osdev.org/MBR_(x86)

.code16
.globl _start
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
    movw $0, %ax                // we cannot assign immediate directly
    movw %ax, %ds
    movw %ax, %ss
    movb %dl, (boot_disk)       // saves the boot disk
    
    /* ************************************************************
     * *                     Setting Up Stack                     *
     * ************************************************************ */
    movw $0x7C00, %bp           // call pushes %eip, ret pops it
    movw %bp, %sp

    movw $boot_message, %bx     # gives information
    call print_message

    # loads kernel

    # prepares and loads GDT
    // lgdt gdt

    # enters 64 bits mode

    # jumps to kernel (in C ^_^)

# bx = starting address of printing messages
print_message:
    movb $0x0E, %ah             # opcode, write char on screen
print_message_loop:
    movb (%bx), %al
    cmpb $0, %al                # till \0
    je print_message_end

    int $0x10

    addw $1, %bx
    jmp print_message_loop
print_message_end:
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

boot_disk:
    .byte 0x00

gdt:
    .word gdt_end - gdt_begin
    .long gdt_begin

gdt_begin:
    .quad 0
gdt_end:
    
.org 0x1FE
    .byte 0x55
    .byte 0xaa
