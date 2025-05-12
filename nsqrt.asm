global nsqrt

%macro CALC_BLOCK 5
    ; %1 = pointer to Q 
    ; %2 = index of calculated block (i)
    ; %3 = how many bits to shift (0 ≤ shift < 64)
    ; %4 = total block count (n)
    ; %5 = output register
    ; this macro uses rax, rcx, rdx (caller must preserve if needed)

    cmp %2, %4
    je %%only_prev                  ; if i == n then only Q[i - 1]

    mov %5, [%1 + 8*%2]             ; r = Q[i]
    jmp %%shift

%%only_prev:
    xor %5, %5                      ; r = 0 (Q[i] = 0)

%%shift:
    test %3, %3
    jz %%done                       ; if shift == 0, skip rest

    mov     rax, %5                 ; rax = Q[i] or 0
    mov     cl, %3b           
    shl     rax, cl                 ; rax = Q[i] << shift

    cmp     %2, 0
    je      %%no_prev               ; if i == 0 -> no Q[i - 1]

    mov     rcx, [%1 + 8*%2 - 8]    ; rcx = Q[i - 1]
    mov     rdx, 64
    sub     rdx, %3
    mov     cl, dl                  ; cl = (64 - shift)
    shr     rcx, cl                 ; rcx >> (64 - shift)

    or      rax, rcx                ; get final value 
    mov     %5, rax
    jmp     %%done

%%no_prev:
    mov     %5, rax                 ; just use shifted Q[i] (Q[i - 1] = 0)

%%done:
%endmacro

%macro SET_BIT 4
    ; %1 = output pointer
    ; %2 = bit index
    ; %3 = total bits
    ; %4 = bit value (0 or 1), must be in a register
    ; temp register (clobbers: rax, rcx, rdx, rdi)

    mov     rax, %3            ; rax = n
    sub     rax, %2            ; rax = n - i
    mov     rcx, rax           ; rcx = bit index in block

    shr     rax, 6             ; rax = block index
    and     rcx, BLOCK_MODULO  ; rcx = bit position in block (0–63)

    mov     rdi, 1
    shl     rdi, cl            ; rdi = 1 << bit_index

    mov     rdx, [%1 + rax*8]  ; load target Q[block_index]

    test    %4, %4
    jz      %%clear_bit

    or      rdx, rdi           ; set the bit
    jmp     %%store

%%clear_bit:
    not     rdi
    and     rdx, rdi           ; clear the bit

%%store:
    mov     [%1 + rax*8], rdx  ; store updated block
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
    test rax, rax         
    jz main_loop         ; if rax == 0 -> .main_loop
    jmp .substract

.main_set_ans_loop:
    ; set 2^{n - i}
    mov al, 1                       ; set bit to 1
    SET_BIT r13, r8, rbx, al        ; Q, i, totalBits, value, tempReg
    jmp .main_loop                  ; continue main loop

.compare 
    mov r11, r9             ; set j = BlockCount for compare_loop

    test r10, r10           ; check if r10 = 0
    setz al                 ; al = 1 if r10 = 0
    sub r11, al             ; j-- if r10 = 0
    
    ; handle some edge case where X[j + blockmove + 1] > 0
    ; not sure if it happens

    ; compute (idx) rax = j + block_move + 1
    lea   rax, [r11 + r9 + 1]   
    mov   rcx, r15
    shl   rcx, 1             ; rcx = 2 * block_count

    cmp   rax, rcx
    jae   .compare_loop      ; if rax >= totalWords, skip edge-check

    ; load X[idx]
    mov   rdx, [r14 + rax*BLOCK_SIZE]
    test  rdx, rdx
    jz    .compare_loop      ; if X[idx] == 0, no edge-case

    mov   rax, 1
    jmp   .main_check

.compare_loop:
    CALC_BLOCK r13, r11, r9, rbx, rax   ; use macro to calc j-th block

    mov rcx, r11            
    add rcx, r9                         ; rcx = j + block_move 
    
    mov rdi, [r14 + rcx * BLOCK_SIZE]   ; get X[j + block_move]
    sub rdi, rax                        ; X[j + block_move] - (j-th block)
    test rdi, rdi                       ; if result != 0 -> we have answer
    jnz .compare_exit

    test r11, r11
    jz .compare_exit                    ; if j == 0 finish
    dec r11                             ; j--
    jmp .compare_loop

.compare_exit:
    cmp     rdi, 0
    setae   al                         ; al = 1 if signed (X–v)>=0, else 0
    movzx   rax, al                    ; RAX = 0 or 1
    jmp .main_check

.substract:
    xor r11, r11                       ; j = 0
    clc                                ; CF = 0

.substract_loop_check: 
    jc .substract_loop                 ; if Cf = 1 -> loop again
    cmp r11, r15                       ; check j < n
    jl .substract_loop                 ; if j < n -> loop again
    jmp .exit_substract_loop

.substract_loop:
    CALC_BLOCK r13, r11, r9, rbx, rax  ; macro to get j-th block

    mov rcx, r11
    add rcx, r9                        ; rcx = j + block_move

    mov rdi, [r14 + rcx * BLOCK_SIZE]  ; get X[j + block_move]
    sbb rdi, rax                       ; X[j + block_move] - (j-th block)
    mov [r14 + rcx * BLOCK_SIZE], rdi  ; new value of X[j + block_move]

    inc r11                            ; j++
    jmp substract_loop_check           ; check conditions

.exit_substract_loop:
    jmp .main_set_ans_loop             

.exit
    ; get back to the old value of callee safe registers
    pop     r15
    pop     r14
    pop     r13
    pop     rbp
    pop     rbx
    ret

