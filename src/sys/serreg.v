
// This module will in and out serial data and write and read
// corresponding registers

module serreg


  (clock,
   reset,

   // Towards serial.v
   receive_data,
   recv_strobe,

   send_data,
   send_strobe,
   data_avail,

   // Toward registers as such
   addr,
   write_strobe,
   write_data,
   read_data_mux,
   read_avail_mux,
   read_strobe,

   read_cycle,
   
   testch
   );
  `include "parameters.vh"
   
   input clock;
   input reset;
   input [7:0] receive_data;
   input       recv_strobe;
   output reg [7:0] send_data=0;
   input 	    send_strobe;
   output reg	    data_avail;

   output reg [7:0] addr;
   output reg [7:0] write_data;

   output reg 	    write_strobe;

   input wire [n_periphs-1:0] read_avail_mux;

   // TODO generic to also control in serperiph.v
   input wire [n_periphs*8-1:0] read_data_mux;
   output reg 	    read_strobe;

   output reg 	    read_cycle;
   
   output reg [7:0] 	 testch;

   parameter idle      = 3'd0;
   parameter reading   = 3'd1;
   parameter writing   = 3'd2;
   parameter got_rcnt  = 3'd3;
   parameter got_wcnt  = 3'd4;
   parameter got_raddr = 3'd5;
   parameter got_waddr = 3'd6;

   
   // command byte
   parameter flush = 8'b00000000;
   parameter read  = 8'b00000001;
   parameter write = 8'b00000010;


   // bit zero indicates some kind of read cycle is going on
   reg [2:0] 		 state;

   always @(posedge clock)
     begin
	read_cycle = state[0];
     end
   
   // no of bytes counter
   reg [8:0] 	    cnt;

   // Flank detectors
   reg 		    old_strobe;
   reg 		    old_avail;
   reg 		    old_read_strobe;
   
   always @(posedge clock)
     begin


	/*
	testch[5]=recv_strobe;
	testch[4]=write_strobe;
	testch[3:2]=write_data[1:0];
	testch[1:0]=receive_data[1:0];
	 */
	//testch[4:2] = state;
	// testch[0] = state[0];
     end

   always @(posedge clock)
     begin
	if (reset==1)
	  begin
	     write_strobe=0;
	     write_data=0;
	     old_strobe=0;
	     old_read_strobe=0;
	     old_avail=0;
	     state=idle;
	  end
	if (old_strobe == 0 && recv_strobe == 1)
	  begin
	     old_strobe = 1;
	     case (state)
	       idle:
		 // First byte in msg is command
		 // 258 zeros should reset logic from any state
		 // If a read has stalled one zero should be enough
		 begin
		    case (receive_data)
		      read:
			begin
			   state=reading;
			end
		      write:
			begin
			   state=writing;
			end
		      flush:
			begin
			   // Munch
			end
		    endcase
		 end
	       writing, reading:
		 begin
		    // Second byte in msg is addr 0..255
		    addr = receive_data;
		    if (state == writing) state = got_waddr;
		    if (state == reading) state = got_raddr;
		 end
	       got_waddr, got_raddr:
		 begin
		    // Third byte in msg is len 1..256 (0)
		    if (receive_data==0)
		      cnt = 256;
		    else
		      cnt = receive_data;
		    if (state == got_waddr) state = got_wcnt;
		    if (state == got_raddr) state = got_rcnt;
		 end
	       got_wcnt:
		 begin
		    // Here we receive cnt bytes, i.e. we propagate strobe
		    // to write_strobe
		    write_strobe = 1;

		    // We also propagate data
		    write_data = receive_data;
		    
		    cnt = cnt - 1;
		    if (cnt == 0) state = idle;
		 end
	       got_rcnt:
		 begin
//		    state = idle;
		 end
	     endcase // case (state)
	  end
	else
	  begin
	     old_strobe=recv_strobe;

	     if (recv_strobe == 0)
	       write_strobe = 0;
	  end
	if (state == got_rcnt)
	  begin
	     // Select which periph that should be allowed to
	     // signal to serial that they have data
	     send_data = read_data_mux[addr[1:0]*8+7:addr[1:0]*8];
	     
//	     data_avail = read_avail_mux[addr[1:0]];
	     case (addr[1:0])
	       2'b01: data_avail=read_avail_mux[2'b01];
	       default : data_avail=1;
	     endcase
	     
	     // send_strobe from serial is broadcasted
	     // periphs can ignore this or use it to
	     // prepare next byte of data
	     read_strobe = send_strobe;

	     if (read_strobe == 0 && old_read_strobe==1)
	       begin
		  cnt = cnt - 1;
		  if (cnt == 0)
		    begin
		       state = idle;
		       data_avail = 0;
		    end
	       end
	     old_read_strobe=read_strobe;
	  end
     end

endmodule
