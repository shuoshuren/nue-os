.code32

.global _start

_start:


put_red_string:
	xor %ecx,%ecx # clear the counter

loop:
	mov $red_str,%ebx
	add %cx,%bx
	movb (%ebx),%al
	movb $0x0c,%ah
	mov $0xb8A00,%ebx	
    shl %ecx
    add %ecx,%ebx
    shr %ecx
    movw %ax,(%ebx)
    inc %ecx
    cmp $62,%ecx
    jne loop



halt:
    jmp halt
    
red_str:
	.ascii "You've entered protected mode                            "
