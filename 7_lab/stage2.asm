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

    mov si, len_msg
    call print
    call strlen

    mov bx, ax          ; сохраняем результат strlen
    lea si, num_buf     ; адрес буфера для числа
    call itoa
    call println

    mov si, sleep_msg
    call println
    mov ax, 3000
    call sleep
    
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
; sleep(AX = миллисекунды)   BIOS таймер
; -----------------------------------------------------
sleep:
    push ax
    push bx
    push cx
    push dx

    ; AX = миллисекунды → переводим в микросекунды
    ; 1 ms = 1000 us
    mov bx, ax           ; BX = миллисекунды
    mov ax, 1000
    mul bx               ; DX:AX = AX*BX = миллисекунды * 1000
                         ; DX:AX теперь в микросекундах

    ; Теперь DX:AX = количество микросекунд
    ; BIOS ожидает CX:DX, где DX = младшие 16 бит, CX = старшие 16 бит
    mov dx, ax           ; младшие 16 бит
    mov cx, dx           ; старшие 16 бит
    xor cx, cx           ; на всякий случай старшие = 0 для <65 секунд
    mov ah, 0x86
    int 0x15

    pop dx
    pop cx
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
; itoa: BX = число, SI = адрес буфера, возвращает строку ASCII
; -----------------------------------------------------
itoa:
    push ax
    push bx
    push cx
    push dx
    push di

    mov di, si          ; DI = текущий адрес буфера
    xor cx, cx          ; счетчик цифр

    cmp bx, 0
    jne .convert
    mov byte [di], '0'
    inc di
    jmp .done

.convert:
    mov ax, bx

.next_digit:
    xor dx, dx
    mov bx, 10
    div bx              ; AX / 10 → AX = quot, DX = rem
    push dx             ; сохраняем остаток (цифру)
    inc cx
    mov ax, ax
    cmp ax, 0
    jne .next_digit

.reverse:
    pop dx
    add dl, '0'         ; цифра -> ASCII
    mov [di], dl
    inc di
    loop .reverse

.done:
    mov byte [di], 0    ; завершение строки 0
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

num_buf times 6 db 0     ; буфер для числа (макс 5 цифр + 0)


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
hello_msg1 db "Boot OK. ",0
hello_msg2 db "Stage2 Loaded",0
sleep_msg db "Sleep 3000ms.",0
len_msg db "Len of current row is: ",0
input_buffer times 256 db 0
