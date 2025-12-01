BITS 16
ORG 0x7C00

start:
    xor ax, ax
    mov ds, ax; номер сегмента
    mov dl, 0 ; откуда идет бут

    mov ah, 0x02 ; режим чтения
    mov al, 4 ; размер сектора в 512 байт
    mov ch, 0
    mov cl, 2 ; номер сектора
    mov dh, 0
    mov bx, 0x7E00 ; куда записать второй сектор
    int 0x13

    jmp 0x0000:0x7E00 ; переход к второму сектору

times 510-($-$$) db 0 ;Заполняем сектор до 512 байт
dw 0xAA55
