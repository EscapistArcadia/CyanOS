#ifndef _CYAN_X86_DESC_H
#define _CYAN_X86_DESC_H

#include <types.h>

struct gdt_desc_64 {
    uint16_t limit_15_00;   /* ignored in x86_64 */
    uint16_t base_15_00;    /* starting address of a segment */
    uint8_t base_23_16;
    uint8_t accessed : 1;   /* if the segment is accessed */
    uint8_t read_write : 1; /* code: readable? data: writable? */
    uint8_t dir_cfr : 1;
    uint8_t seg_type : 1;   /* 0 for code, 1 for data */
    uint8_t desc_type : 1;  /* 0 for system segment, 1 for code/data */
    uint8_t dpl : 2;
    uint8_t present : 1;
    uint8_t limit_19_16 : 4;
    uint8_t reserved0 : 1;
    uint8_t long_mode : 1;  /* 1 for 64-bit data segment */
    uint8_t size : 1;       /* must be clear for 64-bit arch */
    uint8_t granularity : 1;
    uint8_t base_31_24;
    uint32_t base_63_32;
    uint32_t reserved1;
} __attribute__((packed));

struct gdt_entry {
    uint16_t size;
    struct gdt_desc_64 *entry;
} __attribute__((packed));

/**
 * @brief loads the \b GDT (Global Descriptor Table)
 */
#define lgdt(gdt)       \
do {                    \
    asm volatile (      \
        "lgdt %0"       \
        :               \
        : "g" (gdt)     \
        : "memory"      \
    );                  \
} while (0)             

/**
 * @brief loads the \b IDT (Interrupt Descriptor Table)
 */
#define lidt(idt)       \
do {                    \
    asm volatile (      \
        "lidt %0"       \
        :               \
        : "g" (idt)     \
        : "memory"      \
    );                  \
} while (0)

#endif
