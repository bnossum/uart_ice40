# uart_ice40
Minimal size uart for ice40 FPGAs, written in Verilog, between 32 and 55 logicCells.

There is much simulation still to do, and the uart has never been on hardware.

My intention is to use this small project to learn the github flow, while contributing something potentially useful. Also, the project will be used with my upcoming < 250 logicCells controller for the iCE40 series FPGAs.

Uart format is startbit, 8 data bits, 1 stop bit. The bitrate is hardcoded (via two parameters).

