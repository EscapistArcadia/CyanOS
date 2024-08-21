.code32

entry:
    movw $0x45, 0xB8000
    movw $0x07, 0xB8001

spin:
    jmp spin
