//////////////////////////////////////////////////////////////////////////////
/* 
 * ice_uart40 features
 * -------------------
 * o Specifically written for iCE40
 * o Small footprint
 *   - 32 logicCells, prescaler excluded
 *   - Total size, prescaler included, is usually less than 42 
 *     logicCells
 *   - Byte receive buffer can be included for convenience, at a 
 *     cost of 8 additional logicCells
 *   - Absolute maximum total size is 55 logicCells
 * o Format is hardcoded: 8 data bits, no parity, one stop bit (8N1)
 * o Bitrate is hardcoded via parameters
 * o Simple to interconnect
 * o Works with any relationship between clock frequency and bitrate,
 *   as long as the clock rate is at least 16 times the bitrate
 * o Works for many combinations of clock rate and bit rate even when
 *   the clock rate is between 8 and 16 times the bitrate
 * 
 * Usage
 * -----
 * o Input rxpin is intended to originate from a physical pin, but can
 *   come from anywhere. This input must have been synchronized to the
 *   clock domain used by the uart.
 * o Output txpin is intended to be connected to a physical pin,
 *   where the output is *inverted*. The output of the uart is
 *   constructed this way to avoid a false transmit at power-on.
 *   txpin can really be used anywhere, but please remember to 
 *   invert it. The reason for this choice is that iCE40 always initiate
 *   ff's to 0 at power-on reset.
 * o When status output txbusy is low, a new byte can be transferred,
 *   use "d[7:0]" for the data, qualify with "load".  txbusy goes high
 *   the cycle the transmit shift register is loaded, and goes low at 
 *   the start of the stop bit.
 * o If status output bytercvd is high (NB:one cycle only), a byte has
 *   been received, and can be read from q[7:0]. The bytercvd output
 *   is intended to be used to set an interrupt flag.
 *   - If data is read from the shift register, it can be latched to
 *     other units qualified by bytercvd. In case a new byte is received
 *     back-to-back, the shift register must be latched before a period of
 *     5/8 bit times has passed, otherwise the shift register contents may
 *     be lost.  
 *   - If data is read from the optional 8-bit holding register, it
 *     can be latched to other units from the clock cycle following
 *     bytercvd high. The holding register must be read before a
 *     complete new byte has been received, available time is a few
 *     clock cycles short of 10 bit times.
 * o There is no checks on overrun of the receive buffer.
 * o There is no check on write collisions of transmit.
 * o Parameters
 *   - SYSCLKFRQ is the system clock frequency in Hz. It must be stated
 *     in order to construct a correct bit clock prescaler.
 *   - BITCLKFRQ is the speed of the uart serial operation in Hz. It
 *     must be stated in order to construct the prescaler.
 *   - HASRXBYTEREGISTER is a switch. When true, the received
 *     byte is written to a 8-bit holding register, and can be
 *     read at relative leasure, while the receiver shift register
 *     is busy receiving the next byte. If HASRXBYTEREGISTER is false 
 *     the received byte is read directly from the shift register.
 *     In that case 8 logic cells are saved, but the received byte must
 *     be read in less than 5/8 bit transfer time. Default value for
 *     HASRXBYTEREGISTER is 0.
 *   - ACCEPTEDERROR_IN_PERCENT determine if it is possible to reach a
 *     required quality on the actual bitrate compared to the desired
 *     bitrate. In itself, this solution samples the receive line 8
 *     times in a bit period. Hence, inherently, there is a 12.5%
 *     uncertainty in the determination on where a startbit really
 *     starts.  This uncertainty comes in addition to the error traced
 *     by this parameter. Because a prescaler will normaly not be
 *     perfect, the sampling time of each bit is either leading or
 *     lagging, and the error accumulates over the startbit, the data
 *     bits, and the frame bit. This parameter sets a limit to how far
 *     the error is allowed to drift.
 * o Tolerances
 *   - This uart use a 8 times oversampling. Inherent to that decission
 *     is a .125 UI uncertainty in deciding where a startbit starts
 *   - Worst case error due to the divisor solutions occurs when
 *     the clock frequency cfrq = 8.03125 bitfrq. To give a real 
 *     example, assume transmission happens at 115200, and the clock 
 *     frequency is 925200 Hz. We do a fractional divide of 8.0625,
 *     and acheives a bitrate of 114753 bps. The error in % for a 1-bit
 *     period is 0.39%, hence error over 10 bits is 3.9%, or 0.04 UI
 *     This is little compared with the uncertainty of the 8-times
 *     sampling, hence I assume the uart is usable for any frequency f,
 *     where f >= 7.97*b, where b is the bitrate. An example, the uart
 *     can work with 115200 as long as a clock with frequency above 
 *     918 kHz is available. 
 */ 
