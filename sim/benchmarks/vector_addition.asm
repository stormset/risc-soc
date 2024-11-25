; load vector (2, 8, -4, -16) in memory
    addui r30, r0, 0x00004000
    addi r2,r0,2
    sw 0(r30),r2
    addi r2,r0,8
    sw 4(r30),r2
    addi r2,r0,-4
    sw 8(r30),r2
    addi r2,r0,-16 
    sw 12(r30),r2

    ; setup indices
    addi r1,r0,0     ; m = 1
    addi r2,r0,4     ; n = 4
    addi r3,r0,0     ; i = 0
    add r4,r0,r30    ; element pointer

; for (i = 0; i < 4; i++) m = m*a(i);
add_loop:
    lw r5,0(r4)	     ; load element of a
    add r1,r5,r1     ; accumulate
    addi r3,r3,1     ; increment i
    addi r4,r4,4     ; increment index
    seq r6,r2,r3     ; is i = n?
    beqz r6,add_loop ; if no loop, otherwise, end

end_program:          
    j end_program    ; infinite loop (halt)
