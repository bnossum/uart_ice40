/* Top level that just instantiates a UART in loopback mode in an icestick.
 * Assumtions: 12M clock. 115200 bps. 8N1 format.
 * Commented out instantiations of uart_m were used to examine generated code in 
 * Synplify
 * 
 * LogicCells:
 * 38 for uart proper
 *  1 for metastability removal rxpin
 *  1 for generation of constant 1'b1.
 * -------
 * 40 logicCells in total
 * 
 * WARNING - not tested yet! Do not use yet!
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
  ( inout PIO3_08,PIO3_07,PIO1_14,PIO1_02,GBIN6
    );
   wire [7:0] d;
   wire       clk,cte1,rxpinmeta1,c_rxpinmeta1,rxpin;
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 bitx8ce;                // From uart of uart_m.v
   wire                 bytercvd;               // From uart of uart_m.v
   wire [7:0]           q;                      // From uart of uart_m.v
   wire                 txbusy;                 // From uart of uart_m.v
   wire                 txpin;                  // From uart of uart_m.v
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

   // bitx8ce to J2 pin 1 for debugging
   SB_IO #( .PIN_TYPE(6'b010111)) // OUTPUT_REGISTERED/INPUT_LATCH
   IO_bitx8ce
     ( .PACKAGE_PIN(PIO1_02),
       .OUTPUT_CLK(clk),
       .D_OUT_0(bitx8ce) );

   
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

   //                                                                               Divider
   //                                                                               | Nr LUTS
//   uart_m #(.SYSCLKFRQ(10*8*6),  .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.0000 37
//   uart_m #(.SYSCLKFRQ(10*4*13), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.5000 38
//   uart_m #(.SYSCLKFRQ(10*2*25), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.2500 40
//   uart_m #(.SYSCLKFRQ(10*2*27), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.7500 40

//   uart_m #(.SYSCLKFRQ(10*1*49), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.1250 41
//   uart_m #(.SYSCLKFRQ(10*1*51), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.3750 41
//   uart_m #(.SYSCLKFRQ(10*1*53), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.6250 41
//   uart_m #(.SYSCLKFRQ(10*1*55), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.8750 41
//   uart_m #(.SYSCLKFRQ(5*1*97 ), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.0625 42
//   uart_m #(.SYSCLKFRQ(5*1*99 ), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.1875 42
//   uart_m #(.SYSCLKFRQ(5*1*101), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.3125 42
//   uart_m #(.SYSCLKFRQ(5*1*103), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.4375 42
//   uart_m #(.SYSCLKFRQ(5*1*105), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.5625 42
//   uart_m #(.SYSCLKFRQ(5*1*107), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.6875 42
//   uart_m #(.SYSCLKFRQ(5*1*109), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.8125 42
//   uart_m #(.SYSCLKFRQ(5*1*111), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 6.9375 42
   
//   uart_m #(.SYSCLKFRQ(10*8*1 ), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.0000 33
//   uart_m #(.SYSCLKFRQ( 5*1*17), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.0625 40
//   uart_m #(.SYSCLKFRQ(10*1*9 ), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.1250 39
//   uart_m #(.SYSCLKFRQ( 5*1*19), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.1875 40
//   uart_m #(.SYSCLKFRQ(10*2*5 ), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.2500 38
//   uart_m #(.SYSCLKFRQ( 5*1*21), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.3175 40
//   uart_m #(.SYSCLKFRQ(10*1*11), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.3750 39
//   uart_m #(.SYSCLKFRQ( 5*1*23), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.4375 40
//   uart_m #(.SYSCLKFRQ(10*4*3 ), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.5000 36
//   uart_m #(.SYSCLKFRQ( 5*1*25), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.5625 40
//   uart_m #(.SYSCLKFRQ(10*1*13), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.6250 39
//   uart_m #(.SYSCLKFRQ( 5*1*27), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.6875 40
//   uart_m #(.SYSCLKFRQ(10*2*7 ), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.7500 38
//   uart_m #(.SYSCLKFRQ( 5*1*29), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.8125 40
//   uart_m #(.SYSCLKFRQ(10*1*15), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.8750 39
//   uart_m #(.SYSCLKFRQ( 5*1*31), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 1.9375 40
//   uart_m #(.SYSCLKFRQ(10*8*2 ), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 2.0000 34

//   uart_m #(.SYSCLKFRQ(10*8*9 ), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 9.0 37
//   uart_m #(.SYSCLKFRQ(10*4*19), .BITCLKFRQ(10), .ACCEPTEDERROR_IN_PERCENT(1)) // 9.5 39

   uart_m #(.SYSCLKFRQ(12000000), .BITCLKFRQ(115200), .ACCEPTEDERROR_IN_PERCENT(2)) // 13 38
   
   uart
     (/*AUTOINST*/
      // Outputs
      .txpin                            (txpin),
      .txbusy                           (txbusy),
      .bitx8ce                          (bitx8ce),
      .bytercvd                         (bytercvd),
      .q                                (q[7:0]),
      // Inputs
      .clk                              (clk),
      .cte1                             (cte1),
      .load                             (load),
      .d                                (d[7:0]),
      .rxpin                            (rxpin));

   // Connect the uart in loopback:
   assign load = bytercvd;
   assign d = q;
endmodule

// Local Variables:
// verilog-library-directories:("." "./fromrefdesign/" )
// verilog-library-files:("../../PROJ/iCE_simlib/iCE_simlib.v" "uart.v" )
// verilog-library-extensions:(".v" )
// End:
