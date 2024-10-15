int kmain() {
    while (1) {
        asm volatile (
            "hlt"
        );
    }
    return 0;
}