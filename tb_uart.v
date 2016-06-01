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
   localparam MEGA = 1000000;
   localparam SYSCLKFRQ = 12*MEGA; 
   localparam BITCLKFRQ = 115200;

   localparam SIMTOCY = 5 * 10* SYSCLKFRQ/(BITCLKFRQ);
   localparam ACCEPTEDERROR_IN_PERCENT = 20;
   localparam real    F_IDEALPREDIVIDE = SYSCLKFRQ / (BITCLKFRQ*8.0);
   localparam integer PREDIVIDE = (SYSCLKFRQ+BITCLKFRQ*4) / (BITCLKFRQ*8); 
   localparam real    RESULTING_BITFRQ = SYSCLKFRQ / (PREDIVIDE*8.0);
   localparam real    REL_ERR = RESULTING_BITFRQ > BITCLKFRQ ?
                      (RESULTING_BITFRQ - BITCLKFRQ)/BITCLKFRQ :
                      (BITCLKFRQ - RESULTING_BITFRQ)/BITCLKFRQ;
   localparam real    REL_ERR_OVER_FRAME_IN_PERCENT = REL_ERR * 10 * 100;

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
      $display( "Predivide value %d (ideal %f)", PREDIVIDE, F_IDEALPREDIVIDE );
      $display( "Resulting bitrate : %d", RESULTING_BITFRQ );
      $display( "Error over (startbit,byte,stopbit) in %% of bit period: %f", 1000*REL_ERR );
      if ( REL_ERR_OVER_FRAME_IN_PERCENT > ACCEPTEDERROR_IN_PERCENT ) begin
         $display( "Can not realize this usart, aborts" );
         $finish;
      end
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
     #( .SYSCLKFRQ(SYSCLKFRQ), .BITCLKFRQ(BITCLKFRQ), .HASRXBYTEREGISTER(1'b1))
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
     #( .SYSCLKFRQ(SYSCLKFRQ), .BITCLKFRQ(BITCLKFRQ), .HASRXBYTEREGISTER(1'b1))
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
