BITS 16
ORG 0x7E00

; ----------------------------
; Общие соглашения
; SI = адрес строки
; AX = результат (если есть)
; Все регистры сохраняются
; ----------------------------
start:
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Запрос размера массивов
    mov si, ask_size_msg
    call print
    call readint
    mov [array_size], ax
    cmp ax, 0
    je .end
    cmp ax, 100
    ja .end

    ; Генерация массивов
    call generate_arrays

    ; Вывод массивов
    call print_arrays

    ; Вычисление и вывод результатов
    call calculate_and_print_results

.end:
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
    jz .done ; Если байт нулевой то конец строки
    mov ah, 0x0E ; ВЫводит символ al
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
    mov al, 13 ; Переводит курсор в начало строки
    mov ah, 0x0E
    int 0x10
    mov al, 10 ; Переводит курсор на строку вниз
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
; sleep(AX = миллисекунды)
; -----------------------------------------------------
sleep:
    push ax
    push bx
    push cx
    push dx

    mov bx, ax
    mov ax, 1000
    mul bx; перевод милисекунд в микросекунды

    mov cx, dx ; В dx:ax будет хранится время остановки в микросекундах
    mov dx, ax
    mov ah, 86h
    int 15h 

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
    push cx
    push dx
    push si
    push di

    mov si, input_buffer
    xor cx, cx

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
    mov byte [si], 0

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

    mov di, si
    xor cx, cx

    cmp bx, 0
    jne .check_neg
    mov byte [di], '0'
    inc di
    jmp .done

.check_neg:
    test bx, 0x8000
    jz .convert
    mov byte [di], '-'
    inc di
    neg bx

.convert:
    mov ax, bx

.next_digit:
    xor dx, dx
    mov bx, 10
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne .next_digit

.reverse:
    pop dx
    add dl, '0'
    mov [di], dl
    inc di
    loop .reverse

.done:
    mov byte [di], 0
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

num_buf times 8 db 0     ; буфер для числа (знак + 5 цифр + 0)
; -----------------------------------------------------
; readint → AX  (читает целое число из строки)
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
; ГПСЧ: мультипликативный генератор (Xorshift)
; Возвращает случайное число в AX (0..65535)
; -----------------------------------------------------
random:
    push bx
    push dx
    mov ax, [rng_seed]
    mov bx, ax
    shl ax, 7
    xor ax, bx
    mov bx, ax
    shr ax, 9
    xor ax, bx
    mov bx, ax
    shl ax, 8
    xor ax, bx
    mov [rng_seed], ax
    pop dx
    pop bx
    ret

; -----------------------------------------------------
; Генерация массивов A, B, D
; -----------------------------------------------------
generate_arrays:
    push ax
    push bx
    push cx
    push si
    push di

    mov cx, [array_size]
    mov si, array_a
    mov di, array_b
    mov bx, array_d

.loop:
    call random
    mov [si], ax
    add si, 2

    call random
    mov [di], ax
    add di, 2

    call random
    mov [bx], ax
    add bx, 2

    loop .loop

    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; -----------------------------------------------------
; Вывод массивов на экран
; -----------------------------------------------------
print_arrays:
    push ax
    push bx
    push cx
    push si
    push di

    mov si, array_a_msg
    call println

    mov cx, [array_size]
    mov si, array_a
    call print_array

    mov si, array_b_msg
    call println

    mov cx, [array_size]
    mov si, array_b
    call print_array

    mov si, array_d_msg
    call println

    mov cx, [array_size]
    mov si, array_d
    call print_array

    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; -----------------------------------------------------
; Вывод массива: CX = размер, SI = адрес массива
; -----------------------------------------------------
print_array:
    push ax
    push bx
    push cx
    push si
    push di

.loop:
    mov ax, [si]
    mov bx, ax
    mov di, num_buf
    push si
    mov si, di
    call itoa
    call print
    pop si

    mov al, ' '
    mov ah, 0x0E
    int 0x10

    add si, 2
    loop .loop

    call println

    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; -----------------------------------------------------
; Вычисление и вывод результатов
; -----------------------------------------------------
calculate_and_print_results:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, results_msg
    call println

    mov cx, [array_size]
    mov si, array_a
    mov di, array_b
    mov bx, array_d

.loop:
    push cx
    push si
    push di
    push bx

    mov ax, [si]
    mov cx, [di]
    mov dx, [bx]

    ; Вычисление формулы: (A+3)/(B+3) - (D+3)/(A+3)
    call calculate_formula

    ; Вывод результата
    mov bx, ax
    mov si, num_buf
    call itoa
    call print

    mov al, ' '
    mov ah, 0x0E
    int 0x10

    pop bx
    pop di
    pop si
    pop cx

    add si, 2
    add di, 2
    add bx, 2

    loop .loop

    call println

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; -----------------------------------------------------
; Вычисление формулы: (A+3)/(B+3) - (D+3)/(A+3)
; AX = A, CX = B, DX = D
; Результат в AX
; -----------------------------------------------------
calculate_formula:
    push bx
    push cx
    push dx
    push si

    ; Сохраняем исходные значения
    mov si, ax
    mov bx, cx

    ; Вычисляем (A+3)/(B+3)
    mov ax, si
    add ax, 3
    mov cx, bx
    add cx, 3
    cmp cx, 0
    je .div_zero1
    call signed_div
    push ax
    jmp .second_part

.div_zero1:
    push word 0

.second_part:
    ; Вычисляем (D+3)/(A+3)
    mov ax, dx
    add ax, 3
    mov cx, si
    add cx, 3
    cmp cx, 0
    je .div_zero2
    call signed_div
    mov dx, ax
    jmp .subtract

.div_zero2:
    mov dx, 0

.subtract:
    ; Результат: (A+3)/(B+3) - (D+3)/(A+3)
    pop ax
    sub ax, dx

    pop si
    pop dx
    pop cx
    pop bx
    ret

; -----------------------------------------------------
; Деление со знаком: AX / CX → AX
; -----------------------------------------------------
signed_div:
    push bx
    push dx
    push si

    mov si, ax
    mov bx, cx

    ; Проверка знаков
    test si, 0x8000
    jnz .neg_dividend
    test bx, 0x8000
    jnz .neg_divisor

    ; Оба положительные
    mov ax, si
    xor dx, dx
    div bx
    jmp .done

.neg_dividend:
    test bx, 0x8000
    jnz .both_neg

    ; Делимое отрицательное, делитель положительный
    neg si
    mov ax, si
    xor dx, dx
    div bx
    neg ax
    jmp .done

.neg_divisor:
    ; Делимое положительное, делитель отрицательный
    neg bx
    mov ax, si
    xor dx, dx
    div bx
    neg ax
    jmp .done

.both_neg:
    ; Оба отрицательные
    neg si
    neg bx
    mov ax, si
    xor dx, dx
    div bx
    jmp .done

.done:
    pop si
    pop dx
    pop bx
    ret

; -----------------------------------------------------
; Данные
; -----------------------------------------------------
ask_size_msg db "Enter array size (1-100): ", 0
array_a_msg db "Array A: ", 0
array_b_msg db "Array B: ", 0
array_d_msg db "Array D: ", 0
results_msg db "Results: ", 0

array_size dw 0
rng_seed dw 12345

array_a times 200 dw 0
array_b times 200 dw 0
array_d times 200 dw 0

input_buffer times 256 db 0
