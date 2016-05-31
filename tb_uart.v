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
   reg [15:0] cyclecounter,simtocy,tx_cyclecounter;
   reg        load,bytercvd_dly1;
   wire       cte1,rxpin;
   reg [7:0]  d;
   reg        seenB;
   localparam char1 = 8'hc1, char2 = 8'h4e;   
   reg        base_clk;
   reg        rx_clk;
   reg        tx_clk;
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 bytercvd;               // From dut_rx of uart_m.v
   wire [7:0]           q;                      // From dut_rx of uart_m.v
   wire                 txbusy;                 // From dut_tx of uart_m.v
   wire                 txpin;                  // From dut_tx of uart_m.v
   // End of automatics
   
   always # 20 base_clk = ~base_clk;
   assign cte1 = 1'b1;

   

   initial begin
      $dumpfile("tst.lxt");
      $dumpvars(0,tst);
      simtocy = 6000;
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
      if ( cyclecounter > simtocy ) begin
         if ( simtocy == 6000 )
           $display( "Simulation went off the rails" );
         $finish;
      end
      tx_clk <= ~tx_clk;
      if ( cyclecounter > 107 )
        rx_clk <= ~rx_clk;
   end
   
   always @(posedge tx_clk) begin
      tx_cyclecounter <= tx_cyclecounter + 1;
      load <= ( tx_cyclecounter == 654 || tx_cyclecounter == 2222 )
        ? 1'b1 : 1'b0;
      if ( tx_cyclecounter == 560 ) begin
         d <= char1;
      end else if ( tx_cyclecounter == 800 ) begin
         d <= char2;
      end
   end
   
   always @(posedge rx_clk) begin
      bytercvd_dly1 <= bytercvd;
      if ( bytercvd_dly1 ) begin
         if ( seenB ) begin
            if ( q != char2 ) begin
               $display( "Something wrong2" );
               $finish;
            end else begin              
               $display( "Success" );
               simtocy <= cyclecounter+400;
            end
         end else begin
            if ( q != char1 ) begin
               $display( "Something is wrong" );
               $finish;
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
     #( .SYSCLKFRQ(128), .BITCLKFRQ(4), .HASRXBYTEREGISTER(1'b1))
   //     #( .SYSCLKFRQ(12000000), .BITCLKFRQ(115200), .HASRXBYTEREGISTER(1'b1))
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
     #( .SYSCLKFRQ(128), .BITCLKFRQ(4), .HASRXBYTEREGISTER(1'b1))
   //     #( .SYSCLKFRQ(12000000), .BITCLKFRQ(115200), .HASRXBYTEREGISTER(1'b1))
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
