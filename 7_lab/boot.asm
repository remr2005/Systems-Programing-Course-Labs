BITS 16
ORG 0x7C00

start:
    xor ax, ax
    mov ds, ax
    mov dl, [bootdrv]

    mov ah, 0x02
    mov al, 4
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov bx, 0x7E00
    int 0x13

    jmp 0x0000:0x7E00

bootdrv: db 0
times 510-($-$$) db 0
dw 0xAA55
