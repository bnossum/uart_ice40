/* A small simple asynchronous transmitter/receiver
   For documentation see the wiki pages.  */

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
        output [7:0] q //        Received byte from serial receive/byte buffer
        );
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire			loadORtxce;		// From rxtxdiv_i of rxtxdiv_m.v
   wire			rst4;			// From rxtxdiv_i of rxtxdiv_m.v
   wire			rxce;			// From rxtxdiv_i of rxtxdiv_m.v
   wire [1:0]		rxst;			// From uartrx_i of uartrx_m.v
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
      .rst4				(rst4),
      // Inputs
      .clk				(clk),
      .bitxce				(bitxce),
      .load				(load),
      .rxpin				(rxpin),
      .rxst				(rxst[1:0]));
endmodule
 ///////////////////////////////////////////////////////////////////////////////
module uarttx_m
  (
   input       clk,load,loadORtxce,
   input [7:0] d,
   output      txpin, 
   output      txbusy
   );
   genvar      i;
   wire        c_txbusy,c_pp;
   wire [9:0]  c_a,a;
   wire [10:1] cy;
   SB_LUT4 #(.LUT_INIT(16'haaaa))
   ff_i(.O(c_a[9]), .I3(1'b0), .I2(1'b0), .I1(1'b0), .I0(load));
   SB_DFFE ff_r( .Q(a[9]), .C(clk), .E(loadORtxce), .D(c_a[9]));
   generate
      for ( i = 0; i < 9; i = i + 1 ) begin : blk
         if ( i == 0 ) begin
            SB_LUT4 #(.LUT_INIT(16'h55cc))
            shcmb( .O(c_a[i]), .I3(load), .I2(1'b1), .I1(a[i+1]), .I0(1'b0));
            SB_CARRY shcy(.CO(cy[i+1]), .CI(1'b0), .I1(1'b1), .I0(a[i+1]));
         end else begin
            SB_LUT4 #(.LUT_INIT(16'h55cc))
            shcmb( .O(c_a[i]), .I3(load), .I2(1'b1), .I1(a[i+1]), .I0(d[i-1]));
            SB_CARRY shcy(.CO(cy[i+1]), .CI(cy[i]), .I1(1'b1), .I0(a[i+1]));
         end
         SB_DFFE r( .Q(a[i]), .C(clk), .E(loadORtxce), .D(c_a[i]));
      end
   endgenerate
   SB_LUT4 #(.LUT_INIT(16'hffaa))
   txbusy_i( .O(c_txbusy), .I3(cy[9]), .I2(1'b1), .I1(1'b0), .I0(load));
   SB_CARRY msbcy( .CO(cy[10]), .CI(cy[9]), .I1(1'b1), .I0(1'b0));
   SB_DFFE txbusy_r( .Q(txbusy), .C(clk), .E(loadORtxce), .D(c_txbusy));
   SB_LUT4 #(.LUT_INIT(16'hb888))
   pp_i( .O(c_pp), .I3(cy[10]), .I2(a[0]), .I1(load), .I0(txpin));
   SB_DFFE pp_r( .Q(txpin), .C(clk), .E(loadORtxce), .D(c_pp) );
endmodule
 ///////////////////////////////////////////////////////////////////////////////
module uartrxsm_m
  (input        clk,rxce,rxpin,lastbit,
   output       bytercvd,
   output [1:0] rxst
   ); 
   wire [1:0]   nxt_rxst;
   
   SB_LUT4 #(.LUT_INIT(16'h5303))
   stnxt1_i( .O(nxt_rxst[1]),.I3(rxst[1]),.I2(rxst[0]),.I1(rxpin),.I0(lastbit));
   SB_LUT4 #(.LUT_INIT(16'hf300))
   stnxt0_i( .O(nxt_rxst[0]), .I3(rxst[1]), .I2(rxst[0]), .I1(rxpin),.I0(1'b0));
   SB_DFFE r_st0( .Q(rxst[0]), .C(clk), .E(rxce), .D(nxt_rxst[0]));
   SB_DFFE r_st1( .Q(rxst[1]), .C(clk), .E(rxce), .D(nxt_rxst[1]));
   SB_LUT4 #(.LUT_INIT(16'h0080))
   bytercvd_i( .O(bytercvd), .I3(rxst[1]), .I2(rxst[0]), .I1(rxpin), .I0(rxce));
endmodule
 ///////////////////////////////////////////////////////////////////////////////
module uartrx_m
  (
   input        clk,rxce,rxpin,
   output       bytercvd,
   output [1:0] rxst,
   output [7:0] q
   );
   genvar        i;
   wire [7:0]    c_sh;

   uartrxsm_m rxsm(// Inputs
                   .lastbit( q[0] ),
                   /*AUTOINST*/
		   // Outputs
		   .bytercvd		(bytercvd),
		   .rxst		(rxst[1:0]),
		   // Inputs
		   .clk			(clk),
		   .rxce		(rxce),
		   .rxpin		(rxpin));
   generate
      for ( i = 0; i < 8; i = i + 1 ) begin : blk
         localparam a = i == 7 ? 16'hbfb0 : 16'h8f80;
         SB_LUT4 #(.LUT_INIT(a))
         sh( .O(c_sh[i]), .I3(q[i]), .I2(rxst[1]), .I1(rxst[0]), 
             .I0(i==7 ? rxpin:q[i+1]));
         SB_DFFE  shreg( .Q(q[i]), .C(clk), .E(rxce), .D(c_sh[i]) );
      end
   endgenerate
endmodule
 ///////////////////////////////////////////////////////////////////////////////
module rxtxdiv_m
  #( parameter ADJUSTSAMPLEPOINT = 0, SUBDIV16 = 0)
   (input       clk,bitxce,load,rxpin,
    input [1:0] rxst,
    output      loadORtxce,rxce,rst4
    );
   localparam rstval_lsb = ADJUSTSAMPLEPOINT ? 16'haffa : 16'h0550;
   localparam LOOPLIM = SUBDIV16 ? 4 : 3;
   wire [LOOPLIM+1:0] cy,rxcy;
   wire               c_rxce;
   wire [LOOPLIM-1:0] c_txcnt,txcnt,c_rxcnt,rxcnt;
   genvar             j;
               
   assign cy[0] = 1'b0;
   generate
      for ( j = 0; j < LOOPLIM; j = j + 1 ) begin : blk0
         SB_LUT4 #(.LUT_INIT(16'hc33c)) i_txcnt1(.O(c_txcnt[j]),       
                .I3(cy[j]),  .I2(txcnt[j]), .I1(j==0 ? bitxce:1'b0), .I0(1'b0));
         SB_CARRY i_cy1(.CO(cy[j+1]), 
                 .CI(cy[j]), .I1(txcnt[j]), .I0(j==0 ? bitxce:1'b0));
         SB_DFF reg1( .Q(txcnt[j]), .C(clk), .D(c_txcnt[j]));
         if ( j == LOOPLIM-1 ) begin
            SB_LUT4 #(.LUT_INIT(16'hfaaa)) 
            i_txcnt3(.O(loadORtxce),      
                 .I3(cy[j+1]),.I2(bitxce ), .I1(bitxce),.I0(load));
            SB_CARRY i_cy3(.CO(rxcy[0]),
                 .CI(cy[j+1]),.I1(bitxce ), .I0(bitxce));
         end
      end
   endgenerate
   generate
      for ( j = 0; j < LOOPLIM; j = j + 1 ) begin : blk1
         if ( j != LOOPLIM-1) begin
            SB_LUT4 #(.LUT_INIT(j == 0 ? rstval_lsb : 16'h0550)) i_rxcnt0
              (.O(c_rxcnt[j]), .I3(rxcy[j]), .I2(rxcnt[j]),.I1(1'b0),.I0(rst4));
            SB_CARRY i_cy4(.CO(rxcy[j+1]),.CI(rxcy[j]),.I1(rxcnt[j]),.I0(1'b0));
         end else begin
            SB_LUT4 #(.LUT_INIT(j == (LOOPLIM-1) ? 16'hcffc:16'h0550)) i_rxcntl
              (.O(c_rxcnt[j]), .I3(rxcy[j]), .I2(rxcnt[j]),.I1(rst4),.I0(1'b0));
            SB_CARRY i_cy4(.CO(rxcy[j+1]),.CI(rxcy[j]),.I1(rxcnt[j]),.I0(rst4));
         end
         SB_DFF reg4( .Q(rxcnt[j]), .C(clk), .D(c_rxcnt[j]));
         if ( j == LOOPLIM-1 ) begin
            SB_LUT4 #(.LUT_INIT(16'h0055)) i_rst
              (.O(rst4), .I3(rxst[1]),     .I2(1'b0),.I1(bitxce), .I0(rxst[0]));
            SB_CARRY i_andcy
              (.CO(rxcy[j+2]),.CI(rxcy[j+1]),.I1(1'b0),.I0(bitxce));
            SB_LUT4 #(.LUT_INIT(16'hfc30)) i_rxce
              (.O(c_rxce), .I3(rxcy[j+2]),.I2(rxpin),.I1(rxst[1]),.I0(rxst[0]));
            SB_DFF regrxce( .Q(rxce), .C(clk), .D(c_rxce));
         end
      end
   endgenerate
endmodule
 // Local Variables:
 // verilog-library-directories:("." "./fromrefdesign/" )
 // verilog-library-files:("../../../PROJ/iCE_simlib/iCE_simlib.v" )
 // verilog-library-extensions:(".v" )
 // End:
