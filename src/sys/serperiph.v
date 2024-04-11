


module serperiph

  (clock,
   reset,
   dce_rxd,
   dce_txd,

   busrq_n,
   busak_n,

   ri,
   ri_ce_n,
   ri_oe_n,
   ri_we_n,
   ri_addr,
   ri_data,
   ext_ram_out,

   // TODO: remove not used?
   cpu_addr,

   // Break bank switch stuff
   break_addr,
   break_flag,
   
   // Reset of CPU from serial line
   do_reset,
   
   // Keyboard remote
   kb_strobe,
   press,
   row,
   col,

   testch
      
   );
  `include "parameters.vh"
   input clock;
   input reset;

   input dce_rxd;
   output reg dce_txd;   
   
   wire [7:0] receive_data;
   wire 	    recv_strobe;
   wire [7:0] send_data;
   wire 	    send_strobe;
   wire 	    data_avail;

   wire 	    read_strobe;

   wire 	    read_cycle;
   
   output reg 	    busrq_n;
   input wire 	    busak_n;

   // Filtered send_strobe only active when data is incoming
   // (as opposed to command, address and length)
   wire 		    write_strobe;
   wire [7:0] 	    write_data;
   wire [7:0] 	    reg_addr;

   reg 		    oldwstr;
   reg 		    oldrstr;
   // Write machine
   // Here we gather all write signals
   // to simplify writing comms driver in other end
   // Needs shadow registers where applicable

   // Packets: <cmd> <addr> <size n> <b1> <b2> ... <bn>
   // 02 00 01 00  02 00 01 02 - will set busrq_n (and others) low and will set ri high
   
   // 02 00 01 00  02 00 01 01 - will set ri low and will set busrq_n high and others low
   
   // The 00082h test "10 REM BRANDT" - a7,b7 is inverter B,R in zx code
   // 02 01 01 00   02 02 01 00   02 03 01 82   02 04 02 a7 b7
   reg [17:0] 	    addrtmp;

   // This is how to do readback of 82 and 83
   // 02 01 01 00   02 02 01 00   02 03 01 82   01 01 02
   
   // Read machine
   // Here we have all read registers for easy reference
   reg [7:0] datar0, datar1, datar2, datar3;

   reg 	     avail1;
   
   
   reg 	     wtrig, rtrig;

   reg 	     newaddr;

   reg [7:0]	     echoreg;
   
   always @(posedge clock)
     begin
	if (reset == 1)
	  begin
	     // Internal
	     oldwstr = 0;
	     oldrstr = 0;
	     wtrig=0;
	     rtrig=0;
	     newaddr=0;
	     echoreg=0;

	     // "real" signals, these values are also
	     // to be set by shadow register!
	     // TODO: some common "Include" with this between
	     // here and C-code?
	     busrq_n=1;
	     ri=0;
	     break_flag=0;


	     // Remote keyboard
	     kb_strobe=0;
 	     press=0;
	     row=3'b111;
	     col=3'b111;

	  end

	if (wtrig==0 && read_cycle==0)
	  begin

	     // We need to trig on neg since the data and strobe
	     // are altered at the same time so we avoid glitches
	     if (write_strobe == 0 && oldwstr==1)
	       
	       case (reg_addr)
		 8'h00: 
		   begin
		      // Single bit:ers gather here..
		      busrq_n=write_data[0] ;
		      // This activates the ram inject as such,
		      // wait for busak before activating this!!
		      ri = write_data[1];
		      break_flag = write_data[2];
		      
		      // ...
		   end
		 // Three bytes to set RAM address for bus injection
		 8'h01: 
		   begin
		      newaddr=1;
		      addrtmp[17:16]=write_data[1:0];
		   end
		 8'h02: 
		   begin 
		      newaddr=1;
		      addrtmp[15:8]=write_data;
		   end
		 8'h03: 
		   begin
		      newaddr=1;
		      addrtmp[7:0]=write_data;
		   end

		 // Writing data apart from setting ri_data it also
		 // trigger a set of events that should be finished
		 // well before another serial byte arrives
		 8'h04:
		   begin
		      ri_addr = addrtmp;
		      addrtmp = addrtmp + 1;
		      ri_data = write_data;
		      wtrig = 1;
		   end

		 8'h05:
		   echoreg = write_data + 1;

		 8'h06:
		   break_addr[15:8] = write_data;

		 8'h07:
		   break_addr[7:0] = write_data;

		 8'h08:
		   begin
		      kb_strobe=write_data[7];
 		      press=write_data[6];
		      row=write_data[5:3];
		      col=write_data[2:0];
		   end
	       endcase
	     
	     oldwstr = write_strobe;
	  end
	else
	  begin
	     if (write_strobe == 1) wtrig = 0;
	  end

	if (read_cycle==0)
	  rtrig=0;
	
	if (read_cycle==1)
	  begin
	     if (rtrig == 0)
	       begin
		  case (reg_addr)
		    8'h00:
		      datar0 = { busak_n, 7'b0000000 };
		    8'h01:
		      begin 
			 // This is a consequetive reader register

			 // TODO: fix why is this???
			 if (newaddr) addrtmp = addrtmp - 1;
			 newaddr = 0;
			 ri_addr=addrtmp;
			 addrtmp = addrtmp + 1;
			 rtrig = 1;
		      end
		    8'h02: // echo reg + 1 of write (05)
		      datar2 = echoreg;
		    8'h03:
		      datar3 = 8'hba;
		  endcase // case (reg_addr)
		  // TODO REMEMBER to add bits here and there if we need more
		  // than 4 read regs for now... could we make the mux all here
		  // instead?
	       end
	     else
	       begin
		  if (read_strobe == 1 && oldrstr==0) rtrig = 0;
	       end // else: !if(rtrig == 0)
	     oldrstr = read_strobe;
	  end // if (read_cycle==1)
     end

   
   // Connectors for memory manipulation
   output reg 	    ri;
   output reg 	    ri_ce_n=1;
   output reg 	    ri_oe_n=1;
   output reg 	    ri_we_n=1;
   output reg [17:0] ri_addr=0;
   output reg [7:0]      ri_data=0;
   input wire [7:0] 	 ext_ram_out;
   

   // TODO: reader and writer is never on at the same time
   // so they could probably share a lot of this
   //
   // Ram writer machine, goes a turn when data is written
   // possibly repeatedly
   reg 			 old_wtrig;
   reg [2:0] 		 ri_wstate;

   reg [6:0] 		 wpausecnt;

   reg [7:0] 		 readmemdata;

   // Ram reader machine, goes a turn when data is read
   // possibly repeatedly
   reg 			 old_rtrig;
   reg [2:0] 		 ri_rstate;

   reg [6:0] 		 rpausecnt;

   
   always @(posedge clock)
     begin
	if (reset == 1)
	  begin
	     old_wtrig=0;
	     ri_wstate=3'b000;
	     wpausecnt = 0;
	     old_rtrig=0;
	     ri_rstate=3'b000;
	     rpausecnt = 0;
	  end
	if (wpausecnt!=0)
	  begin
	     wpausecnt = wpausecnt - 1;
	  end
	else
	  begin
	     case (ri_wstate)
	       3'b000:
		 begin
		    if (old_wtrig == 0 && wtrig == 1)
		      begin
			 ri_wstate=ri_wstate+1;
			 wpausecnt=100;
		      end
		    old_wtrig = wtrig;
		 end
	       3'b001:
		 begin
		    ri_we_n = 0;
		    ri_wstate=ri_wstate+1;
		    wpausecnt=100;
		 end
	       3'b010:
		 begin
		    ri_ce_n = 0;
		    ri_wstate=ri_wstate+1;
		    wpausecnt=100;
		 end
	       3'b011:
		 begin
		    ri_ce_n = 1;
		    ri_wstate=ri_wstate+1;
		    wpausecnt=100;
		 end
	       3'b100:
		 begin
		    ri_we_n = 1;
		    ri_wstate=0;
		 end
	     endcase
	  end

	if (rpausecnt!=0)
	  begin
	     rpausecnt = rpausecnt - 1;
	  end
	else
	  begin
	     case (ri_rstate)
	       3'b000:
		 begin
		    if (old_rtrig == 0 && rtrig == 1)
		      begin
			 ri_rstate=ri_rstate+1;
			 rpausecnt=100;
		      end
		    old_rtrig = rtrig;
		 end
	       3'b001:
		 begin
		    ri_oe_n = 0;
		    ri_rstate=ri_rstate+1;
		    rpausecnt=100;
		 end
	       3'b010:
		 begin
		    ri_ce_n = 0;
		    ri_rstate=ri_rstate+1;
		    rpausecnt=100;
		 end
	       3'b011:
		 begin
		    // save value now that it is available
		    // also tell serial we have data

		    datar1 = ext_ram_out;
		    
		    avail1 = 1;
		    ri_rstate=ri_rstate+1;
		    rpausecnt=100;
		 end
	       3'b100:
		 begin
		    avail1 = 0;
		    ri_ce_n = 1;
		    ri_oe_n = 1;
		    ri_rstate=3'b000;
		 end
	     endcase
	  end
     end
   
   input wire [13:0] cpu_addr;

   output reg [15:0] break_addr=0;
   output reg 	     break_flag=0;

   output reg 	     do_reset=0;

   output reg 	     kb_strobe;
   
   output reg 	     press;
   
   // 1 of 8
   output reg [2:0]      row;

   // 1 of 5
   output reg [2:0]      col;

   output reg [7:0] 	 testch;

   always @(posedge clock)
     begin
/*
	testch[2:0] = ri_rstate;
	testch[3] = datar1[1];
	testch[4] = avail1;
	testch[5] = read_strobe;
	testch[6] = rtrig;
 */
/*
	testch[3:0] = ri_addr;
	testch[6:4] = ext_ram_out[6:4];
 */
//	testch[7] = dce_txd;

     end


   
   reg [n_periphs*8-1:0] concat_mux;
   reg [3:0] 	       allmuxes;
   
   always @(posedge clock)
     begin
	concat_mux = { datar3, datar2, datar1, datar0 };
	allmuxes = { 2'b11, avail1, 1'b1 };
     end
   
   serreg regs(
	       .clock(clock),
	       .reset(reset),
	       
	       .receive_data(receive_data),
	       .recv_strobe(recv_strobe),
	       .send_strobe(send_strobe),
	       .data_avail(data_avail),
	       .send_data(send_data),

	       .write_strobe(write_strobe),
	       .write_data(write_data),
	       .addr(reg_addr),

	       .read_data_mux(concat_mux),
	       // TODO all data always available
	       // we need to signal this for conseq read
	       .read_avail_mux(allmuxes),
	       .read_strobe(read_strobe),

	       .read_cycle(read_cycle),
	       
	       .testch(testch)
	       );
   
	       

   serial ser(
	      .clock(clock), // 50mhz
	      .reset(reset),
	      .dce_rxd(dce_rxd),
	      .dce_txd(dce_txd),
	      .receive_data(receive_data),
	      .recv_strobe(recv_strobe),
	      .send_data(send_data),
	      .send_strobe(send_strobe),
	      .data_avail(data_avail),
	      );

endmodule