module uart_m
  # (parameter HASRXBYTEREGISTER = 0, // 0 : q from serial receivebuffer
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
        output       bitx8ce, //  True one clock cycle 8 times per bit
        output       bytercvd, // Status receive. True 1 bit period cycle only
        output [7:0] q //         Received byte from serial receive/byte buffer
        );
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 loadORtxce;             // From rxtxdiv_i of rxtxdiv_m.v
   wire                 rst4;                   // From rxtxdiv_i of rxtxdiv_m.v
   wire                 rxce;                   // From rxtxdiv_i of rxtxdiv_m.v
   wire [1:0]           rxst;                   // From uartrx_i of uartrx_m.v
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
      .rxst                             (rxst[1:0]),
      .q                                (q[7:0]),
      // Inputs
      .clk                              (clk),
      .rxce                             (rxce),
      .rxpin                            (rxpin));
   rxtxdiv_m
     rxtxdiv_i
     (/*AUTOINST*/
      // Outputs
      .loadORtxce                       (loadORtxce),
      .rxce                             (rxce),
      .rst4                             (rst4),
      // Inputs
      .clk                              (clk),
      .bitx8ce                          (bitx8ce),
      .load                             (load),
      .rxpin                            (rxpin),
      .rxst                             (rxst[1:0]));
   prediv_m #( .SYSCLKFRQ(SYSCLKFRQ), .BITCLKFRQ(BITCLKFRQ),
               .ACCEPTEDERROR_IN_PERCENT(ACCEPTEDERROR_IN_PERCENT))
   prediv_i
     (/*AUTOINST*/
      // Outputs
      .bitx8ce                          (bitx8ce),
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
 * can think of. When the bitrate is closer than 16 times the
 * clockrate, better approaches exists. These are not explored.    
 * The module need to know the system clock frequency, and also the
 * target bitrate. A parameter is also present to control the accuracy
 * of the solution. Assume we generate a bit clock that is 2% off
 * target when a bit is transmitted. The error accumulates over the
 * startbit, the 8 data bits, and the stop bit. Hence the accumulated
 * error will be 10*2 = 20 % of a bit period. This is usually
 * acceptable. It is recommended to keep this parameter below 30, 
 * it is probably no use to decrease it below 6.

 Special case:
 If the clock is exactly 8 times the bitrate,
 this module is not needed. bitx8ceis then set to the constant 1.
 
 Special case:
 If the clock is exactly 16 times the bitrate, bitx8ce can be
 the output of a toggle register.

 The easiest case for this module is when we want to count PREDIVIDE
 times. Let us examine the module generated when we have a 12 MHz
 clock, and want a 115200 bps uart. The prescale value is then
 13. Counting sequence will be:
 4 5 6 7 8 9 10 11 12 13 14 15 0 4 5 6 7 8 9 10 11 12 13 14 15 0
              ____     _
   0  -------| I0 |---| |----+-  r_tc <= !r_tc & cy[4];
   0  -------| I1 |   >_|    |           
     +-------| I2 |          |
     |   +---|_I3_|          |
     +---(-------------------+
       /cy\         
        |||   ____     _
   0  --(((--| I0 |---| |----+-  r_cnt[3] <= (cy[3]^r_cnt[3])&!r_tc;
r_tc  --+((--| I1 |   >_|    |               
     +---(+--| I2 |          |
     |   +---|_I3_|          |
     +---(-------------------+
       /cy\         
        |||   ____     _
   0  --(((--| I0 |---| |----+-  r_cnt[2] <= (cy[2]^r_cnt[2])&!r_tc | r_tc;
r_tc  --+((--| I1 |   >_|    |               
     +---(+--| I2 |          |
     |   +---|_I3_|          |
     +---(-------------------+
       /cy\         
        |||   ____     _
   0  --(((--| I0 |---| |----+-  r_cnt[1] <= (cy[1]^r_cnt[1])&!r_tc;
r_tc  --+((--| I1 |   >_|    |               
     +---(+--| I2 |          |
     |   +---|_I3_|          |
     +---(-------------------+
       /cy\         
        |||   ____     _
   0  --(((--| I0 |---| |----+-  r_cnt[0] <= (cy[0]^r_cnt[0])&!r_tc;
r_tc  --+((--| I1 |   >_|    |               
     +---(+--| I2 |          |
     |   +---|_I3_|          |
     +---(-------------------+
       /cy\         
         |
        vcc
 
 In the specific case where PREDIVIDE_m1 is a power of 2, we save one logicCell.
 If, for instance, PREDIVIDE is 5, we use the circuit below, and the counting
 sequence is: 0 0 1 2 3 0 0 1 2 3
 
              ____     _
   0  -------| I0 |---| |----+-  r_tc <= !r_tc & cy[4];
   0  -------| I1 |   >_|    |           
     +-------| I2 |          |
     |   +---|_I3_|          |
     +---(-------------------+
       /cy\         
        |||   ____     _
   0  --(((--| I0 |---| |----+-  r_cnt[1] <= (cy[1]^r_cnt[1])&!r_tc;
r_tc  --+((--| I1 |   >_|    |               
     +---(+--| I2 |          |
     |   +---|_I3_|          |
     +---(-------------------+
       /cy\         
        |||   ____     _
   0  --(((--| I0 |---| |----+-  r_cnt[0] <= (cy[0]^r_cnt[0])&!r_tc;
r_tc  --+((--| I1 |   >_|    |               | r_tc
     +---(+--| I2 |          |
     |   +---|_I3_|          |
     +---(-------------------+
       /cy\         
         |
        vcc
 
 Perturbation
 ------------ 

 Assume the following: A 16 MHz clock, and we want 115200 bps.  At
 first hand this seems simple, 16000000/115200=138.8 approx 139 clock
 cycles per bit time. But we need a x8 clock, and
 16000000/(115200*8)=17.36.  The closest we come directly is 17 as a
 predivider, but 16000000/(17*8)=117647, too far from 115200. This is
 disappointing - should it not be possible to transmit at 115200 when
 we have a clock that is 139 times faster? If we could count to 17.5,
 we would acheive a bitrate of 16000000/(17.5*8)=114286, acceptable. It
 is not difficult to count to 17.5, we alternately count to 17 and 18.
 
 Example 2: A 4 MHz clock, and we want 115200. Ideal prescaler is
 4000000/(8*115200)=4.34, if we count to 4 five times, and to 5 three
 times, we count on average (8*4+3)/8 = 4.375, and can realize a
 bitrate of 4000000/(4.375*8)=114.286 for an error of 7.9% over a
 frame
 
 Example 3: A 1 MHz clock, and we want 115200.
 1000000/(1.0625*8)=117647 bps, an error of 0.21 UI over a frame.
 We divide by 1 15 times, and 2 one time: (1*16+1)/16 = 1.0625.
 
 Assume we have a clock >= 8*bitrate. This is a prerequisite for this
 uart anyway. When we can perturb with a granularity of 4 bits, it
 follows that the maximum average error we can have per averaged bit period is
 (1/32)=0.03125 bit cycle. Over 10 bits this accumulates to an error
 of 0.3 UI. Because we only sample 8 times in a bit period, the required
 eye opening is around 0.3 + 0.13 = 0.43 UI.
 
 The perturbator could come in many forms, I concentrate on the
 following because the construction is regular. The perturbator
 require from 0 to 5 logicCells. Though size matters, an observation
 to make is that if several bits of perturbation is needed, the
 counter itself is correspondingly shorter.
  
                                              LogicCells
 Average     Sequence                         |  Comment_____________________
 0.000 0     0                                0  No perturbator  
 0.063 1/16  0+0+0+0+0+0+0+0+0+0+0+0+0+0+0+1  5  4-bit cnt cnt==1111
 0.125 1/8   0+0+0+0+0+0+0+1                  4  3-bit cnt cnt==111
 0.188 3/16  0+0+0+0+1+0+0+0+0+1+0+0+0+0+1+0  5  4-bit cnt cnt==0100,1001,1110
 0.250 1/4   0+0+0+1                          3  2-bit cnt cnt==3
 0.313 5/16  0+0+1+0+0+1+0+0+1+0+0+1+0+0+1+0  5  4-bit cnt cnt==...
 0.375 3/8   0+0+1+0+0+1+0+1                  4  3-bit cnt cnt==010,101,111
 0.438 7/16  0+1+0+1+0+1+0+1+0+0+1+0+1+0+1+0  5  4-bit cnt cnt==...
 0.500 1/2   0+1                              1  1-bit cnt cnt==1
 0.563 9/16  1+0+1+0+1+0+1+0+1+1+0+1+0+1+0+1  5  4-bit cnt cnt==...
 0.625 5/8   1+1+0+1+1+0+1+0                  4  3-bit cnt cnt!=010,101,111
 0.688 11/16 1+1+0+1+1+0+1+1+0+1+1+0+1+1+0+1  5  4-bit cnt cnt==...
 0.750 3/4   0+1+1+1                          3  2-bit cnt cnt!=0
 0.813 13/16 1+1+1+1+0+1+1+1+1+0+1+1+1+1+0+1  5  4-bit cnt cnt==...
 0.875 7/8   1+1+1+1+1+1+1+0                  4  3-bit cnt cnt!=111
 0.938 15/16 1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+0  5  4-bit cnt cnt==...
    
 The counter is always incremented with bitx8ce as clock enable. They
 are arranged as binary counters, but I do not use the carry chain except if the
 counter is 4 bits. We have the following variants:

 bitx8ce ----------+
       _________   |  ___
 +----| I0 |>o- |--)-|   |---+-- perturb_out
 |    |_________|  + |CE |   |
 |                   >___|   |
 +---------------------------+
 
 bitx8ce ----------+
       _________   |  ___
 +----|I0       |--)-|   |------ perturb_out
 | +--|I1       |  +-|CE |   
 | |  |_________|  | >___|   
 | |               |        
 | |   _________   |  ___
 +-(--|I0       |--)-|   |---+-- p1
 | +--|I1       |  +-|CE |   |
 | |  |_________|  | >___|   |
 | |               |         |
 | +---------------)---------+
 |     _________   |  ___
 +----| I0 |>o- |--)-|   |---+-- p0
 |    |_________|  +-|CE |   |
 |                   >___|   |
 +---------------------------+

 bitx8ce ------------+
         _________   |  ___
 +------|I0       |--)-|   |------ perturb_out
 | +----|I1       |  +-|CE |   
 | | +--|I2_______|  | >___|   
 | | |               |        
 | | |   _________   |  ___
 +-(-(--|I0       |--)-|   |---+-- p2
 | +-(--|I1       |  +-|CE |   |
 | | +--|I2_______|  | >___|   |
 | | |               |         |
 | | +---------------)---------+
 | |     _________   |  ___
 +-(----|I0       |--)-|   |---+-- p1
 | +----|I1       |  +-|CE |   |
 | |    |_________|  | >___|   |
 | |                 |         |
 | +-----------------)---------+
 |       _________   |  ___
 +------| I0 |>o- |--)-|   |---+-- p0
 |      |_________|  +-|CE |   |
 |                     >___|   |
 +-----------------------------+

 bitx8ce -0-----------+
          _________   |  ___
 +-------|I0       |--)-|   |------ perturb_out
 | +-----|I1       |  +-|CE |   
 | | +---|I2       |  | >___|   
 | | | +-|I3_______|  |        
 | | | |  _________   |  ___
 +-(-(-(-|I0       |--)-|   |---+-- p3
 | +-(-(-|I1       |  +-|CE |   |
 | | +-(-|I2       |  | >___|   |
 | | | +-|I3_______|  |         |
 | | | +--------------)---------+
 | | |    _________   |  ___
 +-(-(---|I0       |--)-|   |---+-- p2
 | +-(---|I1       |  +-|CE |   |
 | | +---|I2_______|  | >___|   |
 | | |                |         |
 | | +----------------)---------+
 | |      _________   |  ___
 +-(-----|I0       |--)-|   |---+-- p1
 | +-----|I1       |  +-|CE |   |
 | |     |_________|  | >___|   |
 | |                  |         |
 | +------------------)---------+
 |        _________   |  ___
 +-------| I0 |>o- |--)-|   |---+-- p0
 |       |_________|  +-|CE |   |
 |                      >___|   |
 +------------------------------+

 Todo. The above diagrams are not accurate, I avoid clock enable to 
 possibly get better placement. 
 */

/*
 Unfortunately the following fails in iverilog 0.9.5, which do not allow
 the genvar to be used in the local parameters and then tested upon.
 */
//module icarusfails_prediv_m
//  #( parameter SYSCLKFRQ = 12000000, /* System Clock Frequency in Hz */
//     BITCLKFRQ = 115200, /*             Bit Clock Frequency in Hz    */
//     ACCEPTEDERROR_IN_PERCENT = 20  /*  How accurate must we be?     */
//     ) (
//        input         clk, cte1,
//        output        bitx8ce
//        );
//   /* The control structures in Verilog is wanting, fortunately the
//    * accuracy of the predivider is a monotonic function.
//    */
//   genvar             j;
//   generate
//      for ( j = 0; j < 6; j = j + 1 ) begin
//         localparam integer predivide = 
//                            ((1<<j)*SYSCLKFRQ+4*BITCLKFRQ) / (8*BITCLKFRQ);
//         localparam real    bitfrq =  ((1<<j)*SYSCLKFRQ) / (predivide*8.0);
//         localparam real    err = bitfrq > BITCLKFRQ ? 
//                            (bitfrq - BITCLKFRQ)/BITCLKFRQ :
//                            (BITCLKFRQ - bitfrq)/BITCLKFRQ;
//         localparam integer next_predivide = 
//                            ((1<<(j+1))*SYSCLKFRQ+4*BITCLKFRQ)/(8*BITCLKFRQ);
//         localparam real    next_bitfrq =  
//                            ((1<<(j+1))*SYSCLKFRQ) / (next_predivide*8.0);
//         localparam real    next_err = next_bitfrq > BITCLKFRQ ? 
//                            (next_bitfrq - BITCLKFRQ)/BITCLKFRQ :
//                            (BITCLKFRQ - next_bitfrq)/BITCLKFRQ;
//         if ( (predivide < 1)
//              || (predivide >= 16'hffff) ) begin : blk0
//            Illegal_Relationship_Between_SYSCLKFRQ_and_BITCLKFRQ illegal_i();
//         end      
//         if ( j == 0 &&  err * 1000 <= ACCEPTEDERROR_IN_PERCENT) begin 
//            basic_prediv_m #( .PREDIVIDE(predivide))
//            p0_i (/*AUTOINST*/
//                  // Outputs
//                  .bitx8ce              (bitx8ce),
//                  // Inputs
//                  .clk                  (clk),
//                  .cte1                 (cte1));         
//         end else if ( (      err * 1000 >  ACCEPTEDERROR_IN_PERCENT) &&
//                       ( next_err * 1000 <= ACCEPTEDERROR_IN_PERCENT ) ) begin
//            perturbated_prediv_m #( .PERTURBATOR_NRBITS(j+1), 
//                                    .SCALEDPREDIVIDE(next_predivide) )
//            pp (/*AUTOINST*/
//                // Outputs
//                .bitx8ce                (bitx8ce),
//                // Inputs
//                .clk                    (clk),
//                .cte1                   (cte1));               
//         end
//      end
//   endgenerate
//endmodule

/////////////////////////////////////////////////////////////////////////////
module prediv_m
  #( parameter SYSCLKFRQ = 12000000, /* System Clock Frequency in Hz */
     BITCLKFRQ = 115200, /*             Bit Clock Frequency in Hz    */
     ACCEPTEDERROR_IN_PERCENT = 20  /*  How accurate must we be?     */
     ) (
        input         clk, cte1,
        output        bitx8ce
        );
   /* The control structures in Verilog is wanting, fortunately the
    * accuracy of the predivider is a monotonic function. It seems 
    * that I can't use the genvar when construction localparams, so
    * I introduce a level of indirection. This has the complication
    * that we must or together results, and tie of ungenerated results
    * to 0 in the "kluge" module
    */
   genvar             j;
   wire [5:0]         kluge_bitx8ce;
   generate
      for ( j = 0; j < 6; j = j + 1 ) begin
         prediv_kluge_m #( .ITERATION(j), 
                           .SYSCLKFRQ(SYSCLKFRQ), 
                           .BITCLKFRQ(BITCLKFRQ), 
                           .ACCEPTEDERROR_IN_PERCENT(ACCEPTEDERROR_IN_PERCENT))
         kluge (// Outputs
                .bitx8ce                (kluge_bitx8ce[j]),
                /*AUTOINST*/
                // Outputs
                .prediv_kluge_m_dummy   (prediv_kluge_m_dummy),
                // Inputs
                .clk                    (clk),
                .cte1                   (cte1));
      end
   endgenerate
   assign bitx8ce = |kluge_bitx8ce;
endmodule

/////////////////////////////////////////////////////////////////////////////
// In this module, exactly one case will result in generated code.           
module prediv_kluge_m
  #( parameter ITERATION = 0,       /* Not pretty                   */
     SYSCLKFRQ = 12000000,          /* System Clock Frequency in Hz */
     BITCLKFRQ = 115200,            /* Bit Clock Frequency in Hz    */
     ACCEPTEDERROR_IN_PERCENT = 20  /*  How accurate must we be?    */
     ) (
        input  clk, cte1,
        output bitx8ce,prediv_kluge_m_dummy
        );
   localparam integer j = ITERATION;
   localparam integer predivide = 
                      ((1<<j)*SYSCLKFRQ+4*BITCLKFRQ) / (8*BITCLKFRQ);
   localparam real    bitfrq =  ((1<<j)*SYSCLKFRQ) / (predivide*8.0);         
   localparam real    err = bitfrq > BITCLKFRQ ? 
                      (bitfrq - BITCLKFRQ)/BITCLKFRQ :
                      (BITCLKFRQ - bitfrq)/BITCLKFRQ;
   localparam integer next_predivide = 
                      ((1<<(j+1))*SYSCLKFRQ+4*BITCLKFRQ) / (8*BITCLKFRQ);
   localparam real    next_bitfrq =  
                      ((1<<(j+1))*SYSCLKFRQ) / (next_predivide*8.0);
   localparam real    next_err = next_bitfrq > BITCLKFRQ ? 
                      (next_bitfrq - BITCLKFRQ)/BITCLKFRQ :
                      (BITCLKFRQ - next_bitfrq)/BITCLKFRQ;

   // Avoid warning in Synplify
   assign prediv_kluge_m_dummy = clk | cte1;

   generate
      if ( (predivide < 1)
           || (predivide >= 16'hffff) ) begin : blk0
         Illegal_Relationship_Between_SYSCLKFRQ_and_BITCLKFRQ illegal_i();
      end      
      if ( j == 0 &&  err * 1000 <= ACCEPTEDERROR_IN_PERCENT) begin
`ifdef SIMULATION
         initial begin
            $display( "Resulting bps: %f", bitfrq );
         end
`endif         
         basic_prediv_m #( .PREDIVIDE(predivide))
         p0_i (/*AUTOINST*/
               // Outputs
               .bitx8ce                 (bitx8ce),
               .basic_prediv_m_dummy    (basic_prediv_m_dummy),
               // Inputs
               .clk                     (clk),
               .cte1                    (cte1));         
      end else if ( (      err * 1000 >  ACCEPTEDERROR_IN_PERCENT) &&
                    ( next_err * 1000 <= ACCEPTEDERROR_IN_PERCENT ) ) begin
`ifdef SIMULATION
         initial begin
            $display( "Resulting bps: %f", bitfrq );
         end
`endif         
         perturbated_prediv_m #( .PERTURBATOR_NRBITS(j+1), 
                                 .SCALEDPREDIVIDE(next_predivide) )
         pp (/*AUTOINST*/
             // Outputs
             .bitx8ce                   (bitx8ce),
             .perturbated_prediv_m_dummy(perturbated_prediv_m_dummy),
             // Inputs
             .clk                       (clk),
             .cte1                      (cte1));               
      end else begin
         assign bitx8ce = 1'b0;
      end
   endgenerate
endmodule


/////////////////////////////////////////////////////////////////////////////
module basic_prediv_m
  # (parameter PREDIVIDE=1)
   ( input clk,cte1,
     output bitx8ce,basic_prediv_m_dummy
     );
   wire     c_tc,r_tc;
   localparam PREDIVIDE_m1 = PREDIVIDE - 1;
   localparam PRED_initval = (~PREDIVIDE_m1)+1;
   
   assign basic_prediv_m_dummy = c_tc | r_tc | cte1 | clk;
   generate
      if ( PREDIVIDE_m1 == 0 ) begin
         // No prescaler needed.
         assign bitx8ce = cte1;
         // To avoid warnings in Synplify
         assign c_tc = cte1;
         assign r_tc = cte1;
      end else if ( PREDIVIDE_m1 == 1 ) begin
         // Special case, prescale by 2.0
         SB_LUT4 #(.LUT_INIT(16'h5555)) 
         cmb_tc( .O(c_tc), .I3(1'b0), .I2(1'b0), .I1(1'b0), .I0(r_tc));
         SB_DFF reg_tc( .Q(r_tc), .C(clk), .D(c_tc));
         assign bitx8ce = r_tc;         
      end else if ( (PREDIVIDE_m1 & (PREDIVIDE_m1-1)) != 0 ) begin
         // General case, PREDIVIDE_m1 is not a power of 2.
         // Code is equal with code for a perturbator with 
         // 0 bits of fractional divide
         perturbated_prediv_m #( .PERTURBATOR_NRBITS(0), 
                                 .SCALEDPREDIVIDE(PREDIVIDE))
         pp_i (/*AUTOINST*/
               // Outputs
               .bitx8ce                 (bitx8ce),
               .perturbated_prediv_m_dummy(perturbated_prediv_m_dummy),
               // Inputs
               .clk                     (clk),
               .cte1                    (cte1));
         // To avoid warnings in Synplify
         assign c_tc = cte1;
         assign r_tc = cte1;
      end else begin
         // When PREDIVIDE_m1 is a power of 2 and there is no perturbation. 
         // This code could be merged with the general case, this is not done 
         // for a semblance of clarity.
         basic_prediv_spescase_m #( .PREDIVIDE_m1(PREDIVIDE_m1))
           ppp(/*AUTOINST*/
               // Outputs
               .bitx8ce                 (bitx8ce),
               // Inputs
               .clk                     (clk),
               .cte1                    (cte1));
         // To avoid warnings in Synplify
         assign c_tc = cte1;
         assign r_tc = cte1;
      end
   endgenerate
endmodule

/////////////////////////////////////////////////////////////////////////////
module basic_prediv_spescase_m
  # (parameter PREDIVIDE_m1=2)
   ( input clk,cte1,
     output bitx8ce
     );
   wire [15:0] cy,c_cnt,r_cnt;
   wire        c_tc,r_tc;
   genvar      j;
   
   generate
      assign cy[0] = cte1;
      for ( j = 0; PREDIVIDE_m1 >> (j+1); j = j + 1 ) begin
         SB_LUT4 #(.LUT_INIT(16'h0330))
         i_cnt( .O(c_cnt[j]), .I0(1'b0),
                .I3(cy[j]),.I2(r_cnt[j]), .I1(r_tc));
         SB_CARRY carry( .CO(cy[j+1]),.CI(cy[j]),.I1(r_cnt[j]), .I0(r_tc));
         SB_DFF cnt_inst( .Q(r_cnt[j]), .C(clk), .D(c_cnt[j]) );
         if ( (PREDIVIDE_m1 >> (j+2)) == 0 ) begin
            SB_LUT4 #(.LUT_INIT(16'h0f00)) 
            cmb_tc( .O(c_tc), .I3(cy[j+1]),.I2(r_tc), .I1(1'b0),  .I0(1'b0));
            SB_DFF reg_tc( .Q(r_tc), .C(clk), .D(c_tc));
         end
      end
   endgenerate
   assign bitx8ce = r_tc;         
endmodule

/////////////////////////////////////////////////////////////////////////////
module perturbated_prediv_m
  # (parameter PERTURBATOR_NRBITS=1, SCALEDPREDIVIDE=1 )
   ( input clk,cte1,
     output bitx8ce,perturbated_prediv_m_dummy
     );
   wire [15:0] c_cnt,r_cnt;
   wire        r_tc;
   wire        r_perturb;
   wire [3:0]  r_pcnt;
   genvar      j;
   localparam integer predivide     = (SCALEDPREDIVIDE>>PERTURBATOR_NRBITS);
   localparam integer predivide_m1  = predivide-1;
   localparam integer pred_initval  = (~predivide_m1)+1;
   localparam integer pred_perturb_initval = pred_initval-1;

   assign perturbated_prediv_m_dummy = cte1;
`ifdef SIMULATION
   initial begin
      $display( "Input: Nr perturb.bits  = %d", PERTURBATOR_NRBITS);
      $display( "Input: Scaled_predivide = %d", SCALEDPREDIVIDE );
      $display( "  ..want Prescaler divide=%f", 
                SCALEDPREDIVIDE/(1.0*(1<<PERTURBATOR_NRBITS)) );
      $display( "predivide = %d", predivide );
   end
`endif

   generate
      if ( PERTURBATOR_NRBITS > 4 ) begin
         Can_not_honour_requested_accuracy illegal_perturb_i();
      end else if ( PERTURBATOR_NRBITS == 4 ) begin
         // 4-bit binary counter using a carry chain
         wire [3:0] cyp, c_pcnt;
         assign cyp[0] = 1'b1;
         for ( j = 0; j < 4; j = j + 1 ) begin : blkA
            SB_LUT4 #(.LUT_INIT(16'hd278)) cntfour
                   ( .O(c_pcnt[j]),.I3(cyp[j]), 
                     .I2(r_pcnt[j]), .I1(1'b0), .I0(r_tc));
            if ( j != 3 )
              SB_CARRY pcy
                (.CO(cyp[j+1]), 
                 .CI(cyp[j]), .I1(r_pcnt[j]), .I0(1'b0));
            SB_DFF pcntr( .Q(r_pcnt[j]), .C(clk), .D(c_pcnt[j]));
         end
      end else if ( PERTURBATOR_NRBITS > 0 ) begin
         wire [3:0] c_pcnt;
         SB_LUT4 #(.LUT_INIT(16'h6666)) pcnt_i0
           ( .O(c_pcnt[0]), .I3(1'b0), .I2(1'b0), .I1(r_tc), .I0(r_pcnt[0]));
         SB_DFF perturbreg0_i( .Q(r_pcnt[0]), .C(clk), .D(c_pcnt[0]));
         if ( PERTURBATOR_NRBITS > 1 ) begin
            SB_LUT4 #(.LUT_INIT(16'h6c6c)) pcnt_i1
              (.O(c_pcnt[1]), .I3(1'b0), .I2(r_tc), .I1(r_pcnt[1]), 
               .I0(r_pcnt[0]));
            SB_DFF perturbreg1_i( .Q(r_pcnt[1]), .C(clk), .D(c_pcnt[1]));
            if ( PERTURBATOR_NRBITS > 2 ) begin
               SB_LUT4 #(.LUT_INIT(16'h78f0)) pcnt_i2
                 (.O(c_pcnt[2]), .I3(r_tc), .I2(r_pcnt[2]), .I1(r_pcnt[1]), 
                  .I0(r_pcnt[0]));
               SB_DFF perturbreg2_i( .Q(r_pcnt[2]), .C(clk), .D(c_pcnt[2]));
               if ( PERTURBATOR_NRBITS > 4 ) begin
                  Unsupported illegalGT4_i();                  
               end
            end 
         end
      end
      // For waveform display it is nice to define bits not used in synthesis
      for ( j = PERTURBATOR_NRBITS; j < 4; j = j + 1 ) begin
         assign r_pcnt[j] = 1'b0;
      end
      if ( PERTURBATOR_NRBITS == 0 ) begin
        assign r_perturb = 1'b0;
      end else if ( PERTURBATOR_NRBITS == 1 ) begin
         assign r_perturb = r_pcnt[0];
      end else begin
         /* There is some gymnastics to select the right LUT value for
          * the perturbation. This is not made any easier by iverilog 0.9.5,
          * where we can't select out of a localparam.
          */
         localparam plutval_4
           //                4  3  2  1
           = { 16'hfffe, // 15
               16'hfefe, //     7
               16'hfbde, // 13
               16'heeee, //        3
               16'hedb6, // 11
               16'h6b6b, //     5  
               16'hd56a, //  9
               16'haaaa, //           1   Not in use
               16'h2a95, //  7
               16'h9494, //     3
               16'h1249, //  5
               16'h1111, //        1
               16'h0421, //  3
               16'h0101, //     1
               16'h0001, //  1
               16'h0000  //               Not in use
               };
         localparam inx = SCALEDPREDIVIDE & ((1<<PERTURBATOR_NRBITS)-1);
         localparam plutvalinx = inx << (4-PERTURBATOR_NRBITS);
         localparam v = (plutval_4 >> (16*plutvalinx)) & 16'hffff;
         wire cmb_perturb;
`ifdef SIMULATION
         initial begin
            $display( "inx = %d, plutvalinx = %d, v = %h",inx, plutvalinx, v );
         end
`endif
         SB_LUT4 #(.LUT_INIT(v))
         cmb_pert( .O(cmb_perturb), .I3(r_pcnt[3]), .I2(r_pcnt[2]),
                   .I1(r_pcnt[1]),.I0(r_pcnt[0]));
         SB_DFF reg_pert( .Q(r_perturb), .C(clk), .D(cmb_perturb));
      end
   endgenerate

   /*
    * The above generate took care of the perturbation. The following
    * generate takes care of the prescaler proper. 
    */
   generate
      if ( predivide_m1 == 0 ) begin
         // Special case, divide by less than 2, but perturbation needed
         // Here I must let r_tc be combinatorical, I abuse my naming.
         SB_LUT4 #(.LUT_INIT(16'h777)) spes_tc_combinatorical
           (.O(r_tc), .I3(1'b0),.I2(1'b0),.I1(r_perturb),.I0(r_cnt[0]));
         SB_LUT4 #(.LUT_INIT(16'h777)) c_msb
           (.O(c_cnt[0]), .I3(1'b0),.I2(1'b0),.I1(r_perturb),.I0(r_cnt[0]));
         SB_DFF cnt_lsb( .Q(r_cnt[0]), .C(clk), .D(c_cnt[0]));
         assign bitx8ce = r_tc;
      end else begin
         wire [15:0] cy;
         assign cy[0] = cte1;
         //for ( j = 0; predivide_m1 >> j; j = j + 1 ) begin 
         //(above replaced for nice sim display)
         for ( j = 0; 16'hffff >> j; j = j + 1 ) begin
            if ( (predivide_m1 >> j) == 0 ) begin
               assign r_cnt[j] = 0; // For waveform display in simulation
            end else begin
               wire c_tc;
               localparam bitinit_no_perturb = pred_initval >> j;
               localparam bitinit_perturb    = pred_perturb_initval >> j;
               localparam v 
                 = 16'h0330 
                   + ( (bitinit_no_perturb & 1) ? 16'h4444 : 16'h0000)
                     +  ( (bitinit_perturb & 1) ? 16'h8888 : 16'h0000);
            SB_LUT4 #(.LUT_INIT(v)) i_cnt
              ( .O(c_cnt[j]), 
                .I3(cy[j]), .I2(r_cnt[j]), .I1(r_tc), .I0(r_perturb));
               SB_CARRY carry
                 ( .CO(cy[j+1]),
                   .CI(cy[j]), .I1(r_cnt[j]), .I0(r_tc));
               SB_DFF cnt_inst( .Q(r_cnt[j]), .C(clk), .D(c_cnt[j]));
               if ( (predivide_m1 >> (j+1)) == 0 ) begin
                  SB_LUT4 #(.LUT_INIT(16'h0f00)) 
                  cmb_tc( .O(c_tc),.I3(cy[j+1]),.I2(r_tc),.I1(1'b0),.I0(1'b0));
                  SB_DFF reg_tc( .Q(r_tc), .C(clk), .D(c_tc));
               end            
            assign bitx8ce = r_tc;
            end
         end
      end
   endgenerate
endmodule



/* 
 //////////////////////////////////////////////////////////////////////////////
 The transmit part in 12 LogicCells.
 txpin is to be connected to a pad with INVERTED output. This way uart
 transmit will go to inactive during power-up.

 The main idea here is to have a 10-bit shift register. When all bits
 are shifted out, a fact we find from the carry chain, transmission is
 done. 

 We also need a FF to synchronize "load" with "txce". We could skip
 this, it would imply a 1/8 bit period uncertainty in the length of
 the start bit. Even if this uart is very spartan, I do not want to
 degrade the accuracy, so this FF stays.
 
 We also need a FF to record that the shift regiser is busy. The shift
 register is busy from the clock cycle after it is loaded, until start
 of transmit of the stop bit. For continuous transfer, a
 microcontroller is expected to hook up ~txbusy as an interrupt
 source. A new byte must then be output in 7/8 bit times. An example:
 At 12 MHz clock, 115200 bps, a new byte must be written in at most 91
 clock cycles to saturate the transmit path.
  
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
 
 The construction can be formalized as a state machine, something like:
 
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
*/
module uarttx_m
   (
    input       clk,cte1,load,loadORtxce,
    input [7:0] d,
    output      txpin, 
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
 Generating enable bits for the transmit and the receive part.
 
 Want a freerunning 3-bit counter with terminal count. Terminal count
 only high one cycle. We do this with an up-counter. We also want to
 or in "load". This is the transmit clock enable.
  
 Also want a freerunning 3-bit counter, but resettable to half-full. 
 We do this with an upcounter. This is the receive clock enable.
                                           ALWAYS USE THIS CASE 
               PREDIVIDE_m1 != 0 |                PREDIVIDE_m1 == 0:
               (rxcy & ce) |     |                ((ARMD | RECV) & rxcy & ce) |
               (GRCE & rxpin)    |                (GRCE & rxpin)              |
                                 |                (HUNT & rxpin)
               ____              |                ____             
 rxstate[0] --| I0 |  __         |  rxstate[0] --| I0 |  __        
 rxstate[1] --| I1 |-|  |- rxce  |  rxstate[1] --| I1 |-|  |- rxce 
 rxpin -------| I2 | >__|        |  rxpin -------| I2 | >__|       
        +-----|_I3_|             |         +-----|_I3_|            
        |
        | rxcy & ce   "(receive count overflow, or rst4) & bitx8ce" 
      /cy\                                      
rxst[0](((---- I0  rst4 = rxst == 2'b0
 ce ---+((--   I1  
  0 ----(+--   I2  
rxst[1]-(---   I3
        |                                 
      /cy\                               cnt is an up-counter
 0    -(((---- I0                         __    
 rst4 -+((---- I1   ~rst4&(cnt2^cy)   ---|  |-- cnt2
 cnt2 --(+---- I2   | rst4               >__|   
        +----- I3                               
        |                                       
      /cy\                                      
 rst4--(((---- I0                         __
 0   --+((---- I1   ~rst4&(cnt1^cy)   ---|  |-- cnt1
 cnt1 --(+---- I2                        >__|
        +----- I3
        |
      /cy\ 
 rst4--(((---- I0                         __
 0   --+((---- I1   ~rst4&(cnt0^ce)   ---|  |-- cnt0
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
/*
 * The dividers as described above. 
 * In addition rst4, placed here to save a LUT.
 */
module rxtxdiv_m
  (
   input       clk,bitx8ce,load,rxpin,
   input [1:0] rxst,
   output      loadORtxce,rxce,rst4
   );
   wire [2:0]  c_tnt,tnt,c_cnt,cnt;
   wire [8:1]  cy;
   wire        c_rxce;
   
   SB_LUT4 #(.LUT_INIT(16'hc33c)) 
   i_tnt0(.O(c_tnt[0]),       .I3(1'b0),  .I2(tnt[0]), .I1(bitx8ce), .I0(1'b0));
   SB_CARRY i_cy0(.CO(cy[1]), .CI(1'b0),  .I1(tnt[0]), .I0(bitx8ce));
   SB_DFF reg0( .Q(tnt[0]), .C(clk), .D(c_tnt[0]));
   SB_LUT4 #(.LUT_INIT(16'hc33c)) 
   i_tnt1(.O(c_tnt[1]),       .I3(cy[1]), .I2(tnt[1]), .I1(1'b0), .I0(1'b0));
   SB_CARRY i_cy1(.CO(cy[2]), .CI(cy[1]), .I1(tnt[1]), .I0(1'b0));
   SB_DFF reg1( .Q(tnt[1]), .C(clk), .D(c_tnt[1]));
   SB_LUT4 #(.LUT_INIT(16'hc33c)) 
   i_tnt2(.O(c_tnt[2]),       .I3(cy[2]), .I2(tnt[2]), .I1(1'b0), .I0(1'b0));
   SB_CARRY i_cy2(.CO(cy[3]), .CI(cy[2]), .I1(tnt[2]), .I0(1'b0));
   SB_DFF reg2( .Q(tnt[2]), .C(clk), .D(c_tnt[2]));
  
   SB_LUT4 #(.LUT_INIT(16'hfaaa)) 
   i_tnt3(.O(loadORtxce),     .I3(cy[3]),.I2(bitx8ce ), .I1(bitx8ce),.I0(load));
   SB_CARRY i_cy3(.CO(cy[4]), .CI(cy[3]),.I1(bitx8ce ), .I0(bitx8ce));

   SB_LUT4 #(.LUT_INIT(16'h0550)) 
   i_cnt0(.O(c_cnt[0]),       .I3(cy[4]), .I2(cnt[0]), .I1(1'b0), .I0(rst4));
   SB_CARRY i_cy4(.CO(cy[5]), .CI(cy[4]), .I1(cnt[0]), .I0(1'b0));
   SB_DFF reg4( .Q(cnt[0]), .C(clk), .D(c_cnt[0]));
   SB_LUT4 #(.LUT_INIT(16'h0550)) 
   i_cnt1(.O(c_cnt[1]),       .I3(cy[5]), .I2(cnt[1]), .I1(1'b0), .I0(rst4));
   SB_CARRY i_cy5(.CO(cy[6]), .CI(cy[5]), .I1(cnt[1]), .I0(1'b0));
   SB_DFF reg5( .Q(cnt[1]), .C(clk), .D(c_cnt[1]));
   SB_LUT4 #(.LUT_INIT(16'hcffc)) 
   i_cnt2(.O(c_cnt[2]),       .I3(cy[6]), .I2(cnt[2]), .I1(rst4), .I0(1'b0));
   SB_CARRY i_cy6(.CO(cy[7]), .CI(cy[6]), .I1(cnt[2]), .I0(rst4));
   SB_DFF reg6( .Q(cnt[2]), .C(clk), .D(c_cnt[2]));

   SB_LUT4 #(.LUT_INIT(16'h0055))
   i_rst(.O(rst4), .I3(rxst[1]),          .I2(1'b0),.I1(bitx8ce), .I0(rxst[0]));
   SB_CARRY i_andcy(.CO(cy[8]),.CI(cy[7]),.I1(1'b0),.I0(bitx8ce));
   generate 
      localparam v = 16'hfc30; // Seems I do not need two cases.
      SB_LUT4 #(.LUT_INIT(v))
      i_rxce( .O(c_rxce), .I3(cy[8]), .I2(rxpin), .I1(rxst[1]), .I0(rxst[0]));
   endgenerate
   SB_DFF regrxce( .Q(rxce), .C(clk), .D(c_rxce));
endmodule

/* ==========================================================================
 Reception is controlled with a 2-bit state machine. When starting reception,
 the receive shift register is initiated to 0x80, so when the first high is
 shifted out of the register we have counted to 8.
 
 Reception. State machine. Qualified with rxce
  
              Inputs          Next/Outputs                 State encoding:
                      +------ NextState[1]
          +---rxpin   |+------ NextState[0]                 HUNT  00 
          |+--lastbit || +---- bytercvd                     ARMD  10 
          ||rxce      || |+--- Initshiftreg                 RECV  11 
          |||         || ||+-- rst4                         GRCE  01
  State   |||         || |||   Comment
  -----DC BAa---------DC--------------------------
  HUNT 00 1xx         00 001   HUNT   
  HUNT 00 0x0         10 001   HUNT
  HUNT 00 0x1         10 001   ARMD   
  ARMD 10 xx0         10 000   ARMD
  ARMD 10 0x1         11 010   RECV   
  ARMD 10 1x1         00 000   HUNT   False start bit
  RECV 11 xx0         11 000   RECV   
  RECV 11 x01         11 000   RECV   
  RECV 11 x11         01 000   GRCE   
  GRCE 01 xx0         00 000   GRCE
  GRCE 01 0x1         00 000   HUNT   Frame bit not right, reject byte
  GRCE 01 1x1         00 100   HUNT   
  
 c_NextState[1] =  DCBA == x00x |  DCBA == 11x0
 c_NextState[0] =  DCBA == 100x |  DCBA == 11xx
  (rst4         =  DC   == 00)
   bytercvd     =  DCBA == 011x && rxce
  (initshiftreg =  DCBA == 100x && rxce)
   
 Shift shift register right in state RECV, qualified with rxce. When
 initshiftreg == 1, load sh[7:0] == 0x80 (qualified with rxce). To
 save one LUT, the initshiftreg equation is propagated to the LUTs
 used to constitute the shift regiser. The equation for rst4 is moved
 to rxtxdiv_m in order to save a LUT.
 
 rxst msb    other_bits
 00   hold   hold
 01   hold   hold
 10   1      0
 11   shift  shift
   
bytercvd     --------------------------------+--------------------- to INTF0
rxce         ----------------+               |
                      ____   |               |    _____         
rxpin ---------------|I0  |  |   __          +---|-+   |   _    
rxst[0] -----+-------|I1  |--(--|  |--+------(---|-|1\_|__| |__ ___ d[7]
rxst[1] -----(-+-----|I2  |  |  >  |  |      | +-| |0/ |  >_|  |
             | | +---|I3__|  +--CE_|  |      | | |_____|       |
             | | +-----------(--------+      | +---------------+
             | | |    ____   |               |    _____         
             | | +---|    |  |   __          +---|-+   |   _    
             +-(-----|    |--(--|  |--+------(---|-|1\_|__| |__ ___ d[6]
             | +-----|    |  |  >  |  |      | +-| |0/ |  >_|  |
             | | +---|____|  +--CE_|  |      | | |_____|       |
             | | +-----------(--------+      | +---------------+
             | | |           |               |
             : : :           |               :
             | |             |               |
             | | |    ____   |               |    _____         
             | | +---|    |  |   __          +---|-+   |   _    
             +-(-----|    |--(--|  |--+------(---|-|1\_|__| |__ ___ d[1]
             | +-----|    |  |  >  |  |      | +-| |0/ |  >_|  |
             | | +---|____|  +--CE_|  |      | | |_____|       |
             | | +-----------(--------+      | +---------------+
             | | |    ____   |               |    _____
             | | +---|    |  |   __          +---|-+   |   _
             +-(-----|    |--(--|  |--+----------|-|1\_|__| |__ ___ d[0]
               +-----|    |  |  >  |  |        +-| |0/ |  >_|  |
                 +---|____|  +--CE_|  |        | |_____|       |
                 |                    |        +---------------+
                 +--------------------+---------------------------- lastbit
                                               Extra resources - 
                                               can free up the carry
                                               chain by using rxce as 
                                               CE to these registers.
*/
module uartrxsm_m
  (
   input        clk,rxce,rxpin,lastbit,
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

//////////////////////////////////////////////////////////////////////////////
/*
 The receive state machine is assembled together with the shift regiser,
 and (optionally) a 8-bit holding regiser.
 Should be   8+4 = 12 logic cells when HASRXBYTEREGISTER == 0
 Should be 8+8+4 = 20 logic cells when HASRXBYTEREGISTER == 1
 
 The holding register, if present, has 6 bits that are qualified with
 rxce. This is not logically required, but may lead to better
 placement. 
 */
module uartrx_m
  # (parameter HASRXBYTEREGISTER = 0 )
   (
    input        clk,rxce,rxpin,
    output       bytercvd,
    output [1:0] rxst,
    output [7:0] q
    );
   /*AUTOWIRE*/
   uartrxsm_m rxsm(// Inputs
                   .lastbit( v[0] ),
                   /*AUTOINST*/
                   // Outputs
                   .bytercvd            (bytercvd),
                   .rxst                (rxst[1:0]),
                   // Inputs
                   .clk                 (clk),
                   .rxce                (rxce),
                   .rxpin               (rxpin));
   genvar        i;
   wire [7:0]    c_sh;
   wire [7:0]    v;

   generate
      for ( i = 0; i < 8; i = i + 1 ) begin : blk
         localparam a = i == 7 ? 16'hbfb0 : 16'h8f80;
         SB_LUT4 #(.LUT_INIT(a))
         sh( .O(c_sh[i]), .I3(v[i]), .I2(rxst[1]), .I1(rxst[0]), 
             .I0(i==7 ? rxpin:v[i+1]));
         SB_DFFE  shreg( .Q(v[i]), .C(clk), .E(rxce), .D(c_sh[i]) );
      end

      if ( HASRXBYTEREGISTER == 0 ) begin
         assign q = v;
      end else begin
         wire [7:0] c_h,bytereg;
         for ( i = 0; i < 8; i = i + 1 ) begin : blk2
            SB_LUT4 #(.LUT_INIT(16'hcaca))
            bt(.O(c_h[i]),.I3(1'b0),.I2(bytercvd), .I1(v[i]), .I0(bytereg[i]));
            if ( i < 6 )
              SB_DFFE regbyteA( .Q(bytereg[i]), .C(clk), .E(rxce), .D(c_h[i]));
            else
              SB_DFF regbyteB( .Q(bytereg[i]), .C(clk), .D(c_h[i]));            
         end
         assign q = bytereg;
      end
   endgenerate
endmodule

/* 

 Examples
 -------- 
 Example for 12MHz clock, 115200:
  4 LogicCells for rx state machine and control
 16 LogicCells for receive bit shiftregister and byte holding register.
 12 LogicCells for transmit part
     5 Prescaler /13 to get to 923 kHz
     4 txce counter 8
     4 rxce counter 8/4  115.385 bps, 1.6% error over a byte
                         needs a 14.1% eye-opening minimum.
 13    for bit clocks
 --------
 45 LogicCells total.
 37 LogicCells minimal version. Read no later than after 65 cycles.
 
 Example for 12MHz clock, 9600:
  4 LogicCells for rx state machine and control
 16 LogicCells for receive bit shiftregister and byte holding register.
 12 LogicCells for transmit part
     9  Prescaler /156 to get 76.923 kHz 
     4  txce counter 8
     4  rxce counter 8/4  9615 bps, 1.6% error over a byte
 17     for bit clocks
 -------------
 49 LogicCells total
 41 LogicCells minimal. Read no later than after 780 cycles.
 
 Example to establish the worst case I can think anyone would attempt,
 when it comes to implementation size. Assume a 270 MHz clock, want
 2400 bps.
  4 LogicCells for rx state machine and control
 16 LogicCells for receive bit shiftregister and byte holding register.
 12 LogicCells for transmit part
    15  Prescaler /14062 to get a 192001 Hz clock enable (1 cycle)
     4  txce counter 8
     4  rxce counter 8/4  2400 bps, 0.04% error over a byte.
 23     for bit clocks
 -------------
 55 LogicCells total

 Minimum solution for this way to construct the counters.  Assume
 system clock is 8 times bitrate: 
  4 LogicCells for rx state machine and control
 16 LogicCells for receive bit shiftregister and byte holding register.
 12 LogicCells for transmit part
     0  Prescaler
     4  txce counter 8
     4  rxce counter 8/4  
  8     for bit clocks
 -------------
 40 LogicCells total
 32 LogicCells if the result can be read in 5 cycles maximum.
 
 The shift register is only shifted during reception, and is otherwise
 only changed when the receive state machine goes from ARMED to RCV.
 This maximizes the time available to latch the shift register. Logic
 using the receiver will know a byte is received when the receive state
 machine goes from GRACE to HUNT. The implication is that we are
 guaranteed that a received byte stay unmodified for 1/8 + 1/2 bit time. 
 If it can be guaranteed that the *shiftregister* can be read in this 
 time, we can remove the parallel holding register, and save 8 
 LogicCells. An example: At 12MHz, 115200 has a bit time of 104 cycles. 
 5/8 bit time is 65 cycles.

 
 The following comments will apply to my small controller:
 --------------------------------------------------------- 
 Assume a 12 MHz clock, and a transmission at 115200. Interrupt
 response of a slow Epick must then be better than (65-2-10)/2 = 26
 instructions, which should not be difficult to acheive. Of cause,
 with a byte buffer we have 1041 clock cycles, 520 instructions, to
 react.
 
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
