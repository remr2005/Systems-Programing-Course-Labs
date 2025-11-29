BITS 16
ORG 0x7E00

; ----------------------------
; Общие соглашения
; SI = адрес строки
; AX = результат (если есть)
; Все регистры сохраняются
; ----------------------------

start:
    mov ah, 0x00    ; функция BIOS: установить видеорежим
    mov al, 0x03    ; 80x25 текстовый режим, цветной
    int 0x10

    mov si, hello_msg
    call println

    mov ax, 3000
    call sleep
    call sleep
    call sleep
    call sleep
    mov si, sleep_msg
    call println
    jmp $

; -----------------------------------------------------
; print(SI = строка)
; -----------------------------------------------------
print:
    push ax
    push si
.next:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .next
.done:
    pop si
    pop ax
    ret

; -----------------------------------------------------
; println(SI = строка)
; -----------------------------------------------------
println:
    call print
    push ax
    mov al, 13
    mov ah, 0x0E
    int 0x10
    mov al, 10
    mov ah, 0x0E
    int 0x10
    pop ax
    ret

; -----------------------------------------------------
; strlen(SI = строка) → AX
; -----------------------------------------------------
strlen:
    push si
    xor cx, cx
.len:
    lodsb
    or al, al
    jz .end
    inc cx
    jmp .len
.end:
    mov ax, cx
    pop si
    ret

; -----------------------------------------------------
; sleep(AX = миллисек)   BIOS таймер
; -----------------------------------------------------
sleep:
    push ax
    push bx
    mov bx, ax
    mov ah, 0x86
    mov cx, 0
    mov dx, bx
    int 0x15
    pop bx
    pop ax
    ret

; -----------------------------------------------------
; readline → строка в input_buffer (макс 255)
; -----------------------------------------------------
readline:
    push ax
    push bx
    push si

    mov si, input_buffer
    xor cx, cx

.get:
    mov ah, 0
    int 0x16
    cmp al, 13
    je .done
    stosb
    inc cx
    jmp .get

.done:
    mov al, 0
    stosb
    pop si
    pop bx
    pop ax
    ret

; -----------------------------------------------------
; readint → AX  (читает целое число из строки)
; -----------------------------------------------------
readint:
    call readline
    mov si, input_buffer
    xor ax, ax            ; ax = результат = 0

.parse:
    lodsb
    or al, al
    jz .finish            ; 0 → конец строки

    cmp al, '0'
    jb .finish
    cmp al, '9'
    ja .finish

    sub al, '0'           ; теперь al = цифра 0..9

    ; ax = ax * 10
    mov bx, ax
    shl ax, 1             ; ax = ax * 2
    shl ax, 1             ; ax = ax * 4
    add ax, bx            ; ax = ax * 5
    add ax, bx            ; ax = ax * 10

    ; ax += цифра (al)
    mov bl, al            ; расширить 8-бит в 16-бит
    xor bh, bh
    add ax, bx

    jmp .parse

.finish:
    ret

; -----------------------------------------------------
; Данные
; -----------------------------------------------------
hello_msg db "Boot OK. Stage2 Loaded",0
sleep_msg db "Sleep 3000ms.",0
input_buffer times 256 db 0
