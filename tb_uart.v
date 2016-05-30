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
   reg clk;
   reg [15:0] cyclecounter,simtocy;
   reg        load,bytercvd_dly1;
   wire       cte1,rxpin;
   reg [7:0]  d;
   reg        seenB;
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 bitx8ce;                // From dut of uart_m.v
   wire                 bytercvd;               // From dut of uart_m.v
   wire [7:0]           q;                      // From dut of uart_m.v
   wire                 txbusy;                 // From dut of uart_m.v
   wire                 txpin;                  // From dut of uart_m.v
   // End of automatics
   
   always # 20 clk = ~clk;
   assign cte1 = 1'b1;

   

   initial begin
      $dumpfile("tst.lxt");
      $dumpvars(0,tst);
      simtocy = 3000;
      clk <= 0;
      cyclecounter <= 0;
      load <= 0;    
      seenB <= 0;  
   end

   always @(posedge clk) begin
      cyclecounter <= cyclecounter+1;
      if ( cyclecounter > simtocy ) begin
         if ( simtocy == 3000 )
           $display( "Simulation went off the rails" );
         $finish;
      end
      load <= ( cyclecounter == 333 || cyclecounter == 1640 )
                ? 1'b1 : 1'b0;
      if ( cyclecounter == 300 )
        d <= 8'h41;
      else if ( cyclecounter == 400 )
        d <= 8'h4e;
      
      bytercvd_dly1 <= bytercvd;
      if ( bytercvd_dly1 ) begin
         if ( seenB ) begin
            if ( q != 8'h4e ) begin
               $display( "Something wrong2" );
               $finish;
            end else begin              
               $display( "Success" );
               simtocy <= cyclecounter+200;
            end
         end else begin
            if ( q != 8'h41 ) begin
               $display( "Something is wrong" );
               $finish;
            end else begin
               seenB <= 1;
            end
         end
      end
   end

   // Device under test
   uart_m
     #( .HASRXBYTEREGISTER(1'b1))
     dut
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
   // Bit-serial loopback. Pads not simulated, so txpin inverted here.
   assign rxpin = ~txpin; 
endmodule

// Local Variables:
// verilog-library-directories:("." "./fromrefdesign/" )
// verilog-library-files:("../../PROJ/iCE_simlib/iCE_simlib.v" "uart.v" )
// verilog-library-extensions:(".v" )
// End:
