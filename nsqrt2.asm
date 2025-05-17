global nsqrt 
; void nsqrt(uint64_t *Q, uint64_t *X, uint64_t n)
; rdi = pointer to result 
; rsi = pointer to input value
; rdx number of bytes
; returns Q^2 <= X^2 <= (Q + 1)^2

; use of callee safe registers:
; rbx = n (number of bits)
; r13 = Q (pointer to Q)
; r14 = X (pointer to Q)
; r15 = block_count (n / 64)
nsqrt:
    push rbx
    push r13
    push r14
    push r15

    mov rbx, rdx            ; set n 
    shr rdx, 6              ; n / 64 (block_count)
    mov r15, rdx            ; set block_count
    mov r13, rdi            ; set Q pointer
    mov r14, rsi            ; set X pointer

    xor rax, rax            ; set rax = 0
    mov rdi, r13            ; set rdi = Q
    mov rcx, r15            ; set counter
    rep stosq               ; set the Q = 0

    xor r8, r8              ; i = 0
; MAIN LOOP
; r8 = i = 1 .. n
; r9 = (n - i + 1) / 64 (block_move)
; rcx = (n - i + 1) % 64 (block_offset)
; r12 = (n - i + 1)
.main_loop:
    lea r12, [rbx - r8 + 1]     ; r12 = n - i + 1

    mov r9, r12
    shr r9, 6                   ; set r9 = (n - i + 1) / 64

    mov rcx, r12
    and rcx, 63                 ; set rcx = (n - i + 1) % 64

    inc r8                      ; i++

    cmp rbx, r8                 ; check i == n
    je .compare                 ; if i == n -> compare (edge case)
    
    lea r11, [r12 - 2]          ; r11 = n - i - 1
    mov rax, r11
    shr rax, 6                  ; rax = index = (n - i - 1) / 64

    mov r10, r11
    and r10, 63                 ; r10 = bit_in_block = (n - i - 1) % 64

    bts qword [r13 + rax*8], r10; set 2^{n - i - 1} 
    jmp .compare

.compare:
; r11 = j (block_count -> 0)
; rax = Q[i]
; rdx = Q[i - 1]
    mov r11, r15                ; j = block_count 
    xor rax, rax                ; set first = 0 = rax (there is no Q[block_count])

    lea rdx, [r11 - 1]          ; rxd = j - 1
    mov rcx, [r13 + rdx*8]      ; set second = Q[block_count - 1] = rcx



    
.exit:
    pop rbx
    pop r13
    pop r14
    pop r15
    ret 
