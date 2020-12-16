	mov ra0, unif
	mov ra1, unif
	mov rb0, unif
	mov rb1, unif
	mov ra2, unif
	mov ra3, unif
	ldi ra7, 8
	ldi rb5, 16
	ldi ra8, 32
	ldi rb6, 0x3f000000
	ldi r0, 0x1a00
	ldi r1, 4
	nop;  mul24 r1, qpu_num, r1
	add rb2, r0, r1
	shl r1, r1, 7
	ldi r0, 0x88040000
	add rb3, r0, r1
	ldi rb4, -2.0000000e+00
	nop;  mul24 r0, elem_num, 8
	add ra5, ra0, r0
	mov ra6, ra1
	sub rb0, rb0, ra7
	ldi r0, 4
	shl rb1, rb1, r0
	shr r0, ra3, 4
	max ra4, r0, 1
:Ld0_e48
	nop;  read vw_wait
	mov vw_setup, rb2
	mov r0, 0;  mov r1, 1
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov vpm, r0
	mov r0, 0;  mov r1, 1
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov vpm, r0
	mov r0, 0;  mov r1, 1
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov vpm, r0
	mov r0, 0;  mov r1, 1
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	mov t0s, ra5
	nop;  ldtmu0
	fmin.setf -, r4.8af, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8bf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8cf, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	fmin.setf -, r4.8df, rb6
	shl r1, r1, 1;  v8adds.ifc r0, r0, r1
	add ra5, ra5, 4
	nop
	add ra5, ra5, rb0
	nop
	mov vpm, r0
	mov vw_setup, rb3
	mov vw_setup, rb4
	mov vw_addr, ra6
	add ra6, ra6, rb1
	sub.setf ra4, ra4, 1
	brr.anynz -, r:Ld0_e48
	nop
	nop
	nop
	mov.setf irq, nop
	nop;  thrend
	nop
	nop
