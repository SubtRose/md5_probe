section .bss
	ERRORCODE: 	resd	1
	INPUTMESSAGE:	resq	1	;; <--(address) 
	INPUTLEN:	resd	1	
	SOURCEMESSAGE:	resq	1	;; (address)
	SOURCELEN:	resd	1
	MD5HASH:	resb	0x10
	MD5BCP:		resb	0x10
	FILEDESC:	resb	1
	
section .text

global _start

;; X - %edi, Y - %esi, Z - %edx, result -  %edi	;;
f_func:
	and esi, edi
	not edi
	and edi, edx
	or edi, esi
	ret
g_func:
	and edi, edx
	not edx
	and esi, edx
	or edi, edi
	ret
h_func:
	xor esi, edx
	xor edi, esi
	ret
i_func:
	not edx
	or edi, edx
	xor edi, esi
	ret

	HASHSIZE	equ	0x10
	ADDRSIZE	equ	0x08

	ROTFUNC:	dq	f_func, g_func, h_func, i_func	

	S_SEQ:		db	0x07, 0x0c, 0x11, 0x16,
			db	0x05, 0x09, 0x0e, 0x14,
			db	0x04, 0x0b, 0x10, 0x17,
			db	0x06, 0x0a, 0x0f, 0x15

	K_SEQ:		db	0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,
			db	0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,

			db	0x01,0x06,0x0b,0x00,0x05,0x0a,0x0f,0x04,
			db	0x09,0x0e,0x03,0x08,0x0d,0x02,0x07,0x0c,
	
			db	0x05,0x08,0x0b,0x0e,0x01,0x04,0x07,0x0a,
			db	0x0d,0x00,0x03,0x06,0x09,0x0c,0x0f,0x02,
			
			db	0x00,0x07,0x0e,0x05,0x0c,0x03,0x0a,0x01,
			db	0x08,0x0f,0x06,0x0d,0x04,0x0b,0x02,0x09	
	
	T_SEQ:		dd	0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,
	                dd	0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
        	        dd	0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be, 
	                dd	0x6b901122,0xfd987193,0xa679438e,0x49b40821,
        	        dd	0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,
                	dd	0xd62f105d,0x2441453,0xd8a1e681,0xe7d3fbc8,
	                dd	0x21e1cde6 0xc33707d6,0xf4d50d87,0x455a14ed,
        	        dd	0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
	                dd	0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,
        	        dd	0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
	                dd	0x289b7ec6,0xeaa127fa,0xd4ef3085,0x4881d05,
        	        dd	0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
                	dd	0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,
	                dd	0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
	                dd	0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,
        	        dd	0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391

;; [abcd k s i]
;; a = b + ((a + Func(b,c,d) + X[k] + T[i]) <<< s)
complete_all_rounds:
	mov ecx, 1

	lea rdi, [MD5BCP]
	lea rsi, [MD5HASH]
	mov ecx, 2
	cld
	rep movsq		;; backuping
	
step:
	;; initaliazation and fetching
	mov r14b, cl
	and r14, 0x03

	mov r9, rcx
	shr r9, 0x04
	and r9, 0x03

	lea rdi, [MD5HASH]

	lea r8, [ROTFUNC+8*r9]

	mov bl, BYTE[S_SEQ+r14+4*r9]

	push r14
	xor r14, r14
	mov r14b, BYTE[K_SEQ+rcx]
	mov esi, DWORD[r10+4*r14]
	pop r14

	mov edx, DWORD[T_SEQ+4*r14]
	
	;; processing
	mov r12d, DWORD[rdi+4*r14]
	push rdi
	push rsi
	push rdx
	push r14
	mov r13, rdi
	inc r14
	and r14, 0x03
	mov edi, DWORD[r13+4*r14]
	inc r14
	and r14, 0x03
	mov esi, DWORD[r13+4*r14]
	inc r14
	and r14, 0x03
	mov edx, DWORD[r13+4*r14]
	call r8
	add r12d, edi
	pop r14
	pop rdx
	pop rsi
	pop rdi
	add r12d, edx

	push rcx
	mov cl, bl
	shl r12d, cl
	pop rcx

	add r12d, esi
	mov DWORD[rdi], r12d
		
	inc cl
	cmp cl, 0x41
	jl step

	lea rsi, [MD5BCP]
	lea rdi, [MD5HASH]
	mov ecx, 4
	push rbx
re_backuping:
	dec ecx
	add ebx, DWORD[rsi+rcx]
	add DWORD[rdi+rcx], ebx
	loop re_backuping			;; re-backuping
	pop rbx

	ret
	
_start:
	
	call GET_SOURCE
	call PADDING_MESSAGE
	call APPEND_LENGTHOF_MESSAGE
	call INIT_MD5_BUFFER
	call PROCESSING_MD5_BUFFER
	call WRITE_TO
	call EXIT_

;; input message into argv[1]
GET_SOURCE:
	add rsp, ADDRSIZE
	pop rdi
	add rsp, ADDRSIZE
	pop rsi
	mov ecx, ADDRSIZE
	shl rcx, 2
	sub rsp, rcx
		

	mov BYTE[FILEDESC], 0x01	;; set hash-stream to stdout
	or DWORD[ERRORCODE], 0x02
	cmp rdi, 1
	je EXIT_
	mov DWORD[ERRORCODE], 0x00
	mov rsi, QWORD[rsi]
	add rsi, 8			;; now rsi is address of input message
	mov QWORD[INPUTMESSAGE], rsi

	push rcx
	mov rcx, rsi
loop_strlen:
	inc rcx
	cmp BYTE[rcx], 0x00
	jne loop_strlen

	sub rcx, rsi
	mov DWORD[INPUTLEN], ecx
	pop rcx
	ret

PADDING_MESSAGE:
	
	mov ecx, DWORD[INPUTLEN]
	shl ecx,3				;; now unit is BIT
	inc ecx	
	
	mov edx, 448
padding:
	cmp ecx, edx
	jle padded
	add edx, 512
	jmp padding
padded:
	shr edx, 3				;; now unit is BYTE
	mov DWORD[SOURCELEN], edx

	;; here's allocation memory for source message(padded)
	mov eax, 9
	xor edi, edi
	mov esi, edx
	mov edx, 0x01
	or edx, 0x02		;;	RW- - permissions
	mov r10, 0x02
	or r10, 0x10		;; (MAP_PRIVATE(0x02) | MAP_ANONYMOUS(0x10))
	mov r8, -1
	xor r9d, r9d
	syscall
	
	or DWORD[ERRORCODE], 0x01
	cmp rax, 12			;; ENOMEM=12
	je EXIT_
	mov DWORD[ERRORCODE], 0x00	
	mov QWORD[SOURCEMESSAGE], rax

	;; copy input message into source-buffer
	mov rsi, QWORD[INPUTMESSAGE]
	mov rdi, rax
	mov ecx, DWORD[SOURCELEN]
	push rcx
	shr ecx, 3			;; for qword-processing
	cld
copy_padded:
	movsq
	loop copy_padded
	
	mov BYTE[rsi], 0x80
	inc rsi
	pop rcx 
	lea rdi, [rax+rcx]		;; marking a boundary source-message	
	
zeroing:
	mov BYTE[rsi], 0x00
	inc rsi
	cmp rsi, rdi
	jl zeroing
zeroed:
	ret


APPEND_LENGTHOF_MESSAGE:
	mov edx, DWORD[INPUTLEN]
	shl edx, 3			;; now unit is BIT
	mov ecx, DWORD[SOURCELEN]
	mov QWORD[SOURCEMESSAGE+rcx-8], rcx
	ret

INIT_MD5_BUFFER:
	lea rsi, [MD5HASH]
	mov QWORD[rsi],	0xefcdab8967452301
	mov QWORD[rsi+8], 0x1032547698badcfe
	ret

PROCESSING_MD5_BUFFER:
	mov r10, QWORD[SOURCEMESSAGE]	;; %r10-->CRT_BLK512
	xor r11, r11
	mov r11d, DWORD[SOURCELEN]
	add r11, r10			;; %r11-->LIMIT OF PROCESSING
	
proc_blk512:
	
	call complete_all_rounds
	add r10, 0x40
	cmp r10, r11
	jl proc_blk512

	ret

WRITE_TO:
	mov eax, 1
	xor edi, edi
	mov dil, BYTE[FILEDESC] 
	lea rsi, [MD5HASH]
	mov edx, HASHSIZE 
	syscall
	cmp eax, HASHSIZE
	ret

EXIT_:
	cmp DWORD[ERRORCODE], 0x04
	jl badmem_exit	
	mov eax, 0x0b
	mov rdi, QWORD[SOURCEMESSAGE]
	mov esi, DWORD[SOURCELEN]
	syscall

badmem_exit:
	mov eax, 60
	mov edi, DWORD[ERRORCODE]
	syscall

DPRINT_HASH:
	mov eax, 1
	mov edi, 1
	lea rsi, [MD5HASH]
	mov edx, HASHSIZE
	syscall
