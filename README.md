# uart_ice40
Minimal uart for ice40 FPGAs, in Verilog.

Warning: This design is not yet debugged, and as such is certain to fail!

My intention is to use this small project to learn the github flow, while contributing something potentially usefull. Also, the project will be used with my upcoming < 250 logiccells controller for the iCE40 series FPGAs.

Uart format is startbit, 8 data bits, 1 stop bit. The bitrate is hardcoded (via two parameters).

The uart has not yet been simulated, nor tested.
