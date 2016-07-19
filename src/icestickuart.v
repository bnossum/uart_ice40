/* Top level that just instantiates a UART in loopback mode in an icestick.
 * Assumtions: 12M clock. 115200 bps. 8N1 format.
 * Note: Needs retesting on hardware after code reorganization.
 */

/*              
MIT License

Copyright (c) 2016 Baard Nossum

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
/* 
 * LogicCells:
 * 38 for uart proper
 *  1 for metastability removal rxpin
 *  1 for generation of constant 1'b1.
 * -------
 * 40 logicCells in total
 * 
 */
/*                                            
 PIO3_08  _                _    _             
 [x] ----| |- rxpinmeta1 -| |--| |-- rxpin -> UART
         >_|              |_|  >_|
                  _
 UART -- txpin ->| |--|>o--[x] PIO03_07
                 >_|
 */
module top
//  ( inout PIO3_08,PIO3_07,PIO1_14,PIO1_02,GBIN6
//    );
  ( input PIO3_08, GBIN6,
    output PIO3_07, PIO1_14, PIO1_02
    );
   wire [7:0] d;
   wire       clk,cte1,rxpinmeta1,c_rxpinmeta1,rxpin;
   reg [3:0]  bitxcecnt;
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire			bytercvd;		// From uart of uartICE40.v
   wire [7:0]		q;			// From uart of uartICE40.v
   wire			txbusy;			// From uart of uartICE40.v
   wire			txpin;			// From uart of uartICE40.v
   // End of automatics

   // One LUT consumed to get a constant 1.
   // May get constant 1 from an unbonded pad instead.
   assign cte1 = 1'b1; 

   // Clock pin
   SB_GB_IO clockpin
     ( .PACKAGE_PIN(GBIN6),
       .GLOBAL_BUFFER_OUTPUT(clk));
   
   // Transmit pin
   SB_IO #( .PIN_TYPE(6'b011111)) // OUTPUT_REGISTERED_INVERTED/INPUT_LATCH
   IO_tx
     ( .PACKAGE_PIN(PIO3_07),
       .OUTPUT_CLK(clk),
       .D_OUT_0(txpin) );

   // txbusy to LED0
   SB_IO #( .PIN_TYPE(6'b010111)) // OUTPUT_REGISTERED/INPUT_LATCH
   IO_txbusy
     ( .PACKAGE_PIN(PIO1_14),
       .OUTPUT_CLK(clk),
       .D_OUT_0(txbusy) );

   // bitxce to J2 pin 1 for debugging
   SB_IO #( .PIN_TYPE(6'b010111)) // OUTPUT_REGISTERED/INPUT_LATCH
   IO_bitxce
     ( .PACKAGE_PIN(PIO1_02),
       .OUTPUT_CLK(clk),
       .D_OUT_0(bitxce) );

   // Receive pin
   SB_IO #( .PIN_TYPE(6'b000000)) // NO_OUTPUT/INPUT_REGISTERED
   IO_rx
     ( .PACKAGE_PIN(PIO3_08),
       .INPUT_CLK(clk),
       .D_IN_0(rxpinmeta1) );
   // Metastability. I explicitly instantiate a LUT,
   SB_LUT4 #( .LUT_INIT(16'haaaa))
   cmb( .O(c_rxpinmeta1), .I3(1'b0), .I2(1'b0), .I1(1'b0), .I0(rxpinmeta1));
   SB_DFF metareg( .Q(rxpin), .C(clk), .D(c_rxpinmeta1));

   // Prescaler : 12000000/(115200*8) = 13.02, so make a counter
   // 4 5 6 7 8 9 a b c d e f 10
   always @(posedge clk)
      bitxcecnt <= bitxcecnt[3] ? 4'h4 : bitxcecnt+4'h1;
   assign bitxce = bitxcecnt[3];              
   // The module proper              
   uartICE40 uart
     (/*AUTOINST*/
      // Outputs
      .txpin				(txpin),
      .txbusy				(txbusy),
      .bytercvd				(bytercvd),
      .q				(q[7:0]),
      // Inputs
      .clk				(clk),
      .bitxce				(bitxce),
      .load				(load),
      .d				(d[7:0]),
      .rxpin				(rxpin));

   // Connect the uart in loopback:
   assign load = bytercvd;
   assign d = q;
endmodule

// Local Variables:
// verilog-library-directories:("." "./fromrefdesign/" )
// verilog-library-files:("../../../PROJ/iCE_simlib/iCE_simlib.v" "uart.v" )
// verilog-library-extensions:(".v" )
// End:

