global nsqrt

section .rodata

BLOCK_MODULO equ 63  ; value to get modulo of 64
BLOCK_SIZE equ 8     ; size of block 

section .text

; void get_zero(uint64_t *Q, uint64_t blockCount)
; rdi = Q, esi = blockCount
get_zero:
    xor ecx, ecx                        ; ecx = i = 0
.loop:
    cmp ecx, esi                        ; i < blockCount
    jge .exit                           ; exit loop 
    mov qword [rdi + ecx*BLOCK_SIZE], 0 ; get the i-th block
    inc ecx                             ; i++
    jmp .loop                           ; get back
.exit:
    ret        

; void nsqrt(uint64_t *Q, uint64_t *X, uint64_t n)
; rdi = pointer to result 
; rsi = pointer to input value
; rdx number of bytes
; returns Q^2 <= X^2 <= (Q + 1)^2
nsqrt:
    ; push all the callee safe registers on stack
    push    rbx
    push    rbp
    push    r13
    push    r14
    push    r15

    ; set arguments for callee safe registers
    mov rbx, rdx            ; set n 
    mov r13, rdi            ; set pointer to Q 
    mov r14, rsi            ; set pointer to X

    ; set arguments for call_zero
    mov rax, rdx            ; rax = n (bytes)
    shr rax, 3              ; divide by 8 → 64-bit block count
    mov rsi, rax            ; rsi = block count for get_zero

    mov r15, rsi            ; set block count
    
    sub rsp, 8              ; align stack to 16 bytes before call
    call get_zero           ; rdi = Q, rsi = block count
    add rsp, 8              ; restore alignment

    mov r8, 0               ; set i = 0 for .main_loop

.main_loop:
    mov r9, rbx             ; get n
    sub r9, r8              ; get (n - j + 1)
    shr r9, 8               ; set r9 to shift of T_{i - 1} / BLOCK_SIZE

    mov r10, rbx            ; get n
    sub r10, r8             ; get (n - j + 1)
    and r10, BLOCK_MODULO   ; set r10 to shift of T_{i - 1} % BLOCK_SIZE

    inc r8                  ; i++
    cmp rbx, r8             ; check i > n
    jg .exit                ; if true exit loop

    jmp .compare

.compare 

.exit
    ; get back to the old value of callee safe registers
    pop     r15
    pop     r14
    pop     r13
    pop     rbp
    pop     rbx
    ret

