`timescale 1us / 10ns
`default_nettype none

// Test bench is acting both as the CPU and the serial port

module cmdtest();

   // # (n*m) gives us scalable delay statements if we want to change granularity
   // Cant get #10us notation or something to work in iverilog
   parameter m=100;
   
   reg clock=0;

   // 50 mhz clock
   always #(m) clock = ~clock;

   reg [7:0] divi;
   
   reg reset;
   reg [7:0] receive_data;
   reg      recv_strobe;
   wire [7:0] send_data=0;
   reg 	      send_strobe=1; // Serial port starts by being available for transmiting
   wire       data_avail;
   wire       busrq_n;
   reg 	      busak_n=1;

   reg [7:0]	      ext_ram_out=0;
   

   reg [7:0] 	      tmp;
   
   
   // svcd cant handle integer :)
   reg [3:0]    i;

   function [7:0] get_w_str;
      input [12*8-1:0] str;
      input [3:0] i;
      begin
	 // TODO generate for this...
	 case(i)
	   0:  get_w_str = str[12*8-1: 11*8];
	   1:  get_w_str = str[11*8-1: 10*8];
	   2:  get_w_str = str[10*8-1: 9*8 ];
	   3:  get_w_str = str[ 9*8-1: 8*8 ];
	   4:  get_w_str = str[ 8*8-1: 7*8 ];
	   5:  get_w_str = str[ 7*8-1: 6*8 ];
	   6:  get_w_str = str[ 6*8-1: 5*8 ];
	   7:  get_w_str = str[ 5*8-1: 4*8 ];
	   8:  get_w_str = str[ 4*8-1: 3*8 ];
	   9:  get_w_str = str[ 3*8-1: 2*8 ];
	   10: get_w_str = str[ 2*8-1: 1*8 ];
	   11: get_w_str = str[ 1*8-1: 0*8 ];
	   
	 endcase
      end
   endfunction
   
   initial begin
      $dumpfile("cmdline.vcd");
      $dumpvars(clock);
      
      // Munch the welcome message
      for (i=0;i<4;i++)
	begin
	   wait (data_avail);
	   #(m) send_strobe=0;
	   #(10*m) send_strobe=1;
	   wait (!data_avail);
	end
      
      #(2*m) reset = 1;
      recv_strobe=0;
      #(18*m) reset = 0;

      // Send a command instructing cmdline interpreter to halt cpu...
      receive_data = "h";
      #(2*m) recv_strobe=1;
      #(2*m) recv_strobe=0;

      receive_data = 10;
      #(2*m) recv_strobe=1;
      #(2*m) recv_strobe=0;

      wait (busrq_n==0);

      #(m) busak_n <= 0;

      for (i=0;i<4;i++)
	begin
	   wait (data_avail);
	   #(m) send_strobe=0;
	   #(10*m) send_strobe=1;
	   wait (!data_avail);
	end
      
      // Tell interpreter to restart cpu...
      receive_data = "g";
      // The time from last strobe is less than 80 us and a character takes at least 86 us so we should be ok
      // even though provoking this by setting it to 2*m has the cmdline.v miss it
      #(10*m) recv_strobe=1;
      #(2*m) recv_strobe=0;

      receive_data = 10;
      #(2*m) recv_strobe=1;
      #(2*m) recv_strobe=0;


      wait (busrq_n==1);

      #(m) busak_n <= 1;
      

      for (i=0;i<4;i++)
	begin
	   wait (data_avail);
	   #(m) send_strobe=0;
	   #(10*m) send_strobe=1;
	   wait (!data_avail);
	end

      receive_data = "h";
      #(10*m) recv_strobe=1;
      #(2*m) recv_strobe=0;

      receive_data = 10;
      #(2*m) recv_strobe=1;
      #(2*m) recv_strobe=0;

      wait (busrq_n==0);

      #(m) busak_n <= 0;

      for (i=0;i<4;i++)
	begin
	   wait (data_avail);
	   #(m) send_strobe=0;
	   #(10*m) send_strobe=1;
	   wait (!data_avail);
	end

      // Try a simple write (this will produce a lot of signalling :)
      // We will write to the notorious 16514 "10 REM BRANDT" address
      // remembering that this is now addressed in srams "linear" memory, we will end up at 130 decimal
      // making it the "00082" address in hex, then we will change the "B" to a "D" i.e. zx81 code 26 (hex)
      // remembering that the zeddy does not use ascii..
      // Ending it all with a period

      for (i=0;i<12;i++)
	begin
	   tmp = get_w_str("w 00082 26.\n", i);
	   #(20*m) receive_data = tmp;
	   #(20*m) recv_strobe=1;
	   #(20*m) recv_strobe=0;
	end

      // Could test for the memory signaling here

      for (i=0;i<4;i++)
	begin
	   wait (data_avail);
	   #(m) send_strobe=0;
	   #(10*m) send_strobe=1;
	   wait (!data_avail);
	end
      
      // memory test invert
      receive_data = "i";
      #(10*m) recv_strobe=1;
      #(2*m) recv_strobe=0;

      receive_data = 10;
      #(2*m) recv_strobe=1;
      #(2*m) recv_strobe=0;

      for (i=0;i<4;i++)
	begin
	   wait (data_avail);
	   #(m) send_strobe=0;
	   #(10*m) send_strobe=1;
	   wait (!data_avail);
	end

       for (i=0;i<12;i++)
	begin
	   #(20*m) receive_data = get_w_str("b 10207.\n   ", i);
	   #(20*m) recv_strobe=1;
	   #(20*m) recv_strobe=0;
	end

      $display("break flag %d", break_flag);
      $display("break addr %x", break_addr);
  
      for (i=0;i<4;i++)
	begin
	   wait (data_avail);
	   #(m) send_strobe=0;
	   #(10*m) send_strobe=1;
	   wait (!data_avail);
	end

       for (i=0;i<12;i++)
	begin
	   #(20*m) receive_data = get_w_str("r 00082 002.", i);
	   #(20*m) recv_strobe=1;
	   #(20*m) recv_strobe=0;
	end
  
      receive_data = 10;
      #(2*m) recv_strobe=1;
      #(2*m) recv_strobe=0;

      for (i=0;i<4;i++)
	begin
	   wait (data_avail);
	   #(m) send_strobe=0;
	   #(10*m) send_strobe=1;
	   wait (!data_avail);
	end

      # (100*m) $stop;
      
   end
   
   reg [7:0] ram_fakedata=0;
   // Simple sram test bench model
   always @(posedge clock)
     begin
	ram_fakedata++;
	ext_ram_out = ram_fakedata;
	
     end
   
   wire break_flag;
   wire[15:0] break_addr;
   
   cmdline cmd(
	       .clock(clock),
	       .reset(reset),
	       .receive_data(receive_data),
	       .recv_strobe(recv_strobe),
	       .send_data(send_data),
	       .send_strobe(send_strobe),
	       .data_avail(data_avail),
	       .busrq_n(busrq_n),
	       .busak_n(busak_n),
	       .ext_ram_out(ext_ram_out),
	       .break_flag(break_flag),
	       .break_addr(break_addr)
	       );
   
   

   
   
   
endmodule
