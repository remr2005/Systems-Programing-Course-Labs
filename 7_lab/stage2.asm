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

    ; Таймер
    mov si, sleep_msg
    call println
    mov ax, 3000
    call sleep

    ; Ввод строки
    mov si, ask_string
    call print
    call readline
    mov si, string_result
    call print
    mov si, input_buffer
    call println
    
    ;Ввод числа
    mov si, ask_int
    call print
    call readint          ; → AX = число
    mov bx, ax            ; BX = AX для itoa
    lea si, num_buf
    call itoa

    mov si, int_result
    call print
    mov si, num_buf
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
; readline: читает строку в input_buffer (макс 255)
; Вход: нет (использует глобальный input_buffer)
; Выход: input_buffer содержит нуль-терминированную строку
; Сохраняет регистры: AX,BX,CX,DX,SI,DI

readline:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, input_buffer   ; DS:SI -> куда писать
    xor cx, cx             ; длина = 0

.read_loop:
    mov ah, 0x00
    int 0x16               ; BIOS: ждем клавишу, AL = ASCII

    cmp al, 13             ; Enter?
    je .done

    cmp al, 8              ; Backspace?
    je .backspace

    cmp cx, 255
    jae .read_loop         ; переполнение буфера — игнорируем ввод

    mov [si], al
    inc si
    inc cx

    ; эхо: INT 10h AH=0Eh (teletype). BH=page(0), BL=color(7)
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    jmp .read_loop

.backspace:
    cmp cx, 0
    je .read_loop
    dec si
    dec cx
    ; вывести BS ' ' BS
    mov ah, 0x0E
    mov al, 8
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .read_loop

.done:
    mov byte [si], 0       ; нуль-терминатор

    ; вывести CR LF
    mov ah, 0x0E
    mov al, 13
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    mov al, 10
    int 0x10

    pop di
    pop si
    pop dx
    pop cx
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
; -----------------------------------------------------
; readint -> AX
; Читает строку (через readline) и парсит десятичное число.
; Возвращает 16-bit результат в AX.
; Сохраняет регистры: BX,CX,DX,SI (и т.д.)
; -----------------------------------------------------
readint:
    push bx
    push cx
    push dx
    push si

    call readline         ; заполняет input_buffer
    mov si, input_buffer  ; указатель на начало буфера
    xor ax, ax            ; результат = 0

.parse_loop:
    mov dl, [si]          ; прочитать байт в DL (не портим AX)
    inc si
    or dl, dl
    jz .parse_done        ; конец строки

    cmp dl, '0'
    jb .parse_done
    cmp dl, '9'
    ja .parse_done

    sub dl, '0'           ; dl = цифра 0..9

    ; ax = ax * 10
    mov bx, ax
    shl bx, 3             ; bx = ax * 8
    shl ax, 1             ; ax = ax * 2
    add ax, bx            ; ax = ax*2 + ax*8 = ax*10

    ; ax += dl (цифра)
    mov bx, 0
    mov bl, dl
    add ax, bx

    jmp .parse_loop

.parse_done:
    pop si
    pop dx
    pop cx
    pop bx
    ret


; -----------------------------------------------------
; Данные
; -----------------------------------------------------
hello_msg1 db "Boot OK. ",0
hello_msg2 db "Stage2 Loaded",0
sleep_msg db "Sleep 3000ms.",0
len_msg db "Len of current row is: ",0

ask_string db "Enter the string: ", 0
string_result db "You entered string: ", 0

ask_int     db "Enter number: ",0
int_result  db "You entered number: ",0

input_buffer times 256 db 0
