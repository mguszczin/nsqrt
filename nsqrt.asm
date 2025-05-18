global nsqrt 

section .text
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
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdx            ; set n 
    shr rdx, 6              ; n / 64 (block_count)
    mov r15, rdx            ; set block_count
    mov r13, rdi            ; set Q pointer
    mov r14, rsi            ; set X pointer

    xor rax, rax            ; set rax = 0
    mov rcx, r15            ; set counter
    rep stosq               ; set the Q = 0 / rdi = Q

    xor r8, r8              ; i = 0
; MAIN LOOP
; r8 = i = 1 .. n
; r9 = (n - i + 1) / 64 (block_move)
; rcx = (n - i + 1) % 64 (block_offset)
; r12 = (n - i + 1)
.main_loop:
    mov r12, rbx                
    sub r12, r8                 ; r12 = n - i + 1

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

.compare:
; r11 = j (block_count -> 0)
; rax = Q[j]    (first)
; rdx = Q[j - 1](second)
; r10 = max_index
    mov r11, r15                ; j = block_count 
    mov rdx, 0                  ; set second = 0 

    ; handle some edge case where X[j + blockmove + 1] > 0
    lea r10, [r15 * 2]          ; r10 = max_index = block_count * 2
    lea rdi, [r11 + r9 + 1]     ; rdi = j + blockmove + 1 = idx

    ; if(j + blockmove + 1 >= max_index) -> compare_calculate_offset
    cmp rdi, r10               
    jae .compare_calculate_offset

    ; if we are in bounds
    cmp qword[r14 + rdi*8], 0        ; check X[idx] > 0
    jnz .compare_check          ; if (X[idx] > 0) -> .compare_check
.compare_calculate_offset:
    mov rax, rdx                ; first = second

    cmp r11, 0                  ; check j == 0
    je .compare_no_prev         ; if j == 0 -> compare_no_prev

    mov rdx, [r13 + r11 * 8 - 8];second = Q[j - 1]
    shld rax, rdx, cl          ;Calculate offset Q[i] and Q[i - 1]
    jmp .compare_X_and_Q        

.compare_no_prev:
    shl rax, cl                ; Calculate offset for single elem

    cmp r12, 1                  ; check n - i + 1 == 1 (edge case)
    jne .compare_X_and_Q        ; if (!check) -> compare
    inc rax                     ; else first++
.compare_X_and_Q:
    lea rdi, [r11 + r9]         ; rdi = j + block_move 
    cmp rdi, r10                ; if (j + block_move == max_index) -> compare_check
    je .compare_check
    cmp qword[r14 + rdi*8], rax      ; compare X[j + block_move], new_block
.compare_check:
    jc .main_exit               ; if X smaller we can stop merging
    ja .subtract                ; if X bigger we can start subtracting

    cmp r11, 0                
    je .subtract                ; if j == 0 -> subtract
    dec r11                     ; else j-- and continue loop

    jmp .compare_calculate_offset
.subtract:
; r10 = block_count - [rcx == 0]
; r11 = j (from 0 -> max | CF = 1)
; rax = Q[j]    (first)
; rdx = Q[j - 1](second)
; rsi = store cf value 
    mov r10, r15                ; r10 = block_count
    xor rax, rax                ; clear RAX
    test rcx, RCX               ; set zero flag
    setz al                     ; AL = 1 if RCX == 0
    sub r10, rax                ; r10 = block_count - [rcx == 0]
    
    xor r11, r11                ; set j = 0
    xor rax, rax                ; first = 0
    xor rsi, rsi                ; rsi = 0 (CF equal to zero)

.calc_first_and_second:
    mov rdx, rax                ; second = first 
    xor rax, rax                ; first = 0

    cmp r11, r15                ; check j >= block_count 
    jae .calc_block             ; if (j >= block_count) -> subtract_block

    mov rax, [r13 + r11*8]      ; first = Q[j]
.calc_block:
    mov rdi, rax                ; set temp first block
    shld rdi, rdx, cl           ; calc block to be substracted

    ; solve edge case
    test r11, r11                ; check j == 0
    jnz .subtract_blocks         

    cmp r12, 1                   ; check n - i + 1 == 1 (edge case)
    jne .subtract_blocks         

    inc rdi                      ; if n - i + 1 == 1 && j == 0 -> Q[j]++ 
.subtract_blocks:
    bt rsi, 0                    ; CF <- (SIL >> 0) & 1
    lea rdx, [r11 + r9]           ; set temp j + block_move
    ; X[j + block_move] - calculated_block
    sbb [r14 + rdx * 8], rdi
    setc sil                     ; remember CF value 
.subtract_check:
    inc r11                     ; j++
    jc .calc_first_and_second   ; CF = 1 repeat

    cmp r10, r11              
    jae .calc_first_and_second  ; if(max >= j) -> loop again
.bit_set:
    lea r11, [r12 - 1]          ; r11 = n - i
    mov rax, r11
    shr rax, 6                  ; rax = index = (n - i) / 64

    mov r10, r11
    and r10, 63                 ; r10 = bit_in_block = (n - i) % 64

    bts qword [r13 + rax*8], r10; set 2^{n - i} 

.main_exit:
    cmp r8, rbx                 ; if i == n exit
    je .exit
    
    lea r11, [r12 - 2]          ; r11 = n - i - 1
    mov rax, r11
    shr rax, 6                  ; rax = index = (n - i - 1) / 64

    mov r10, r11
    and r10, 63                 ; r10 = bit_in_block = (n - i - 1) % 64

    btr qword [r13 + rax*8], r10; unset 2^{n - i - 1} 
    jmp .main_loop
.exit:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret 
