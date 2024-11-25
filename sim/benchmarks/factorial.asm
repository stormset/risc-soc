.text
.global main
        addui r30, r0, 0x00004000   ; setup stack pointer

        addi r1, r0, 4              ; compute factorial of 4 (result will be in r2)
        jal factorial               ; call the factorial function
end_program:          
        j end_program               ; infinite loop (halt)

factorial:          
        addi r3, r0, 1              ; identity element of multiplication (1)
        beqz r1, base_case          ; if n == 0, return 1 (base case)

        sw 0(r30), r31              ; push return address onto the stack
        sw 4(r30), r1               ; push n onto the stack
        addui r30, r30, 8           ; adjust stack pointer
        addi r1, r1, -1             ; decrement n
        jal factorial               ; recursive call
        lw r1, -4(r30)              ; restore n from the stack
        mult r2, r2, r1             ; multiply result of (n-1)! with n
        addi r30, r30,-8            ; adjust stack pointer back
        lw r31, 0(r30)              ; restore return address
        jr r31                      ; return to caller

base_case:          
        add r2, r0, r3              ; set result to 1
        jr r31                      ; return to caller

.align 4                            ; ensure alignment for padding
.data
        .space 32768
