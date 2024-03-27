

module serial
  (clock,
   reset,
   dce_rxd,
   dce_txd,
   
   receive_data,
   recv_strobe,

   send_data,
   send_strobe,
   data_avail,
);

   input clock;
   input reset;
   input dce_rxd;
   output reg dce_txd=1;
   output reg [7:0] receive_data;
   output reg 	    recv_strobe;
   input [7:0] 	    send_data;
   output 	    send_strobe;
   input 	    data_avail;
   
   
   // 50 mhz clock 434 gives abt 115207 baud
   parameter rcv_bit_per = 434;
   
   parameter half_rcv_bit_per = 434/2;

   parameter timeout=100000000/2;
   
   parameter sloclock_divider=17;
   
   //--State Definitions--
   parameter ready = 3'b000;
   parameter start_bit = 3'b001;
   parameter data_bits = 3'b010;
   parameter stop_bit = 3'b011;

   // Pulse forming of reset to counter
   parameter ready2 = 3'b100;
   parameter more_bits = 3'b101;
   parameter data_bits2 = 3'b110;
   parameter stop_bit2 = 3'b111;
   
   reg [3:0] 	data_bit_count=4'b0000;
   reg [7:0] 	rcv_sr=0;
   reg [2:0] 	state=ready;

   reg 		cnt_res=0;
   
   // Fast counters, TODO instances
   // We only count n-34 beause we spend one sloclock cycle doing reset

   reg [9:0] 	counter1;
   reg 		half_done=0;
   always @(posedge clock)
     begin
	if (cnt_res==1)
	  begin
	     counter1 <= 0;
	     half_done<=0;
	  end
	else
	  begin
	     if (counter1==half_rcv_bit_per-34)
	       half_done<=1;
	     else
	       counter1 <= counter1 + 1;
	  end
     end


   reg [9:0] 	counter2;
   reg 		done=0;
   always @(posedge clock)
     begin
	if (cnt_res==1)
	  begin
	     counter2 <= 0;
	     done<=0;
	  end
	else
	  begin
	     if (counter2==rcv_bit_per-34)
	       done<=1;
	     else
	       counter2 <= counter2 + 1;
	  end
     end

   // Pulse shaper for short reset
   reg old_cnt_res_slow=0;
   always @(posedge clock)
     begin
	if (cnt_res_slow==1 && old_cnt_res_slow==0)
	  cnt_res<=1;
	else
	  cnt_res<=0;
	old_cnt_res_slow<=cnt_res_slow;
     end
   
   reg [4:0] sloclock_cnt;
   reg sloclock;
   
   // Clk divider for the slow logic divide 434 even by seven and then two
   always @(posedge clock)
     begin
	begin
	   if (sloclock_cnt==sloclock_divider)
	     begin
		sloclock_cnt <= 5'b00000;
		sloclock <= ~sloclock;
	     end
	   else
	     sloclock_cnt <= sloclock_cnt + 1;
	end
     end

   reg cnt_res_slow=0;
   always @(posedge sloclock)
     begin
	if (reset==1)
	  begin
	     data_bit_count<=4'b0000;
	     state<=ready;
	     recv_strobe <= 0;
	  end
	else
	  begin
	     case (state)
	       ready:
		 begin
		    if (dce_rxd == 0)
		      begin
			 state<=ready2;
			 cnt_res_slow=1;
		      end
		 end
	       ready2:
		 begin
		    state<=start_bit;
		    cnt_res_slow=0;
		 end
	       start_bit:
		 begin
		    if (half_done)
		      begin
			 state<=more_bits;
			 cnt_res_slow = 1;
			 data_bit_count <= 4'b0000;
		      end
		 end
	       more_bits:
		 begin
		    cnt_res_slow=0;
		    state <= data_bits;
		 end
	       data_bits:
		 begin
		    if (done)
		      begin
			 // time to sample mid-bit
			 rcv_sr <= { dce_rxd, rcv_sr[7:1] };
			 cnt_res_slow = 1;

			 state <= more_bits;
			 if (data_bit_count==7)
			   begin
			      state <= data_bits2;
			   end
			 else
			   data_bit_count <= data_bit_count+1;
		      end
		 end
	       data_bits2:
		 begin
		    receive_data <= rcv_sr;
		    state <= stop_bit;
		    cnt_res_slow=0;
		 end
	       stop_bit:
		 begin
		    // We roll forward to approx. middle of stop bit
		    // then we allow ready state to sync and wait for start bit
		    // next time around
		    recv_strobe <= 1;
		    if (done)
		      begin
			 cnt_res_slow = 1;
			 data_bit_count<=4'b0000;
			 state<=stop_bit2;
		      end
		 end
	       stop_bit2:
		 begin
		    state<=ready;
		    recv_strobe <= 0;
		    cnt_res_slow=0;
		 end
	     endcase
	     
	  end
     end

   parameter idle = 3'b000;
   parameter sending = 3'b001;
   parameter wait_bit = 3'b010;
   reg [2:0] sstate=idle;
   reg [9:0] send_reg=10'b0;
   reg [3:0] send_cnt=0;
   reg [10:0] bigcnt;
   
   // Starts as allowed to send
   reg 	     send_strobe=1;
   
   reg [7:0] blaha = 8'b01010101;
   
   // The sender
   always @(posedge sloclock)
     begin
	case (sstate)
	  idle:
	    if (data_avail)
	      begin
		 send_reg <= { 1'b1, send_data[7:0], 1'b0 };
		 sstate<=sending;
		 send_cnt<=0;
		 send_strobe <= 0;
	      end
	  sending:
	    begin
	       if (send_cnt == 10)
		 begin
		    sstate <= idle;
		    send_strobe <= 1;
		 end
	       else
		 begin
		    dce_txd<=send_reg[send_cnt];
		    sstate <= wait_bit;
		    bigcnt <= 0;
		 end
	    end // case: sending
	  wait_bit:
	    if (bigcnt == rcv_bit_per/(sloclock_divider*2)-2 )
	      begin
		 send_cnt <= send_cnt + 1;
		 sstate <= sending;
	      end
	    else
	      begin
		 bigcnt <= bigcnt + 1;
	      end
	  endcase
     end

   
endmodule
