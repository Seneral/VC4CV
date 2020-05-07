## Free shared QPU mutex
# For development purposes to make sure mutex is released
# Works in all modes (default is fine)

nop;
nop;
nop;
nop;
nop;
nop;
nop;
nop;
or.setf mutex, nop, nop;
nop;
nop;
nop;
nop;
nop;
nop;
nop;
nop;
nop;

mov.setf irq, nop;

nop; thrend
nop
nop
