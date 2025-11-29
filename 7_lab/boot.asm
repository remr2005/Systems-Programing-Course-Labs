BITS 16
ORG 0x7C00

start:
    xor ax, ax
    mov ds, ax
    mov es, ax

    mov dl, [bootdrv]        ; флешка/диск

    ; читаем 2-й сектор (stage2) → 0000:7E00
    mov ah, 0x02
    mov al, 4                ; читаем 4 сектора
    mov ch, 0                ; цилиндр
    mov cl, 2                ; сектор 2
    mov dh, 0                ; головка
    mov bx, 0x7E00
    int 0x13
    jc disk_error

    jmp 0x0000:0x7E00        ; переход к stage2

disk_error:
    mov si, msg_err
.print:
    lodsb
    or al, al
    jz $
    mov ah, 0x0E
    int 0x10
    jmp .print

bootdrv: db 0

msg_err db "Disk read error",0

times 510-($-$$) db 0
dw 0xAA55
