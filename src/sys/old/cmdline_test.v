`timescale 1us / 1ns
`default_nettype none

module cmdline_test();
   
   reg clock=0;

   always #1 clock = ~clock;

   reg reset;
   reg [7:0] receive_data;
   reg      recv_strobe;
   wire [7:0] send_data=0;
   reg 	      send_strobe;
   wire       data_avail=0;
   wire       busrq_n=1;
   reg 	      busak_n;

   reg 	      blaha=0;
   
   
   initial begin
      $dumpfile("cmdline.vcd");
      $dumpvars(clock);
      # 1 reset = 1;
      # 16 reset = 0;
      recv_strobe=1;

      // Send some value to the cmdline interpreter
      #100 receive_data = 8'b10011001;
      recv_strobe=1;
      #1 recv_strobe=0;

      # 100 $stop;
   end

   
   
   cmdline cmd(
	       .clock(clock),
	       .reset(reset),
	       .receive_data(receive_data),
	       .recv_strobe(recv_strobe),
	       .send_data(send_data),
	       .send_strobe(send_strobe),
	       .data_avail(data_avail),
	       .busrq_n(busrq_n),
	       .busak_n(busak_n)
	       );

   
   
   
endmodule
