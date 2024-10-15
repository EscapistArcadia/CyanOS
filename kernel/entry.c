int kmain() {
    *((char *)0xB8000) = 'A';
    while (1) {
        asm volatile (
            "hlt"
        );
    }
    asm volatile (
        "nop\n"
        "iret\n"
    );
    return 0;
}