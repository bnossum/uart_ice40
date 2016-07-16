# uart_ice40
Minimal size uart for ice40 FPGAs, written in Verilog, between 32 or 34 logicCells

Simulation has been performed successfully. The uart has been on hardware, but need more testing on hardware.

My intention is to use this small project to learn the github flow, while contributing something potentially useful. Also, the project will be used with my upcoming < 250 logicCells controller for the iCE40 series FPGAs.

Uart format is startbit, 8 data bits, 1 stop bit. The bitrate is given by a 8x or 16x bit clock, see [the main documentation file](../tree/master/doc/uartICE40.pdf).

