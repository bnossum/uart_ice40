/* A first testbench for a small uart.
 *
 * We transmit "B" and see if we receive it.
 * 
 * Commands to run this:
 * 
 * iverilog -o workfile -DSIMULATION tb_uart.v \
 *         uart.v ../../../PROJ/iCE_simlib/iCE_simlib.v 
 * vvp workfile -lxt
 * gtkwave tst.lxt
 */

module tst;
   reg [31:0] cyclecounter,simtocy,tx_cyclecounter;
   reg        load,bytercvd_dly1;
   wire       cte1,rxpin;
   reg [7:0]  d;
   reg        seenB;
   localparam char1 = 8'hc1, char2 = 8'h4e;   
   reg        base_clk;
   reg        rx_clk;
   reg        tx_clk;

   function real bnabs;
      input real v;
      bnabs = v >= 0 ? v : -v;
   endfunction
     
   localparam MEGA = 1000000;
   localparam ACCEPTEDERROR_IN_PERCENT = 2;
//    localparam BITCLKFRQ = 10;
// //   localparam SYSCLKFRQ = 10*8*6;  // 6
// //   localparam SYSCLKFRQ = 10*4*13; // 6.5
// //   localparam SYSCLKFRQ = 10*2*25; // 6.25
// //   localparam SYSCLKFRQ = 10*2*27; // 6.75
// //   localparam SYSCLKFRQ = 10*1*49; // 6.125
// //   localparam SYSCLKFRQ = 10*1*51; // 6.375
// //   localparam SYSCLKFRQ = 10*1*53; // 6.625
// //   localparam SYSCLKFRQ = 10*1*55; // 6.875
// //   localparam SYSCLKFRQ = 5*1*97;  // 6.0625
// //   localparam SYSCLKFRQ = 5*1*99;  // 6.1875
// //   localparam SYSCLKFRQ = 5*1*101; // 6.3125
// //   localparam SYSCLKFRQ = 5*1*103; // 6.4375
// //   localparam SYSCLKFRQ = 5*1*105; // 6.5625
// //   localparam SYSCLKFRQ = 5*1*107; // 6.6875
// //   localparam SYSCLKFRQ = 5*1*109; // 6.8125
// //   localparam SYSCLKFRQ = 5*1*111; // 6.9375
// 
// //   localparam SYSCLKFRQ = 10*8*1;  // 1.0000
// //   localparam SYSCLKFRQ = 5*1*17;  // 1.0625
// //   localparam SYSCLKFRQ = 10*1*9;  // 1.1250
// //   localparam SYSCLKFRQ = 5*1*19;  // 1.1875
// //   localparam SYSCLKFRQ = 10*2*5;  // 1.2500
// //   localparam SYSCLKFRQ = 5*1*21;  // 1.3125
// //   localparam SYSCLKFRQ = 10*1*11; // 1.3750 
// //   localparam SYSCLKFRQ = 5*1*23;  // 1.4375
// //   localparam SYSCLKFRQ = 10*4*3;  // 1.5000
// //   localparam SYSCLKFRQ = 5*1*25;  // 1.5625
// //   localparam SYSCLKFRQ = 10*1*13; // 1.6250 
// //   localparam SYSCLKFRQ = 5*1*27;  // 1.6875
// //   localparam SYSCLKFRQ = 10*2*7;  // 1.7500 
// //   localparam SYSCLKFRQ = 5*1*29;  // 1.8125
// //   localparam SYSCLKFRQ = 10*1*15; // 1.8750
// //   localparam SYSCLKFRQ = 5*1*31;  // 1.9375
// //   localparam SYSCLKFRQ = 10*8*2;  // 2.0000
// 
// //   localparam SYSCLKFRQ = 10*8*9;  // 9
// //   localparam SYSCLKFRQ = 10*4*19;  // 9.5
   
   localparam SYSCLKFRQ = 12*MEGA;
   localparam BITCLKFRQ = 115200;
   localparam SIMTOCY = 5 * 10* SYSCLKFRQ/(BITCLKFRQ);
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 bytercvd;               // From dut_rx of uart_m.v
   wire [7:0]           q;                       // From dut_rx of uart_m.v
   wire                 txbusy;                 // From dut_tx of uart_m.v
   wire                 txpin;                  // From dut_tx of uart_m.v
   // End of automatics
   
   always # 20 base_clk = ~base_clk;
   assign cte1 = 1'b1;

   initial begin
      $dumpfile("tst.lxt");
      $dumpvars(0,tst);
      simtocy = SIMTOCY;
      tx_clk <= 0;
      rx_clk <= 0;
      base_clk <= 0;
      cyclecounter <= 0;
      tx_cyclecounter <= 0;
      load <= 0;    
      seenB <= 0;
      d <= 0;
   end

   always @(posedge base_clk ) begin
      cyclecounter <= cyclecounter+1;
      if ( cyclecounter > SIMTOCY ) begin
         if ( simtocy == SIMTOCY )
           $display( "Simulation went off the rails" );
         $finish;
      end
      tx_clk <= ~tx_clk;
      if ( cyclecounter > 0.8*SYSCLKFRQ/(BITCLKFRQ) )
        rx_clk <= ~rx_clk;
   end
   
   always @(posedge tx_clk) begin
      tx_cyclecounter <= tx_cyclecounter + 1;
      load <= ( tx_cyclecounter == 10 +       SYSCLKFRQ/BITCLKFRQ || 
                tx_cyclecounter == 10 + 12*(SYSCLKFRQ/BITCLKFRQ) )
        ? 1'b1 : 1'b0;
      if ( tx_cyclecounter == SYSCLKFRQ/BITCLKFRQ ) begin
         d <= char1;
      end else if ( tx_cyclecounter == SYSCLKFRQ/BITCLKFRQ + 20 ) begin
         d <= char2;
      end
   end
   
   always @(posedge rx_clk) begin
      bytercvd_dly1 <= bytercvd;
      if ( bytercvd_dly1 ) begin
         if ( seenB ) begin
            if ( q != char2 ) begin
               $display( "Something wrong2" );
               simtocy <= cyclecounter+400;
            end else begin              
               $display( "Success" );
               simtocy <= cyclecounter+400;
            end
         end else begin
            if ( q != char1 ) begin
               $display( "Something is wrong" );
               simtocy <= cyclecounter+400;
            end else begin
               //$display("HERE");
               seenB <= 1;
            end
         end
      end
   end

   wire dummy_txpin, dummy_txbusy, dummy_bytercvd;
   wire bitx8ce_rx, bitx8ce_tx, dummy_rxpin;
   wire [7:0] dummy_q;
   
   // Device under test. We have two, we let one be a tx, the other a rx.
   // The reason we have two devices, is that I want to test different
   // phases of the clocks.
   assign dummy_rxpin = 0;
   uart_m
     #( .SYSCLKFRQ(SYSCLKFRQ), .BITCLKFRQ(BITCLKFRQ), 
        .ACCEPTEDERROR_IN_PERCENT(ACCEPTEDERROR_IN_PERCENT), 
        .HASRXBYTEREGISTER(1'b1))
   dut_tx
     (// Outputs
      .bytercvd(dummy_bytercvd),
      .q                                (dummy_q[7:0]),
      .bitx8ce                          (bitx8ce_tx),
      // Inputs
      .rxpin                            (dummy_rxpin),
      .clk                              (tx_clk),
      /*AUTOINST*/
      // Outputs
      .txpin                            (txpin),
      .txbusy                           (txbusy),
      // Inputs
      .cte1                             (cte1),
      .load                             (load),
      .d                                (d[7:0]));
   
   uart_m
     #( .SYSCLKFRQ(SYSCLKFRQ), .BITCLKFRQ(BITCLKFRQ), .HASRXBYTEREGISTER(1'b1),
        .ACCEPTEDERROR_IN_PERCENT(ACCEPTEDERROR_IN_PERCENT))
   dut_rx
     (// Outputs
      .txpin(    dummy_txpin    ),
      .txbusy(   dummy_txbusy   ),
      .bitx8ce(  bitx8ce_rx  ),
      // Inputs
      .clk (rx_clk ),
      .load( 1'b0 ),
      .d (0),
      /*AUTOINST*/
      // Outputs
      .bytercvd                         (bytercvd),
      .q                                (q[7:0]),
      // Inputs
      .cte1                             (cte1),
      .rxpin                            (rxpin));
   
   // Bit-serial loopback. Pads not simulated, so txpin inverted here.
   assign rxpin = ~txpin; 
endmodule

// Local Variables:
// verilog-library-directories:("." "./fromrefdesign/" )
// verilog-library-files:("../../PROJ/iCE_simlib/iCE_simlib.v" "uart.v" )
// verilog-library-extensions:(".v" )
// End:
