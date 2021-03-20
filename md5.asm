;; Five stage-procedures:
;;	1. Append Padding Bits
;;	2. Append Length
;;	3. Initialize MD buffer
;;		3.1 Initialize other objects
;;	4. Process Message in 16-Word Blocks
;;	5. Output

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .bss
	SOURCE_MESSAGE	resb MAX_SIZE		;; input buffer
	SOURCE_LENGTH_0	resqw 1			;; size of source message(in bytes)
	SOURCE_LENGTH	resqw 1			;; size of padded source(in bytes)
	MD5_HASH 	resb MD5_LENGTH		;; 128 bits
section .text
	MAX_SIZE:	dw	0x2000
	MD5_LENGTH:	dw	0x10
	TABLE:		dw .....	;; 64 entries for 4 bytes
	SEQUENCE_S:	db .....	;; 16 entries for 1 byte
	SEQUENCE_K:	db .....	;; 64 entries for 1 bytes

padding_message:
	push rcx
	push rdx
	push rsi
	
	mov rcx, QWORD[SOURCE_LENGTH_0]
	lea rsi, [SOURCE_MESSAGE+rcx]
	or BYTE[rsi], 0x80
	sub rsi, rcx	
	shl rcx, 3				;; unit is bit
	inc rcx

	mov rdx, 448
padding:
	cmp rcx, rdx
	jle padded
	add rdx, 512
	jmp padding
padded:
	shr rdx, 3				;; unit is byte
	mov QWORD[SOURCE_LENGTH], rdx

	;;NEED TO ZEROING!!!;;
	
	pop rsi
	pop rdx
	pop rcx
	ret

append_lengthof_message:
	push rsi
	push rdi
	mov rsi, QWORD[SOURCE_LENGTH]
	lea rdi, [SOURCE_MESSAGE+rsi-0x40]
	mov rsi, QWORD[SOURCE_LENGTH_0]
	shl rsi, 3		;; unit is bits
	cld
	movsq
	pop rdi
	pop rsi	
	ret

;;3 stage: Initialize MD5 buffer;;;;;;;;;;;;;;;;
init_MD5_buffer:
	push rdi
	lea rdi, [MD5_HASH]
	DWORD[rdi], 0x01234567
	add edi, 4
	DWORD[rdi], 0x89abcdef
	add edi, 4
	DWORD[rdi], 0xfedcba98
	add edi, 4
	DWORD[rdi], 0x76543210	
	pop rdi
	ret

	

;;4 stage: Processing MD buffer;;;;;;;;;;;;;;;;;
	MD5BCP:			db	-0X10
	WORD512BLK:		db	-0x18
	LIMIT_SOURCE:		db	-0x20
	FGHI:			db	-0x40
	DEPTH_STACK_PROC:	db	-0x40
	
processing_MD5_buffer:
	push rcx
	push rdx
	push rdi
	push rsi
	push rbp
	mov rbp, rsp
	sub esp, DEPTH_STACK_PROC

	lea rsi, [SOURCE_MESSAGE]
	mov QWORD[rbp+WORD512BLK], rsi		;; current 512-bit block
	mov edx, DWORD[SOURCE_LENGTH]
	add esi, edx 
	mov QWORD[rbp+LIMIT_SOURCE], rsi	;; end of padded message

;;foreach 512-bit block;;
foreach_512:

	;;;;;;backup md5 buffer;;;;;;;;;;;;;;;;
	mov ecx, 4
	lea rsi, [MD5_HASH]
	lea rdi, [rbp+M5BCP]
	cld
	rep movsd	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	;;internals cycles;;;;;;;;;;;;;;;;;;;;;;;;;
	;;round_procedure(void);;;;;;;;;;;;;;;;;;;;
	call round_procedure
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	;;refresh md5-hash's buffer;;
	lea rdi, [MD5_HASH]
	lea rsi, [rbp+MD5BCP]
	mov ecx, 4
refresh_md5_x:
	add DWORD[rdi], DWORD[rsi]
	add rdi, 4
	add rsi, 4
	loop refresh_md5_x
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

	add QWORD[rbp+WORD512BLK], 8
	cmp QWORD[rbp+WORD512BLK], QWORD[rbp+LIMIT_SOURCE]
	jl foreach_512
;;end foreach_512;;

	add esp, DEPTH_STACK_PROC
	pop rbp
	pop rsi
	pop rdi
	pop rdx
	pop rcx
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;5 stage: Output;;;;;;;;;;;;;;;;;;;;;;;;;
	mov eax, WRITE_CODE_FROM_ABI_X64
	mov edi, STDOUT_STREAM
	lea rsi, MD5_HASH
	mov edx, MD5_LENGTH
	syscall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; finishing program
	mov eax, EXIT_CODE_FROM_ABI_X64
	mov edi, ERROR_CODE
	syscall


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;ADDITIONAL PROCEDURE;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;FGHI-PROCEDURES;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;DWORD(eax) X_FUNC(DWORD(edi), DWORD(esi), DWOTR(edx));;
F_FUNC:
	and esi, edi
	not edi
	and edi, edx
	or esi, edi
	mov eax, esi
	ret
G_FUNC:
	and edi, edx
	not edx
	and esi, edx
	or edi, esi
	mov eax, edi
	ret
H_FUNC:
	xor edi, esi
	xor edi, edx
	mov eax, edi
	ret
I_FUNC:
	not edx
	or edi, edx
	xor esi, edi
	mov eax, esi
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;round-procedure(void);;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;round[abcd k s i];;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;a = b + ((a + FGHI(b,c,d) + X[k] + T[i]) <<< s);;;;;;;;;;;
;;STACK-FRAME OF ROUND-PROCEDURE IS PART OF STACK-FRAME;;;;;
;;OF MAIN PROCEDURE;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;PRERESERVED REGISTERS(TO FUNCTIONS)	
	;;	RESULT, X, Y, Z, CORRESPONDLY	-	EAX, EDI, ESI, EDX;
	;;CNT_I					-	RCX;
	;;CNT_J					-	RBX;
	;;CNT_I & 0X03				-	R7;
	;;CURRENT 32-BITS BLOCK OF HASH(ADDR)	-	R8;
	;;CURRENT S-VALUE			-	R9;
	;;CURRENT K-VALUE			-	R10;
	;;CURRENT X-VALUE(ADDR)			-	R11;
	;;CURRENT FGHI-FUNCTION(ADDR)		-	R12;
	;;TABLE[CNT_I]				-	R13;	

round_procedure:
	push rax
	push rbx
	push rcx
	push rdx
	push rdi
	push rsi
	push r7
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13

	;;iteration's body;;
	mov ecx, 1
	xor ebx, ebx
round_loop:
	mov bl, cl
	shr bl, 4	;;CNT_J

	mov r7b, cl
	and r7b, 0x03	;; CNT_I & 0X03

	lea r8, [MD5_HASH+4*r7]	;; CURRENT BLK OF HASH

	push r7
	inc r7b
	and r7b, 0x03
	mov edi, DWORD[r8+4*r7] 
	inc r7b
	and r7b, 0x03
	mov esi, DWORD[r8+4*r7]
	inc r7b
	and r7b, 0x03
	mov edx, DWORD[r8+4*r7]		;;set a XYZ-context
	pop r7

	lea r9, [SEQUENCE_S]
	add r9, r7
	push rbx
	shl bl, 2
	add rbx, r9
	xor r9d, r9d
	mov r9b, BYTE[rbx]		;; set current S-value
	pop rbx

	lea r10, [SEQUENCE_K]	
	push rcx
	add rcx, r10
	xor r10d, r10d
	mov r10b, BYTE[rcx]		;; set current K-value
	pop rcx
	
	lea r11, [SOURCE_MESSAGE+4*r10]	;; address to X[k]
	
	and bl, 0x03
	lea r12, [FGHI+rbx]		;; current function

	mow r13d, DWORD[TABLE+4*rcx]	;; 32-bit element from table
	
	push r8		
	mov r8d, DWORD[r8]	;;tmp += a;
	add r8d, r13d		;;tmp += T[i];
	lea r11d, DWORD[r11]
	add r8d, r11d;;	tmp += X[k];

	push rdi
	call r12
	pop rdi
	add r8d, eax	;;tmp += Func(b,c,d);
	shl r8d, r9b	;;tmp <<= s;
	add edi, r8d	;;	b += (tmp)
	pop r8
	mov DWORD[r8], edi	;;a=b	
	
	inc cl
	cmp cl, 0x41
	jl round_loop
	

	pop r13
	pop r12
	pop r11
	pop r10
	pop r9
	pop r8
	pop r7
	pop rsi
	pop rdi
	pop rdx
	pop rcx
	pop rbx
	pop rax
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
