//////////////////////////////////////////////////////////////////////////////
/* An uart specifically for iCE40, in 42 logic cells,  predivider not included.
 * Typical size is around 50 logic cells.
 * 
 * Usage:
 * o Input rxpin is intended to originate from a physical pin, but can
 *   really come from anywhere. This input should have been clocked
 *   through two ff's, to reduce chances of metastability.
 * o Output txpin is intended to be connected to a physical pin,
 *   where the output is *inverted*. The output of the uart is
 *   constructed this way to avoid a false transmit at power-on.
 *   txpin can really be used anywhere, but please remember to 
 *   invert it.
 * o When status output txbusy is low, a new byte can be transferred,
 *   use d[7:0] for the data, qualify with input load.
 * o If status output bytercvd is high (NB:one cycle only), a byte 
 *   has been received, and can be read from q[7:0].
 * o Parameters:
 *   - SYSCLKFRQ is the system clock frequency. It must be stated
 *     in order to construct a correct bit clock prescaler.
 *   - BITCLKFRQ is the speed of the uart serial operation. It
 *     must be stated in order to correct the prescaler.
 *   - HASRXBYTEREGISTER is a switch. When true, the received
 *     byte is written to a 8-bit holding register, and can be
 *     read at relative leasure, while the receiver shift register
 *     is busy receiving the next byte. If HASRXBYTEREGISTER is false 
 *     the received byte is read directly from the shift register.
 *     In that case 8 logic cells are saved, but the byte must be
 *     read in less than 1/2 bit transfer time. It is reccommended to
 *     set HASRXBYTEREGISTER == 1.
 * 
 * There is no checks on overrun of the receive buffer.
 * 
 */
 
module uart
  # (parameter HASRXBYTEREGISTER = 1, // 0 : q from serial receivebuffer
     //                                  1 : q from byte buffer 
     SYSCLKFRQ = 12000000,            // System Clock Frequency in Hz
     BITCLKFRQ = 115200,              // Bit clock frequency in Hz
     ACCEPTEDERROR_IN_PERCENT = 20    // Accuracy over (startbit,byte,stopbit)
     ) (
        input        clk, //      System clock
        input        cte1, //     Vanity, to get right logic cell count
        input        load, //     Time to transmit a byte. load transmit buffer
        input [7:0]  d, //        Byte to load into transmit buffer
        input        rxpin, //    Connect to receive pin of uart
        output       txpin, //    Connect to INVERTED transmit pin of uart
        output       txbusy, //   Status of transmit. When high do not load
        output       bytercvd, // Status receive. True 1 bit period cycle only
        output [7:0] q //         Received byte from serial receive/byte buffer
        );
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 ce;                     // From prediv_i of prediv_m.v
   wire                 loadORtxce;             // From rxtxdiv_i of rxtxdiv_m.v
   wire                 prediv_m_dummy;         // From prediv_i of prediv_m.v
   wire                 rst4;                   // From uartrx_i of uartrx_m.v
   wire                 rst8;                   // From uartrx_i of uartrx_m.v
   wire                 rxce;                   // From rxtxdiv_i of rxtxdiv_m.v
   wire [1:0]           rxstate;                // From uartrx_i of uartrx_m.v
   // End of automatics
   uarttx_m uarttx_i
     (/*AUTOINST*/
      // Outputs
      .txpin                            (txpin),
      .txbusy                           (txbusy),
      // Inputs
      .clk                              (clk),
      .cte1                             (cte1),
      .load                             (load),
      .loadORtxce                       (loadORtxce),
      .d                                (d[7:0]));
   uartrx_m #(.HASRXBYTEREGISTER(HASRXBYTEREGISTER)) uartrx_i
     (/*AUTOINST*/
      // Outputs
      .bytercvd                         (bytercvd),
      .rst8                             (rst8),
      .rst4                             (rst4),
      .rxstate                          (rxstate[1:0]),
      .q                                (q[7:0]),
      // Inputs
      .clk                              (clk),
      .rxce                             (rxce),
      .rxpin                            (rxpin));
   rxtxdiv_m rxtxdiv_i
     (/*AUTOINST*/
      // Outputs
      .loadORtxce                       (loadORtxce),
      .rxce                             (rxce),
      // Inputs
      .clk                              (clk),
      .ce                               (ce),
      .rst8                             (rst8),
      .rst4                             (rst4),
      .load                             (load),
      .rxstate                          (rxstate[1:0]));
   prediv_m #( .SYSCLKFRQ(SYSCLKFRQ), .BITCLKFRQ(BITCLKFRQ),
               .ACCEPTEDERROR_IN_PERCENT(ACCEPTEDERROR_IN_PERCENT))
   prediv_i
     (/*AUTOINST*/
      // Outputs
      .ce                               (ce),
      .prediv_m_dummy                   (prediv_m_dummy),
      // Inputs
      .clk                              (clk),
      .cte1                             (cte1));
endmodule
   
