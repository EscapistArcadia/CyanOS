#include <x86_desc.h>

const struct gdt_desc_64 gdt_64[] = {
    {},
    {   /* kernel code segment */
        .limit_15_00 = 0xFFFF,
        .base_15_00 = 0x0000,
        .base_23_16 = 0x00,
        .accessed = 0,
        .read_write = 1,
        .dir_cfr = 0,
        .seg_type = 1,
        .desc_type = 1,
        .dpl = 0,
        .present = 1,
        .limit_19_16 = 0xF,
        .reserved0 = 0,
        .long_mode = 1,
        .size = 0,
        .granularity = 1,
        .base_31_24 = 0x00,
        .base_63_32 = 0x00000000,
        .reserved1 = 0
    },
    {   /* kernel data segment */
        .limit_15_00 = 0xFFFF,
        .base_15_00 = 0x0000,
        .base_23_16 = 0x00,
        .accessed = 0,
        .read_write = 1,
        .dir_cfr = 0,
        .seg_type = 0,
        .desc_type = 1,
        .dpl = 0,
        .present = 1,
        .limit_19_16 = 0xF,
        .reserved0 = 0,
        .long_mode = 1,
        .size = 0,
        .granularity = 1,
        .base_31_24 = 0x00,
        .base_63_32 = 0x00000000,
        .reserved1 = 0
    },
    {   /* user code segment */
        .limit_15_00 = 0xFFFF,
        .base_15_00 = 0x0000,
        .base_23_16 = 0x00,
        .accessed = 0,
        .read_write = 1,
        .dir_cfr = 0,
        .seg_type = 1,
        .desc_type = 1,
        .dpl = 3,
        .present = 1,
        .limit_19_16 = 0xF,
        .reserved0 = 0,
        .long_mode = 1,
        .size = 0,
        .granularity = 1,
        .base_31_24 = 0x00,
        .base_63_32 = 0x00000000,
        .reserved1 = 0
    },
    {   /* kernel data segment */
        .limit_15_00 = 0xFFFF,
        .base_15_00 = 0x0000,
        .base_23_16 = 0x00,
        .accessed = 0,
        .read_write = 1,
        .dir_cfr = 0,
        .seg_type = 0,
        .desc_type = 1,
        .dpl = 3,
        .present = 1,
        .limit_19_16 = 0xF,
        .reserved0 = 0,
        .long_mode = 1,
        .size = 0,
        .granularity = 1,
        .base_31_24 = 0x00,
        .base_63_32 = 0x00000000,
        .reserved1 = 0
    },
};

const struct gdt_entry gdt_entry = {
    .size = sizeof(gdt_64) - 1,
    .entry = gdt_64
};

int kmain() {
    lgdt(gdt_entry);

    while (1);
    return 0;
}
