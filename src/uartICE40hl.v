/* High level version of a small simple asynchronous transmitter/receiver
   For documentation see the wiki pages. */

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
 ///////////////////////////////////////////////////////////////////////////////
module uartICE40
  # (parameter SUBDIV16 = 0, //  Examine rx line 16 or 8 times per bit
     ADJUSTSAMPLEPOINT=0     //  See documentation
     ) (
        input        clk, //     System clock
        input        bitxce, //  High 1 clock cycle 8 or 16 times per bit
        input        load, //    Time to transmit a byte. Load transmit buffer
        input [7:0]  d, //       Byte to load into transmit buffer
        input        rxpin, //   Connect to receive pin of uart
        output       txpin, //   Connect to INVERTED transmit pin of uart
        output       txbusy, //  Status of transmit. When high do not load
        output       bytercvd, //Status receive. True 1 clock cycle only
`ifdef SIMULATION
        output [1:0] rxst, //    Testbench need access to receive state machine
`endif        
        output [7:0] q //        Received byte from serial receive/byte buffer
        );
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire			loadORtxce;		// From rxtxdiv_i of rxtxdiv_m.v
   wire			rxce;			// From rxtxdiv_i of rxtxdiv_m.v
   // End of automatics
   uarttx_m uarttx_i (/*AUTOINST*/
		      // Outputs
		      .txpin		(txpin),
		      .txbusy		(txbusy),
		      // Inputs
		      .clk		(clk),
		      .load		(load),
		      .loadORtxce	(loadORtxce),
		      .d		(d[7:0]));
   uartrx_m uartrx_i (/*AUTOINST*/
		      // Outputs
		      .bytercvd		(bytercvd),
		      .rxst		(rxst[1:0]),
		      .q		(q[7:0]),
		      // Inputs
		      .clk		(clk),
		      .rxce		(rxce),
		      .rxpin		(rxpin));
   rxtxdiv_m #( .ADJUSTSAMPLEPOINT(ADJUSTSAMPLEPOINT),
                .SUBDIV16(SUBDIV16))
   rxtxdiv_i
     (/*AUTOINST*/
      // Outputs
      .loadORtxce			(loadORtxce),
      .rxce				(rxce),
      // Inputs
      .clk				(clk),
      .bitxce				(bitxce),
      .load				(load),
      .rxpin				(rxpin),
      .rxst				(rxst[1:0]));
endmodule
 ///////////////////////////////////////////////////////////////////////////////
module uarttx_m
  (input       clk,load,loadORtxce,
   input [7:0] d,
   output reg  txpin, txbusy
   );
   reg [9:0]   a;
`ifdef SIMULATION
   initial begin txbusy = 0; txpin = 0; a = 0;  end
`endif   
   always @(posedge clk) 
     if ( loadORtxce ) begin
        a[9:0] <= load ? ~{1'b0,d,1'b0} : {1'b0,a[9:1]};
        txbusy <= load | |a[9:1]; 
        txpin  <= (load & txpin) | (!load & |a[9:1] & a[0]);
     end
endmodule
 ///////////////////////////////////////////////////////////////////////////////
module uartrxsm_m
  # ( parameter HUNT = 2'b00, GRCE = 2'b01, ARMD = 2'b10, RECV = 2'b11 )
   (input            clk,rxce,rxpin,lastbit,
    output           bytercvd,
    output reg [1:0] rxst
    );
   reg [1:0]         nxt;   
`ifdef SIMULATION
   initial rxst = 0;
`endif
   always @(/*AS*/lastbit or rxce or rxpin or rxst) begin
      casez ( {rxst,rxpin,lastbit,rxce} )
        {HUNT,3'b1??} : nxt = HUNT; 
        {HUNT,3'b0?0} : nxt = HUNT; 
        {HUNT,3'b0?1} : nxt = ARMD; 
        {ARMD,3'b??0} : nxt = ARMD;
        {ARMD,3'b0?1} : nxt = RECV;
        {ARMD,3'b1?1} : nxt = HUNT; // False start bit.
        {RECV,3'b??0} : nxt = RECV;
        {RECV,3'b?01} : nxt = RECV;
        {RECV,3'b?11} : nxt = GRCE;
        {GRCE,3'b??0} : nxt = GRCE;
        {GRCE,3'b0?1} : nxt = HUNT; // Stop bit wrong, reject byte.
        {GRCE,3'b1?1} : nxt = HUNT; // Byte received
      endcase
   end
   always @(posedge clk)
     rxst <= nxt;
   assign bytercvd = (rxst == GRCE) && rxpin && rxce;
endmodule
 ///////////////////////////////////////////////////////////////////////////////
module uartrx_m
  # (parameter HUNT = 2'b00, GRCE = 2'b01, ARMD = 2'b10, RECV = 2'b11 )
   (
    input            clk,rxce,rxpin,
    output           bytercvd,
    output [1:0]     rxst,
    output reg [7:0] q
    );
`ifdef SIMULATION
   initial q = 0;
`endif
   uartrxsm_m #(.HUNT(HUNT), .GRCE(GRCE), .ARMD(ARMD), .RECV(RECV))
   rxsm(// Inputs
        .lastbit( q[0] ),
        /*AUTOINST*/
	// Outputs
	.bytercvd			(bytercvd),
	.rxst				(rxst[1:0]),
	// Inputs
	.clk				(clk),
	.rxce				(rxce),
	.rxpin				(rxpin));
   always @(posedge clk)
     if ( rxce )
       q <= (rxst == ARMD) ? 8'h80 : (rxst == RECV) ? {rxpin,q[7:1]} : q;
endmodule
 ///////////////////////////////////////////////////////////////////////////////
module rxtxdiv_m
  # (parameter HUNT = 2'b00, GRCE = 2'b01, ARMD = 2'b10, RECV = 2'b11,
     SUBDIV16 = 0, ADJUSTSAMPLEPOINT = 0
     )
   (input       clk,bitxce,load,rxpin,
    input [1:0] rxst,
    output      loadORtxce,
    output reg  rxce
    );
   localparam   rstval = SUBDIV16 ? (ADJUSTSAMPLEPOINT ? 4'b1001 : 4'b1000) :
                                    (ADJUSTSAMPLEPOINT ? 3'b101  : 3'b100);
   reg [2+SUBDIV16:0]    txcnt,rxcnt;
`ifdef SIMULATION
   initial txcnt = 0;
`endif
   always @(posedge clk) begin
      if ( bitxce ) begin
         txcnt <= txcnt + 1;
         rxcnt <= rxst == HUNT ? rstval : (rxcnt+1);
      end
//      rxce <= (((rxst == ARMD) | (rxst == RECV)) & (&rxcnt & bitxce) ) 
//        | ((rxst == HUNT | rxst == GRCE) & rxpin);
      rxce <= ((rxst != HUNT) & (&rxcnt & bitxce) ) 
        | ((rxst == HUNT | rxst == GRCE) & rxpin);
   end      
   assign loadORtxce = (&txcnt & bitxce) | load;
endmodule
 // Local Variables:
 // verilog-library-directories:("." "./fromrefdesign/" )
 // verilog-library-files:("../../../PROJ/iCE_simlib/iCE_simlib.v" )
 // verilog-library-extensions:(".v" )
 // End:
