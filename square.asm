global nsqrt

%macro CALC_BLOCK 5
    ; %1 = pointer to Q 
    ; %2 = index of calculated block (i)
    ; %3 = how many bits to shift (0 ≤ shift < 64)
    ; %4 = total block count (n)
    ; %5 = output register
    ; this macro uses rax, rcx, rdx (caller must preserve if needed)

    cmp %2, %4
    je %%only_prev              ; if i == n then only Q[i - 1]

    mov %5, [%1 + 8*%2]         ; r = Q[i]
    jmp %%shift

%%only_prev:
    xor %5, %5                  ; r = 0 (Q[i] = 0)

%%shift:
    test %3, %3
    jz %%done                   ; if shift == 0, skip rest

    mov     rax, %5             ; rax = Q[i] or 0
    mov     cl, %3b           
    shl     rax, cl             ; rax = Q[i] << shift

    cmp     %2, 0
    je      %%no_prev           ; if i == 0 -> no Q[i - 1]

    mov     rcx, [%1 + 8*%2 - 8]    ; rcx = Q[i - 1]
    mov     rdx, 64
    sub     rdx, %3
    mov     cl, dl              ; cl = (64 - shift)
    shr     rcx, cl             ; rcx >> (64 - shift)

    or      rax, rcx            ; get final value 
    mov     %5, rax
    jmp     %%done

%%no_prev:
    mov     %5, rax             ; just use shifted Q[i] (Q[i - 1] = 0)

%%done:
%endmacro

section .rodata

BLOCK_MODULO equ 63  ; value to get modulo of 64
BLOCK_SIZE equ 8     ; size of block 

section .text

; void get_zero(uint64_t *Q, uint64_t blockCount)
; rdi = Q, esi = blockCount
; sets all 64-bit blocks to zero 
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
; use of callee safe registers:
; rbx = n (number of bits)
; r13 = Q (pointer to Q)
; r14 = X (pointer to Q)
; r15 = block_count (n / 64)
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

    mov r8, 0               ; set r8 = i = 0 for .main_loop

.main_loop:
    mov r9, rbx             ; get n
    sub r9, r8              ; get (n - i + 1)
    shr r9, 8               ; set r9 to shift of T_{i - 1} / BLOCK_SIZE

    mov r10, rbx            ; get n
    sub r10, r8             ; get (n - i + 1)
    and r10, BLOCK_MODULO   ; set r10 to shift of T_{i - 1} % BLOCK_SIZE

    inc r8                  ; i++
    cmp r8, rbx             ; check i > n
    jg .exit                ; if true exit loop

    jmp .compare            ; compare T_{i - 1} and R_{i - 1}
.main_check:

.compare 
    mov r11, r9             ; set j = BlockCount for compare_loop
    add r11, r9             ; add block_move

    test r10, r10           ; check if r10 = 0
    setz al                 ; al = 1 if r10 = 0
    sub r11, al             ; j-- if r10 = 0

.compare_loop:
    CALC_BLOCK r13, r11, r9, rbx, rax   ; use macro to calc j-th block

    mov rcx, r11            
    add rcx, r9             ;

.compare_check:

.compare_exit:    
.substract

.exit
    ; get back to the old value of callee safe registers
    pop     r15
    pop     r14
    pop     r13
    pop     rbp
    pop     rbx
    ret

