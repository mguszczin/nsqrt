global nsqrt

section .rodata

BLOCK_MODULO equ 63  ; value to get modulo of 64
BLOCK_SIZE equ 8     ; size of block 


section .text

; void get_zero(uint64_t *Q, uint64_t blockCount)
; rdi = Q, rsi = blockCount
get_zero:
    xor ecx, ecx             ; ecx = i = 0
.loop:
    cmp rcx, rsi             ; i < blockCount?
    jge .exit
    mov qword [rdi + rcx*8], 0
    inc rcx
    jmp .loop
.exit:
    ret


; void nsqrt(uint64_t *Q, uint64_t *X, uint64_t n)
; rdi = pointer to result 
; rsi = pointer to input value
; rdx number of bytes
nsqrt:
    push rsi                ; save rsi (holds pointer to X)

    mov rax, rdx            ; rax = n (bytes)
    shr rax, 3              ; divide by 8 → 64-bit block count
    mov rsi, rax            ; rsi = block count for get_zero

    sub rsp, 8              ; align stack to 16 bytes
    call get_zero           ; rdi = Q, rsi = block count
    add rsp, 8              ; restore stack

    pop rsi                 ; restore original rsi (X pointer)
    
