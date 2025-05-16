global nsqrt

%macro CALC_BLOCK 6
    ; %1 = pointer to Q 
    ; %2 = index of calculated block (i)
    ; %3 = how many bits to shift (0 <= shift < 64)
    ; %4 = total block count (n)
    ; %5 = output register
    ; %6 = j from 2^{n - j + 1} (for edge case)
    ; this macro uses rax, rcx, rdx, rdi (caller must preserve if needed)

    cmp %2, %4
    je %%only_prev                  ; if i == n then only Q[i - 1]

    mov %5, [%1 + 8*%2]             ; r = Q[i]
    jmp %%shift

%%only_prev:
    xor %5, %5                      ; r = 0 (Q[i] = 0)

%%shift:
    test %3, %3
    jz %%done                       ; if shift == 0, skip rest

    mov rax, %5                     ; rax = Q[i] or 0
    mov rcx, %3                     ; rcx = shift 
    shl rax, cl                     ; rax = Q[i] << shift

    cmp %2, 0
    je %%no_prev                    ; if i == 0 -> no Q[i - 1]

    mov rdi, [%1 + 8*%2 - 8]        ; rdi = Q[i - 1]
    mov rdx, 64
    sub rdx, %3
    mov cl, dl                      ; cl = (64 - shift)
    shr rdi, cl                     ; rdi >> (64 - shift)

    or  rax, rdi                    ; get final value 
    mov %5, rax           
    jmp %%done

%%no_prev:
    mov %5, rax                     ; just use shifted Q[i] (Q[i - 1] = 0)
    cmp %6, %4                      ; if j == n &&i == 0 we have edge case
    jne %%done
    inc %5                          ; final block++          

%%done:
%endmacro

%macro SET_BIT 4
    ; %1 = output pointer
    ; %2 = bit index
    ; %3 = total bits
    ; %4 = bit value (0 or 1), must be in a register
    ; temp register (clobbers: rsi, rcx, rdx, rdi)

    mov rsi, %3            ; rsi = n
    sub rsi, %2            ; rsi = n - i
    mov rcx, rsi           ; rcx = bit index in block

    shr rsi, 6             ; rsi = block index (n - i)/64
    and rcx, BLOCK_MODULO  ; rcx = bit_position in block (0–63) (n - i) % 64

    mov rdi, 1
    shl rdi, cl            ; rdi = 1 << bit_position

    mov rdx, [%1 + rsi*8]  ; load target Q[block_index]

    test %4, %4
    jz %%clear_bit

    or rdx, rdi           ; set the bit
    jmp %%store

%%clear_bit:
    not rdi
    and rdx, rdi           ; clear the bit

%%store:
    mov [%1 + rsi*8], rdx  ; store updated block
%endmacro

section .rodata

BLOCK_MODULO equ 63  ; value to get modulo of 64
BLOCK_SIZE equ 8     ; size of block 

section .text

; void get_zero(uint64_t *Q, uint64_t blockCount)
; rdi = Q, rsi = blockCount
; sets all 64-bit blocks to zero 
get_zero:
    xor rcx, rcx                        ; rcx = i = 0
.loop:
    cmp rcx, rsi                        ; i < blockCount
    jge .exit                           ; exit loop 
    mov qword [rdi + rcx*8], 0          ; get the i-th block
    inc rcx                             ; i++
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
    push    r13
    push    r14
    push    r15

    ; set arguments for callee safe registers
    mov rbx, rdx            ; set n 
    mov r13, rdi            ; set pointer to Q 
    mov r14, rsi            ; set pointer to X

    ; set arguments for call_zero
    mov rax, rdx            ; rax = n (bytes)
    shr rax, 6              ; divide by 64 → 64-bit block count
    mov rsi, rax            ; rsi = block count for get_zero

    mov r15, rsi            ; set block count
    
    sub rsp, 8              ; align stack to 16 bytes before call
    call get_zero           ; rdi = Q, rsi = block count
    add rsp, 8              ; restore alignment

    mov r8, 0               ; set r8 = i = 0 for .main_loop

.main_loop:
    mov r9, rbx             ; get n
    sub r9, r8              ; get (n - i + 1)
    shr r9, 6               ; set r9 to shift of T_{i - 1} / BLOCK_SIZE (block_move)

    mov r10, rbx            ; get n
    sub r10, r8             ; get (n - i + 1)
    and r10, BLOCK_MODULO   ; set r10 to shift of T_{i - 1} % BLOCK_SIZE

    inc r8                  ; i++

    mov r11, r8             ; r11 = r8 = i
    cmp r8, rbx             ; check i == n          
    je .compare             ; if i == n -> compare (edge case)
    inc r11                 ; r11++ = i++ 
    mov al, 1 
    ;set 2^{n - i - 1} (4^n after moving)            
    SET_BIT r13, r11, rbx, al

    jmp .compare            ; compare T_{i - 1} and R_{i - 1}
    
.main_check:
    test rax, rax         
    jz .main_finish         ; if rax == 0 -> .main_finish
    jmp .substract

.main_set_ans:
    ; set 2^{n - i}
    mov al, 1                       ; set bit to 1
    SET_BIT r13, r8, rbx, al        ; Q, i, totalBits, value
    jmp .main_finish                ; exit 

.main_finish:
    cmp r8, rbx          
    je .exit                        ; if i == n -> we can finish
    mov r11, r8                     ; r11 = r8 = i 
    inc r11
    mov al, 0                       ; set bit to zero

    ;unset set 2^{n - i - 1} (4^n after moving)            
    SET_BIT r13, r11, rbx, al
    jmp .main_loop
.compare: 
    mov r11, r15            ; set r11 = j = BlockCount for compare_loop

    test r10, r10           ; check if r10 = 0
    setz al                 ; al = 1 if r10 = 0
    movzx rax, al           ; zero-extend al to rax (or use mov rax, al if you're sure al is 0 or 1)
    sub r11, rax            ; subtract 1 or 0 from r11
    
    ; handle some edge case where X[j + blockmove + 1] > 0
    ; not sure if it happens

    ; compute (idx) rax = j + block_move + 1
    lea   rax, [r11 + r9 + 1]   
    mov   rcx, r15           ; get block_count
    shl   rcx, 1             ; rcx = 2 * block_count = totalWords

    cmp   rax, rcx
    jae   .compare_loop      ; if rax >= totalWords, skip edge-check

    ; load X[idx]
    mov   rdx, [r14 + rax*BLOCK_SIZE]
    test  rdx, rdx
    jz    .compare_loop      ; if X[idx] == 0, no edge-case

    mov   rax, 1             ; else X[idx] > 0 , we have answer
    jmp   .main_check

.compare_loop:
    ; use macro to calc j-th block
    CALC_BLOCK r13, r11, r10, rbx, rax, r8 

    mov rcx, r11            
    add rcx, r9                         ; rcx = j + block_move 
    
    mov rdi, [r14 + rcx * BLOCK_SIZE]   ; get X[j + block_move]
    sub rdi, rax                        ; X[j + block_move] - (j-th block)
    jc .compare_exit                    ; result < 0 we go to compare exit
    test rdi, rdi                       ; if result != 0 -> we have answer
    jnz .compare_exit

    test r11, r11
    jz .compare_exit                    ; if j == 0 finish
    dec r11                             ; j--
    jmp .compare_loop

.compare_exit:
    setae   al                         ; al = 1 if signed (X–v)>=0, else 0
    movzx   rax, al                    ; RAX = 0 or 1
    jmp .main_check

.substract:
    mov r12, r15                       ; r12 = block_count
    test r10, r10                      ; check if r10 = 0
    setz al                            ; al = 1 if r10 = 0
    movzx rax, al                      ; zero-extend al to rax (or use mov rax, al if you're sure al is 0 or 1)
    sub r12, rax                       ; subtract 1 or 0 from r11

    xor r11, r11                       ; j = 0
    clc                                ; CF = 0
                    

.substract_loop_check: 
    jc .substract_loop                 ; if Cf = 1 -> loop again
    cmp r15, r11                       ; check j != block_count
    jae .substract_loop                ; if block_count >= j -> loop again
    jmp .exit_substract_loop

.substract_loop:
    ; macro to get j-th block
    CALC_BLOCK r13, r11, r10, rbx, rax, r8 

    mov rcx, r11
    add rcx, r9                        ; rcx = j + block_move

    mov rdi, [r14 + rcx * BLOCK_SIZE]  ; get X[j + block_move]
    sbb rdi, rax                       ; X[j + block_move] - (j-th block) - flag
    mov [r14 + rcx * BLOCK_SIZE], rdi  ; new value of X[j + block_move]

    inc r11                            ; j++
    jmp .substract_loop_check          ; check conditions

.exit_substract_loop:
    jmp .main_set_ans             

.exit:
    ; get back to the old value of callee safe registers
    pop     r15
    pop     r14
    pop     r13
    pop     rbx
    ret

