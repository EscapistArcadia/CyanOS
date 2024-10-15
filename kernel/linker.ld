OUTPUT_FORMAT("elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(kmain)

ALIGNMENT = 0x1000;

SECTIONS {
    . = 0x100000 + ALIGNMENT;

    .text : ALIGN(ALIGNMENT) { *(.text) }
    .data : ALIGN(ALIGNMENT) { *(.data) }
    .bss  : ALIGN(ALIGNMENT) { *(.bss) *(COMMON) }
}