//////////////////////////////////////////////////////////////////////////////
/* Prescale divider.
 *
 * There are several ways to deal with the txce and rxce. The right
 * strategy depends on the relationship between the bitrate we want,
 * and the system clock frequency.  In an FPGA we will typically have
 * clocks available that are much faster (*100 upwards) higher than
 * the bitrate. For instance, with the iCEstick, we have a 12 MHz
 * crystal. Assume we want a bitrate of 115200, we have 12M =
 * 104*115200.
 * 
 * As long as an acceptable solution in terms of accuracy can be
 * constructed with the above, this is the smallest implementation I
 * can make. When the bitrate is closer to the clockrate, better
 * approaches exists. These are not explored now.
 * 
 * The module need to know the system clock frequency, and also the
 * target bitrate. A parameter is also present to control the accuracy
 * of the solution. Assume we generate a bit clock that is 2% off
 * target when a bit is transmitted. The error accumulates over the
 * startbit, the 8 data bits, and the stop bit. Hence the accumulated
 * error will be 10*2 = 20 % of a bit period. This is usually
 * acceptable. In theory one could accept up to a 99% error over a 10
 * bit period, but that won't work. It is recommended to keep this
 * parameter below 30, it is probably no use to decrease it below 6.
 * 
 */

module prediv_m
  #( parameter SYSCLKFRQ = 12000000, /* System Clock Frequency in Hz */
     BITCLKFRQ = 115200, /*             Bit Clock Frequency in Hz    */
     ACCEPTEDERROR_IN_PERCENT = 20  /*  How accurate must we be?     */
     ) (
        input  clk,cte1,
        output ce,prediv_m_dummy
        );
   localparam real    F_IDEALPREDIVIDE = SYSCLKFRQ / (BITCLKFRQ*8.0);
   localparam integer PREDIVIDE = (2*SYSCLKFRQ+1) / (BITCLKFRQ*8*2); // What are rules of rounding in Verilog? Truncate?
   localparam real    RESULTING_BITFRQ = SYSCLKFRQ / (PREDIVIDE*8.0);
   localparam real    REL_ERR = RESULTING_BITFRQ > BITCLKFRQ ?
                      (RESULTING_BITFRQ - BITCLKFRQ)/BITCLKFRQ :
                      (BITCLKFRQ - RESULTING_BITFRQ)/BITCLKFRQ;
   localparam real    REL_ERR_OVER_FRAME_IN_PERCENT = REL_ERR * 10 * 100;
   localparam integer PREDIVIDE_m1 = PREDIVIDE - 1; 
   
   /* A worked example. Assume SYSCLKFRQ = 4000000 Hz, BITCLKFRQ = 9600
    *
    * F_IDEALPREDIVIDE = 52.08
    * PREDIVIDE = 52
    * RESULTING_BITFRQ = 9615.4
    * REL_ERR = 0.0026
    * REL_ERR_OVER_FRAME_IN_PERCENT = 1.6
    * 
    * I arrange for the predivider to be a counter that uses the carry
    * chain. The final carry out is registered, and this is the result
    * of the prescaler. For simplicity the predivider is a down-counter.
    * Slightly less use of routing resources is possible if I had made
    * an up-counter instead. This is not done to let debugging be
    * simpler. 
    * 
    * Work. During simulation, pay attention to corner-cases. Loading of 0
    * count length multiple of (1<<x), etc.
    */

   assign prediv_m_dummy = cte1 | clk; // Vanity: Avoid a warning
   generate
      if ( (REL_ERR_OVER_FRAME_IN_PERCENT > ACCEPTEDERROR_IN_PERCENT)
           || (PREDIVIDE_m1 < 0)
           || (PREDIVIDE_m1 > 16'hffff) ) begin : blk0
         AssertModule #(.FOBAR(-1000)) ChangeClockSolution();
      end

      if ( PREDIVIDE_m1 == 0 ) begin
         assign ce = 1'b1; // No prescaler needed. 
      end else begin
         genvar             j;
         wire [15:0]        cy,c_cnt,r_cnt;
         assign cy[0] = 0;
         for ( j = 0; PREDIVIDE_m1 >> j; j = j + 1 ) begin
            localparam b = (PREDIVIDE_m1 >> j);
            localparam v = 16'h4114 + ((b&1)? 16'haaaa : 0);
            
            SB_LUT4  #(.LUT_INIT(v))
            i_cnt( .O(c_cnt[j]), .I3(cy[j]), .I2(r_cnt[j]), .I1(cte1), .I0(ce));
            SB_CARRY carry( .CO(cy[j+1]),.CI(cy[j]),.I1(r_cnt[j]), .I0(cte1));
            SB_DFF cnt_inst( .Q(r_cnt[j]), .C(clk), .D(c_cnt[j]) );
         end
         SB_LUT4 #(.LUT_INIT(16'h000f)) 
         cmb_tc( .O(c_tc), .I3(cy[j]), .I2(r_tc), .I1(1'b0),  .I0(1'b0));
         SB_DFF reg_tc( .Q(r_tc), .C(clk), .D(c_tc));
         assign ce = r_tc;
      end
   endgenerate
endmodule

//////////////////////////////////////////////////////////////////////////////
// Strange but true - Verilog 2001 do not have compile time assert.
// This solution is not good enough, it does not lead to a fatal error
// during compile. Work to do.
module AssertModule
  #( parameter FOBAR = 1 )
  ( input AssertFailed,
    output [FOBAR:0] AssertKluge);
   assign AssertKluge = AssertFailed;
endmodule

//////////////////////////////////////////////////////////////////////////////
// 12 LogicCells. See documentation at end of file.  pp is to be
// connected to a pad with INVERTED output. This way uart transmit
// will go to inactive during power-up.
module uarttx_m
   (
    input       clk,cte1,load,loadORtxce,
    input [7:0] d,
    output      txpin, // To be connected to a pad with INVERTED output.
    output      txbusy
    );
   genvar       i;
   wire         c_txbusy,c_pp;
   wire [9:0]   c_a,a;
   wire [10:1]  cy;

   // Sentinel bit ff <= load | ff*~txce (aka a9)
   SB_LUT4 #(.LUT_INIT(16'haaaa))
   ff_i(.O(c_a[9]), .I3(1'b0), .I2(1'b0), .I1(1'b0), .I0(load));
   SB_DFFE ff_r( .Q(a[9]), .C(clk), .E(loadORtxce), .D(c_a[9]));
   
   // Shift register with parallel load. Zerodetect in carrychain
   generate
      for ( i = 0; i < 9; i = i + 1 ) begin : blk
         if ( i == 0 ) begin
            SB_LUT4 #(.LUT_INIT(16'h55cc))
            shcmb( .O(c_a[i]), .I3(load), .I2(cte1), .I1(a[i+1]), .I0(1'b0));
            SB_CARRY shcy(.CO(cy[i+1]), .CI(1'b0), .I1(cte1), .I0(a[i+1]));
         end else begin
            SB_LUT4 #(.LUT_INIT(16'h55cc))
            shcmb( .O(c_a[i]), .I3(load), .I2(cte1), .I1(a[i+1]), .I0(d[i-1]));
            SB_CARRY shcy(.CO(cy[i+1]), .CI(cy[i]), .I1(cte1), .I0(a[i+1]));
         end
         SB_DFFE r( .Q(a[i]), .C(clk), .E(loadORtxce), .D(c_a[i]));
      end
   endgenerate

   // Transmit busy: txbusy <= load | ( ~load & |a[9:1]) | (~load&~txce&txbusy)
   // Carry is transported unchanged across this LUT
   SB_LUT4 #(.LUT_INIT(16'hffaa))
   txbusy_i( .O(c_txbusy), .I3(cy[9]), .I2(cte1), .I1(1'b0), .I0(load));
   SB_CARRY msbcy( .CO(cy[10]), .CI(cy[9]), .I1(cte1), .I0(1'b0));
   SB_DFFE txbusy_r( .Q(txbusy), .C(clk), .E(loadORtxce), .D(c_txbusy));
   
   // Synchronizer stage: pp <= load*pp | ~load*txce&cy10*a0 | ~load&~txce&pp
   SB_LUT4 #(.LUT_INIT(16'hb888))
   pp_i( .O(c_pp), .I3(cy[10]), .I2(a[0]), .I1(load), .I0(txpin));
   SB_DFFE pp_r( .Q(txpin), .C(clk), .E(loadORtxce), .D(c_pp) );
endmodule

//////////////////////////////////////////////////////////////////////////////
/* 
 Want a freerunning 3-bit counter with terminal count. Terminal count
 only high one cycle. We do this with an up-counter. We also want to
 or in "load". This is the transmit clock enable.
  
 Also want a freerunning 3-bit counter, but resettable to initial
 count, and to half-full. We do this with an upcounter. This is the
 receive clock enable.
 
 rxstate[0] -- I0                         __              
 rxstate[1] -- I1   ce & (cy | HUNT)  ---|  |-- rxce      
 ce  --------- I2                        >__|             
        +----- I3
        |                                 
      /cy\                               cnt is an up-counter
 rst4--(((---- I0                         __    
 rst --+((---- I1   ~rst&(cnt2^cy)    ---|  |-- cnt2
 cnt2 --(+---- I2   | rst&rst4           >__|   
        +----- I3                               
        |                                       
      /cy\                                      
 0   --(((---- I0                         __
 rst --+((---- I1   ~rst&(cnt1^cy)    ---|  |-- cnt1
 cnt1 --(+---- I2                        >__|
        +----- I3
        |
      /cy\ 
 0   --(((---- I0                         __
 rst --+((---- I1   ~rst&(cnt0^cy)    ---|  |-- cnt0
 cnt0 --(+---- I2                        >__|
        +----- I3
        | ce
      /cy\
 load -(((---- I0  
 ce   -+((---- I1  
 ce   --(+---- I2  (cy&ce) | load = loadORtxce
        +----- I3 
        |
      /cy\                               tnt is a up-counter
 0   --(((---- I0                         __
 0   --+((---- I1        (ce^tnt2^cy) ---|  |-- tnt2  
 tnt2 --(+---- I2                        >__|
        +----- I3        
        |                
      /cy\               
 0   --(((---- I0                         __
 0   --+((---- I1        (ce^tnt1^cy) ---|  |-- tnt1
 tnt1 --(+---- I2                        >__|
        +----- I3        
        |                
      /cy\               
 0   --(((---- I0                         __
 ce  --+((---- I1        (ce^tnt0^0)  ---|  |-- tnt0
 tnt0 --(+---- I2                        >__|
        +----- I3 
        |
       gnd
  */
//////////////////////////////////////////////////////////////////////////////
module rxtxdiv_m
  (
   input       clk,ce,rst8,rst4,load,
   input [1:0] rxstate,
   output      loadORtxce,rxce
   );
   wire [2:0] c_tnt,tnt,c_cnt,cnt;
   wire [7:1] cy;
   wire       c_rxce;
   
   SB_LUT4 #(.LUT_INIT(16'hc33c)) 
   i_tnt0(.O(c_tnt[0]),       .I3(1'b0),  .I2(tnt[0]), .I1(ce), .I0(1'b0));
   SB_CARRY i_cy0(.CO(cy[1]), .CI(1'b0),  .I1(tnt[0]), .I0(ce));
   SB_DFF reg0( .Q(tnt[0]), .C(clk), .D(c_tnt[0]));
   SB_LUT4 #(.LUT_INIT(16'hc33c)) 
   i_tnt1(.O(c_tnt[1]),       .I3(cy[1]), .I2(tnt[1]), .I1(ce), .I0(1'b0));
   SB_CARRY i_cy1(.CO(cy[2]), .CI(cy[1]), .I1(tnt[1]), .I0(ce));
   SB_DFF reg1( .Q(tnt[1]), .C(clk), .D(c_tnt[1]));
   SB_LUT4 #(.LUT_INIT(16'hc33c)) 
   i_tnt2(.O(c_tnt[2]),       .I3(cy[2]), .I2(tnt[2]), .I1(ce), .I0(1'b0));
   SB_CARRY i_cy2(.CO(cy[3]), .CI(cy[2]), .I1(tnt[2]), .I0(ce));
   SB_DFF reg2( .Q(tnt[2]), .C(clk), .D(c_tnt[2]));
   
   SB_LUT4 #(.LUT_INIT(16'hfaaa)) 
   i_tnt3(.O(loadORtxce),     .I3(cy[3]), .I2(ce    ), .I1(ce), .I0(load));
   SB_CARRY i_cy3(.CO(cy[4]), .CI(cy[3]), .I1(ce    ), .I0(ce));

   SB_LUT4 #(.LUT_INIT(16'h8bb8)) 
   i_cnt0(.O(c_cnt[0]),       .I3(cy[4]), .I2(cnt[0]), .I1(rst8), .I0(1'b0));
   SB_CARRY i_cy4(.CO(cy[5]), .CI(cy[4]), .I1(cnt[0]), .I0(rst8));
   SB_DFF reg4( .Q(cnt[0]), .C(clk), .D(c_cnt[0]));
   SB_LUT4 #(.LUT_INIT(16'h8bb8)) 
   i_cnt1(.O(c_cnt[1]),       .I3(cy[5]), .I2(cnt[1]), .I1(rst8), .I0(1'b0));
   SB_CARRY i_cy5(.CO(cy[6]), .CI(cy[5]), .I1(cnt[1]), .I0(rst8));
   SB_DFF reg5( .Q(cnt[1]), .C(clk), .D(c_cnt[1]));
   SB_LUT4 #(.LUT_INIT(16'h8bb8)) 
   i_cnt2(.O(c_cnt[2]),       .I3(cy[6]), .I2(cnt[2]), .I1(rst8), .I0(rst4));
   SB_CARRY i_cy6(.CO(cy[7]), .CI(cy[6]), .I1(cnt[2]), .I0(rst8));
   SB_DFF reg6( .Q(cnt[2]), .C(clk), .D(c_cnt[2]));

   SB_LUT4 #(.LUT_INIT(16'hf010))
   i_cnt3(.O(c_rxce), .I3(cy[7]), .I2(ce), .I1(rxstate[1]), .I0(rxstate[0]));
   SB_DFF regrxce( .Q(rxce), .C(clk), .D(c_rxce));
endmodule

//////////////////////////////////////////////////////////////////////////////
// 6 logic cells. See comment near end of file.
module uartrxsm_m
  (
   input        clk,rxce,rxpin,lstbit,
   output       c_byterx,c_bitcntld,c_halfbitcntld,c_ishift,
   output [1:0] rxstate
   ); 
   wire [1:0]   stnxt,st;
   
   SB_LUT4 #(.LUT_INIT(16'h3f40))
   stnxt1_i( .O(stnxt[1]), .I3(st[1]), .I2(st[0]), .I1(rxce), .I0(rxpin));
   SB_LUT4 #(.LUT_INIT(16'h8000))
   bytercvd_i( .O(c_byterx), .I3(st[1]), .I2(st[0]), .I1(rxce), .I0(rxpin));
   SB_LUT4 #(.LUT_INIT(16'h0040))
   initshiftreg_i( .O(c_ishift), .I3(st[1]), .I2(st[0]), .I1(rxce),.I0(rxpin));
   SB_LUT4 #(.LUT_INIT(16'h0cc5))
   bitcntld_i( .O(c_bitcntld), .I3(st[1]), .I2(st[0]), .I1(rxce), .I0(rxpin));
   SB_LUT4 #(.LUT_INIT(16'hcb0f))
   halfld_i(.O(c_halfbitcntld), .I3(st[1]), .I2(st[0]), .I1(rxce),.I0(lstbit));
   SB_LUT4 #(.LUT_INIT(16'h0009))
   stnxt0_i( .O(stnxt[0]), .I3(c_byterx), .I2(c_ishift), 
             .I1(c_bitcntld), .I0(c_halfbitcntld));
   SB_DFF r_st0( .Q(st[0]), .C(clk), .D(stnxt[0]));
   SB_DFF r_st1( .Q(st[1]), .C(clk), .D(stnxt[1]));
   assign rxstate = st;   
endmodule

//////////////////////////////////////////////////////////////////////////////
// Should be 8+8+6 = 22 logic cells when HASRXBYTEREGISTER == 1
// Should be   8+6 = 14 logic cells when HASRXBYTEREGISTER == 0
module uartrx_m
  # (parameter HASRXBYTEREGISTER = 0 )
   (
    input        clk,rxce,rxpin,
    output       bytercvd,rst8,rst4,
    output [1:0] rxstate,
    output [7:0] q
    );
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 c_bitcntld;             // From rxsm of uartrxsm_m.v
   wire                 c_byterx;               // From rxsm of uartrxsm_m.v
   wire                 c_halfbitcntld;         // From rxsm of uartrxsm_m.v
   wire                 c_ishift;               // From rxsm of uartrxsm_m.v
   // End of automatics
   
   uartrxsm_m rxsm(// Inputs
                   .lstbit( v[0] ),
                   /*AUTOINST*/
                   // Outputs
                   .c_byterx            (c_byterx),
                   .c_bitcntld          (c_bitcntld),
                   .c_halfbitcntld      (c_halfbitcntld),
                   .c_ishift            (c_ishift),
                   .rxstate             (rxstate[1:0]),
                   // Inputs
                   .clk                 (clk),
                   .rxce                (rxce),
                   .rxpin               (rxpin));
   genvar        i;
   wire [7:0]    c_sh;
   wire [8:0]    v;
   assign v[8] = rxpin;
   generate
      for ( i = 0; i < 8; i = i + 1 ) begin : blk
         SB_LUT4 #(.LUT_INIT(16'hef40))
         sh( .O(c_sh[i]), .I3(v[i]), .I2(rxstate[1]), .I1(rxstate[0]), .I0(v[i+1]));
         if ( i == 7 ) begin
            SB_DFFESS shreg( .Q(v[i]), .C(clk), .S(c_ishift), .E(rxce), .D(c_sh[i]) );
         end else begin
            SB_DFFESR shreg( .Q(v[i]), .C(clk), .R(c_ishift), .E(rxce), .D(c_sh[i]) );
         end
      end

      if ( HASRXBYTEREGISTER ) begin
         wire [7:0] c_h,bytereg;
         for ( i = 0; i < 8; i = i + 1 ) begin : blk2
            SB_LUT4 #(.LUT_INIT(16'hcaca))
            bt(.O(c_h[i]),.I3(1'b0),.I2(c_byterx), .I1(v[i]), .I0(bytereg[i]));
            SB_DFF regbyte( .Q(bytereg[i]), .C(clk), .D(c_h[i]));            
         end
         assign q = bytereg;
      end else begin
         assign q = v;
      end
   endgenerate

   assign rst4 = c_halfbitcntld;
   assign rst8 = c_bitcntld;
   assign bytercvd = c_byterx;
endmodule

/* 
 The transmit part:
 ------------------
 The advantage of this solution is that we avoid to rely on a
 cascaded LUT. Cascaded LUT is handled suboptimally by the lattice import
 tool, that adds a THRU_lut. The disadvantage is that clock enable
 exceeds 8 cells, hence will be used in two PLBs. As a consequence
 there are 4 logic cells where the FF has loadORtxce as clock enable,
 rendering these usable (but the LUTs can be used of course).
 
loadORtxce -------------------+
load                _____     |
    +--------------|I0   |    |   ___                     
    |          ----|I1   |----(--|   |---+ ff (aka a9) ff <= load | ff*~txce
    |          ----|I2   |    |  >   |                   
    |          ----|I3___|    +--|CE_|                   
    |  +----------------------(----------+
    |  | pp         _____     |          |
    |  +-----------|I0   |    |   ___    |
    +--------------|I1   |----(--|   |---+---|>o--[x]     
 +--(--------------|I2   |    |  >   |     pp <= load*pp | ~load*txce&cy10*a0 
 |  |          +---|I3___|    +--|CE_|           | ~load&~txce&pp
 |  |          |cy10          |            cy10 = cy9
 |  |       /cy\              |
 |  |        |||    _____     |
 |  +--------(((---|I0   |    |   ___                     
 |  |    0 --+((---|I1   |----(--|   |---+ txbusy <= load | ~load*txce*cy9 | 
 |  |    1 ---+(---|I2   |    |  >   |               ~load&~txce&txbusy
 |  |          +---|I3___|    +--|CE_|
 |  |          |cy9           |            cy9 =  a1 | a2 | a3 | a4 | a5 | 
 |  |       /cy\              |                   a6 | a7 | a8 | a9
 |  |        |||    _____     |                           
 |  |    d7 -(((---|I0   |    |   ___                     
 |  |    ff -+((---|I1   |----(--|   |---+ a8 <= load&~d7 | ~load&txce&ff | 
 |  |    1  --+(---|I2   |    |  >   |   |       ~load&~txce&a8   
 |  +----------(---|I3___|    +--|CE_|   | cy8 = a1 | a2 | a3 | a4 | a5 | 
 |  |          |cy8           |          |       a6 | a7 | a8               
 |  |  +-------(--------------(----------+ a7 <= load&~d6 | ~load&txce&a8 | 
 :  :  :       :              :                  ~load&~txce&a7
 :  :  :       :              :            a6 <= load&~d5 | ~load&txce&a7 | 
 |  |  |    /cy\              |                  ~load&~txce&a6 
 |  |  |     |||    _____     |            a5 <= load&~d4 | ~load&txce&a6 | 
 |  |  | d1 -(((---|I0   |    |   ___            ~load&~txce&a5            
 |  |  +-----+((---|I1   |----(--|   |---+ a4 <= load&~d3 | ~load&txce&a5 | 
 |  |    1 ---+(---|I2   |    |  >   |   |       ~load&~txce&a4            
 |  +----------(---|I3___|    +--|CE_|   | a3 <= load&~d2 | ~load&txce&a4 | 
 |  |          |cy2           |          |       ~load&~txce&a3               
 |  |  +-------(--------------(----------+ a2 <= load&~d1 | ~load&txce&a3 |
 |  |  |    /cy\              |                  ~load&~txce&a2
 |  |  |     |||    _____     |            cy2 = a1 | a2
 |  |  | d0 -(((---|I0   |    |   ___                     
 |  |  +-----+((---|I1   |----(--|   |---+ a1 <= load&~d0 | ~load&txce&a2 | 
 |  |    1 ---+(---|I2   |    |  >   |   |       ~load&~txce&a1
 |  +----------(---|I3___|    +--|CE_|   |                
 |  |          |              |          | cy1 = a1
 |  |  +-------(--------------(----------+
 |  |  |    /cy\              |          
 |  |  |     |||    _____     |                          
 |  |  |     ||| 0-|I0   |    |   ___                    
 |  |  +-----+((---|I1   |----(--|   |---+ bb <= load | ~load&txce&a0 | 
 |  |    1 ---+(---|I2   |    |  >   |   |       ~load&~txce&bb (aka a0)
 |  +----------(---|I3___|    +--|CE_|   |
 |             |                         |
 |            gnd                        |
 +---------------------------------------+
                load
                |txce
 STATE          || cy9  NEXT_STATE
 txbusy         || |    txbusy        At_pin
 |aaaaaaaaaap   || |    |aaaaaaaaaap  |
 |9876543210p   || |    |9876543210p  |  Comment
 000000000000   00 0    000000000000  1  At Power on. Idle/Framebit
                01 0    000000000000  1  
                1x 0    11hgfedcba10  1  Loading from Idle
 11hgfedcba10   00 1    11hgfedcba10  1  
                01 1    101hgfedcba1  0  
 101hgfedcba1   00 1    101hgfedcba1  0  
                01 1    1001hgfedcba  A  
 1001hgfedcba   00 1    1001hgfedcba  A  
                01 1    10001hgfedcb  B  
 10001hgfedcb   00 1    10001hgfedcb  B  
                01 1    100001hgfedc  C  
 100001hgfedc   00 1    100001hgfedc  C  
                01 1    1000001hgfed  D  
 1000001hgfed   00 1    1000001hgfed  D  
                01 1    10000001hgfe  E  
 10000001hgfe   00 1    10000001hgfe  E  
                01 1    100000001hgf  F  
 100000001hgf   00 1    100000001hgf  F  
                01 1    1000000001hg  G  
 1000000001hg   00 1    1000000001hg  G  
                01 1    10000000001h  H  
 10000000001h   00 0    10000000001h  H  
                01 0    000000000000  1  Transition into Idle/Framebit
 1000000000x0   10 0    11hgfedcba10  1  Erronous load
 1000000000x1   10 0    11hgfedcba11  0  Erronous load
 1yyyyyyyyyx0   10 1    11hgfedcba10  1  yyyyyyyyy != 0. Erronous load. 
 1yyyyyyyyyx1   10 1    11hgfedcba11  0  yyyyyyyyy != 0. Erronous load. 
 00000000001x   00 0    00000000001x  X  In unreachable state.
                01 0    000000000000  1  Exit from unreachable state (to idle)
                1x 0    11hgfedcba10  1  Exit from unreach. state (to loaded)
 000000000001   00 0    000000000001  0  In unreachable state
                01 0    000000000000  1  Exit from unreachable state (to idle)
                1x 0    11hgfedcba10  1  Exit from unreach. state (to loaded)

 ============================================================================= 
Reception. State machine
 
              Inputs                                       State encoding:   
         +----rxce                                         HUNT  00          
         |+---rxpin          Outputs                       ARMED 01          
         ||+--lastbit +----- ByteReceived                  RCV   10          
         |||          |+---- Initshiftreg                  GRACE 11          
         |||          ||+--- rst8
         |||  Nrcy    |||+-- rst4
 State   |||  State   ||||   Comment
 -------------------------------------------------
 HUNT    x1x  HUNT    00xx
         x0x  ARMED   0011
 ARMED   0xx  ARMED   000x
         10x  RCV     0110
         11x  HUNT    00xx   False start bit
 RCV     0xx  RCV     000x
         1x0  RCV     0010
         1x1  GRACE   0011
 GRACE   0xx  GRACE   000x
         10x  HUNT    00xx   Frame bit not right, reject byte
         11x  HUNT    10xx
 
 s[1:0]
 ||+---rxce   ByteReceived
 |||+--rxpin  |InitShiftreg   
 ||||+-lastbit||rst8
 |||||  Nxt   |||Rst4
 BAEDC        dcba
 00x1x  00   .0001
 00x0x  01   .0011
 010xx  01   .0000
 0110x  10   .0110
 0111x  00   .0010
 100xx  10   .0001
 101x0  10   .0010
 101x1  11   .0011
 110xx  11   .0000
 1110x  00   .0001
 1111x  00   .1001
  
 Nxt[1]             =  BAED==0110 | BAED == 10xx | BAED == 110x 
 ByteReceived       =  BAED==1111 
 InitShiftreg       =  BAED==0110
 rst8   =  BAED==00x0   | BAED == 011x | BAED == 101x 
 Rst4   =  BAEC==00xx   | BAEC == 100x | BAEC == 1011 | BAEC == 111x 
 Nxt[0] =  dcba == 0011 | dcba == 0000 
 
 Shift shift register right in state RCV.  
 When initshiftreg == 1, load sh[7:0] == 0x80
  
 6 LUT solution.

              Inputs                                       State encoding:   
         +----rxce                                         HUNT  00          
         |+---rxpin          Outputs                       ARMED 01          
         ||+--lastbit +----- ByteReceived                  RCV   10          
         |||          |+---- Initshiftreg                  GRACE 11          
         |||          ||+--- rst8
         |||  Nrcy    |||+-- rst4
 State   |||  State   ||||   Comment
 -------------------------------------------------
 HUNT    x1x  HUNT    0001
         x0x  ARMED   0011   rst8/rst4 actually used
 ARMED   0xx  ARMED   0000
         10x  RCV     0110   rst8/rst4 actually used
         11x  HUNT    0010   False start bit
 RCV     0xx  RCV     0001
         1x0  RCV     0010   rst8/rst4 actually used
         1x1  GRACE   0011   rst8/rst4 actually used
 GRACE   0xx  GRACE   0000
         10x  HUNT    0001   Frame bit not right, silently reject byte
         11x  HUNT    1001
   
bytereceived ---------------------------------+--------------------- to INTF0
initshiftreg ------------------+              |
rxce         ----------------+ |              |
                      ____   | |              |    _____         
rxpin ---------------|    |  | |  __          +---|-+   |   _    
r_state[0] --+-------|    |--(-(-|  |--+------(---|-|1\_|__| |__ ___ d[7]
r_state[1] --(-+-----|    |  | | >  |  |      | +-| |0/ |  >_|  |
             | | +---|____|  | +-S  |  |      | | |_____|       |
             | | |           +-(-CE_|  |      | +---------------+
             | | +-----------(-(-------+      |
             | | |    ____   | |              |    _____         
             | | +---|    |  | |  __          +---|-+   |   _    
             +-(-----|    |--(-(-|  |--+------(---|-|1\_|__| |__ ___ d[6]
             | +-----|    |  | | >  |  |      | +-| |0/ |  >_|  |
             | | +---|____|  | +-R  |  |      | | |_____|       |
             | | |           +-(-CE_|  |      | +---------------+
             | | +-----------(-(-------+      |
             | | |           | |              |
             : : :           | :              :
             | |             |                |
             | | |    ____   | |              |    _____         
             | | +---|    |  | |  __          +---|-+   |   _    
             +-(-----|    |--(-(-|  |--+------(---|-|1\_|__| |__ ___ d[1]
             | +-----|    |  | | >  |  |      | +-| |0/ |  >_|  |
             | | +---|____|  | +-R  |  |      | | |_____|       |
             | | |           +-(-CE_|  |      | +---------------+
             | | +-----------|-(-------+      |
             | | |    ____   | |              |    _____
             | | +---|    |  | |  __          +---|-+   |   _
             +-(-----|    |--(-(-|  |--+----------|-|1\_|__| |__ ___ d[0]
               +-----|    |  | | >  |  |        +-| |0/ |  >_|  |
                 +---|____|  | +-R  |  |        | |_____|       |
                 |           +---CE_|  |        +---------------+
                 +---------------------+---------------------------- lastbit
                                                Extra resources - 
                                                can free up the carry
                                                chain by using CE
                                                to these registers.
 Example for 12MHz clock, 115200:
  6 LogicCells for rx state machine and control
 16 LogicCells for receive bit shiftregister and byte holding register.
 12 LogicCells for transmit part
     5 Prescaler /13 to get to 923 kHz
     4 txce counter 8
     4 rxce counter 8/4  115.385 bps, 1.6% error over a byte
                         needs a 14.1% eye-opening minimum.
 13    for bit clocks
 --------
 47 LogicCells total.
 39 LogicCells minimal version. Read no later than after 52 cycles.
 
 Exampler for 12MHz clock, 9600
  6 LogicCells for rx state machine and control
 16 LogicCells for receive bit shiftregister and byte holding register.
 12 LogicCells for transmit part
     9  Prescaler /156 to get 76.923 kHz 
     4  txce counter 8
     4  rxce counter 8/4  9615 bps, 1.6% error over a byte
 17     for bit clocks
 -------------
 51 LogicCells total
 43 LogicCells minimal. Read no later than after 625 cycles.
 
 Example to establish the worst case I can think anyone would attempt.
 Assume a 270 MHz clock, want 2400 bps.
  6 LogicCells for rx state machine and control
 16 LogicCells for receive bit shiftregister and byte holding register.
 12 LogicCells for transmit part
    15  Prescaler /14062 to get a 192001 Hz clock enable (1 cycle)
     4  txce counter 8
     4  rxce counter 8/4  2400 bps, 0.04% error over a byte.
 23     for bit clocks
 -------------
 57 LogicCells total

 Minimum solution for this way to construct the counters:
 Assume system clock is 8 times bitrate:
  6 LogicCells for rx state machine and control
 16 LogicCells for receive bit shiftregister and byte holding register.
 12 LogicCells for transmit part
     0  Prescaler
     4  txce counter 8
     4  rxce counter 8/4  9615 bps, 1.6% error over a byte
  8     for bit clocks
 -------------
 42 LogicCells total
 
 The shift register is only shifted during reception, and is otherwise
 only changed when the receive state machine goes from ARMED to
 RCV. Logic using the receiver will know a byte is received when the
 receive state machine goes from GRACE to HUNT. The implication is
 that we are guaranteed that a received byte stay unmodified for 1/8 +
 1/2 bit time. If it can be guaranteed that the *shiftregister* can be
 read in this time, we can remove the parallel holding register, and
 save 8 LogicCells. An example: At 12MHz, 115200 has a bit time of 104
 cycles. 1/8 bit time is 13 cycles, 1/2 bit time is 52 cycles.
 
 Interrupt response of a slow Epick must then be better than
 (13+52-2-10)/2 = 26 instructions, which should not be difficult to
 acheive. Of cause, with a byte buffer we have 1041 clock cycles, 520
 instructions, to react.
 
 example1_ISR:; ISR with read into a circular buffer
     bcf     INTCON,4 ;  Clear (the only) interrupt source
 ;                    ;  FSR W   wbufferptr
     swp     RXPTR    ;  fsr p   W
     swp     FSR      ;  p   fsr W
     trg     IND      ;
     movf    P11      ;  Read happens after 10 cycles in ISR 
     incf    FSR      
     bcf     FSR,3    ;  Ptr postinc wrap in 8 byte buffer aligned 
     swp     FSR      ;  fsr p   W                  to adr 0bxxxxx0ooo
     swpret  RXPTR    ;  fsr W   p

example2_ISR: ; Simple ISR, with only one byte receive buffer.
     bcf     INTCON,4   ; Clear (the only) interrupt source
     incf    RXSTATUS   ; Flag received byte
     trg     RXSTORE
     movfret P11        ; RXSTORE = P11, return

 To transmit:
     movwf   P11
 
 To receive:
 RxRut:
     movw    RXSTORE
     decfret RXSTATUS

 To test if anything to read:
     movfsz  RXSTATE
     jmp     HasByte
     jmp     RxIsEmpty
 
 To test if transmit buffer free:
     btfss   INTCON,1
     jmp     TxIsNotEmpty
     jmp     TxIsEmpty
*/
// Local Variables:
// verilog-library-directories:("." "./fromrefdesign/" )
// verilog-library-files:("../../PROJ/iCE_simlib/iCE_simlib.v" )
// verilog-library-extensions:(".v" )
// End:
