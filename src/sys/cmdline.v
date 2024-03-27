


module cmdline
  (clock,
   reset,
   receive_data,
   recv_strobe,

   send_data,
   send_strobe,
   data_avail,
   busrq_n,
   busak_n,

   ri,
   ri_ce_n,
   ri_oe_n,
   ri_we_n,
   ri_addr,
   ri_data,
   ext_ram_out,
   addr,

   break_addr,
   break_flag,
   
   do_reset,
   
      
   );
   
   input clock;
   input reset;
   input [7:0] receive_data;
   input       recv_strobe;
   output reg [7:0] send_data=0;
   input 	    send_strobe;
   output reg	    data_avail=0;
   output reg 	    busrq_n=1;
   input wire 	    busak_n;


   // Connectors for memory manipulation
   output reg 	    ri=0;
   output reg 	    ri_ce_n=1;
   output reg 	    ri_oe_n=1;
   output reg 	    ri_we_n=1;
   output reg [17:0] ri_addr=0;
   output reg [7:0]      ri_data=0;
   input wire [7:0] 	 ext_ram_out;
   
   input wire [13:0] addr;  // CPU data bus

   output reg [15:0] break_addr;
   output reg 	     break_flag=0;

   output reg 	     do_reset=0;

   // The body 
   reg [7:0] divi=0;
   
   always @(posedge divi[6])
     begin
	divi <= divi + 1;
     end
   

   reg [4:0] 	    state=send_ok;

   parameter idle = 5'b00000;
   parameter halt = 5'b00001; // Halt the z80 cpu
   parameter halt_busak = 5'b00010; // wait for busak
   parameter send_ok = 5'b00011; 
   parameter strobing = 5'b00100; 
   parameter wait_xmit = 5'b00101; 
   parameter go = 5'b00110; 
   parameter invert = 5'b00111; // Test of mem read-write for now
   parameter send_err = 5'b01000; 
   parameter read_write = 5'b01001; 

   reg [2:0] 	    invert_substate=0;
   
   
   reg [7:0] 	    sit_on=0;
   
   reg [2:0] 	    msgpek=0;
   
   reg [7:0] 	    temp_byte=0;

    function [6:0] go_func;  
       input 	    msgpek;
       input 	    busrq_n;
       input [4:0]  state;
             
       begin  
	  msgpek=0;
	  busrq_n=1;
	  state = send_ok;
	  go_func={msgpek, busrq_n, state };
	  
       end  
    endfunction

   
   reg [17:0] rw_addr;
   reg [8:0]  rw_data; // We use an extra bit as this doubles for the "length" argument in the "r" command
   reg 	      rw_ce_n;
   reg 	      rw_oe_n;
   reg 	      rw_we_n;
   reg [3:0]  rw_pek;
   reg [4:0]  rw_substate;
   reg [8:0]  rcnt;

   // Must match against rw_func = ... return statement below :p
   function [5+18+9+1+1+1+4+5+9+16+1+8+1+1:0] rw_func;
      input   recv_strobe;
      input [7:0] receive_data;
      
      input [4:0] state;
      input [17:0] rw_addr;
      input [8:0]  rw_data;
      input 	   rw_ce_n;
      input 	   rw_oe_n;
      input 	   rw_we_n;
      input [3:0]  rw_pek;
      input [4:0]  rw_substate;
      input [8:0]  rcnt;
      input send_strobe;
      input [7:0] ext_ram_out;
      
      begin
	 case (rw_substate)
	   0: 
	     begin
		rw_pek=0;
		rw_ce_n=0;
		rw_oe_n=0;
		rw_we_n=1;
		rw_substate=1;
	     end
	   1: // assert that strobe is low
	     if (!recv_strobe) rw_substate=2;
	   2: // Here we wait for chars from serial
	     begin
	     if (recv_strobe)
	       begin
		  // Start receiving hex digits, anything else is ignored, apart from the dot which ends the writing
		  
		  if ( (receive_data>="0" && receive_data<="9") || (receive_data>="a" && receive_data<="f"))
		    begin
		       if  (receive_data>="0" && receive_data<="9") receive_data = receive_data - "0";
		       else if (receive_data>="a" && receive_data<="f") receive_data = receive_data - "a" + 10;

		       case (rw_pek) // Stuff the bits in the correct places...
			 0:
			   begin // First address hex digit only allows 0,1,2,3 not higher :)
			      rw_addr[17:16] = receive_data[1:0];
			      rw_pek=1;
			   end
			 1:
			   begin // b starts here and ends at 4:
			      rw_addr[15:12] = receive_data[3:0];
			      rw_pek=2;
			   end
			 2:
			   begin
			      rw_addr[11:8] = receive_data[3:0];
			      rw_pek=3;
			   end
			 3:
			   begin
			      rw_addr[7:4] = receive_data[3:0];
			      rw_pek=4;
			   end
			 4:
			   begin
			      rw_addr[3:0] = receive_data[3:0];
			      if (sit_on=="b") 
				begin
				   rw_pek=9;
				end
			      else rw_pek=5;
			   end
			 5:
			   begin
			      rw_data[3:0] = receive_data[3:0];
			      rw_pek=6;
			   end
			 6:
			   begin
			      rw_data[7:4] = rw_data[3:0];
			      
			      rw_data[3:0] = receive_data[3:0];

			      // Now we are ready for an actual write
			      if (sit_on == "w") rw_substate = 3; else rw_pek = 7;
			   end
			 7:
			   begin // We cap the number of bytes to read at 100h (256 dec)
			      if (rw_data[4])
				rcnt[8:0] = 256;
			      else
				begin
				   rcnt[8] = 0;
				   rcnt[7:4] = rw_data[3:0];
				   rcnt[3:0] = receive_data[3:0];
				end
			      rw_pek=8;
			   end
			 8:
			   begin
			      if (receive_data==10)
				begin
				   rw_substate=10;
				   rw_oe_n=0;
				   rw_ce_n=0;
				end
			   end
			 9:
			   begin
			      // This is the exit state for "b"
			      // We just wait for the common dot "." below
			   end
		       endcase // case (rw_pek)
		    end

		  if ( (sit_on == "w") || (sit_on == "r") || (sit_on == "b") )
		    begin
		       // When done writing we get a period
		       // then we await a newline
		       if (receive_data == ".") 
			 begin
			    msgpek=0;
			    rw_substate = 9;
			 end
		       // Go to waiting for strobe to turn off but not if 
		       // we are gonna do an actual write cycle
		       if (rw_substate == 2) rw_substate=1;
		    end
		  
	       end // if (recv_strobe)
	     end
	   3: // Here below we do the write cycle timings
	     begin
		rw_ce_n = 0;
		rw_oe_n = 0;
		rw_we_n = 0;
		rw_substate=rw_substate+1;
	     end
	   4,5,6,7:
	     begin // Extra states due to "slow" (>20 ns) tristate buffer and mem
		rw_substate=rw_substate+1;
	     end
	   8:
	     begin
		rw_ce_n = 1;
		rw_oe_n = 1;
		rw_we_n = 1;

		// Set us up for another read from serial cycle but only the data this time with the consequetive addr
		rw_addr = rw_addr + 1;
		rw_substate = 1;
		rw_pek=5;
	     end
	   9:
	     begin
		if ( (receive_data == 10) || (receive_data == 13) )
		  begin
		     if (sit_on == "r")
		       begin
			  rw_ce_n = 0;
			  rw_oe_n = 0;
			  rw_substate = 10;
		       end
		     else
		       state = send_ok;
		  end
	     end
	   10,11,12,13:
	     begin
		// Bite a few cycles for the sram and tristate buffers
		rw_substate = rw_substate + 1;
	     end
	   14:
	     begin
		// Read the data and dump to serial in hex
		send_data={ 4'b0000, ext_ram_out[7:4] };
		send_data = send_data + "0";
		if (send_data > "9") send_data = send_data + 7;
		rw_substate = 15;
	     end
	   15:
	     begin
		data_avail = 1;
		rw_substate = 21;
	     end

	   21:
	     begin
		// Wait for send_strobe toggle low-high
		if (send_strobe == 0) rw_substate = 22;
	     end
	   22:
	     begin
		// Wait for send_strobe toggle low-high
		if (send_strobe == 1) rw_substate = 16;
	     end

	   16:
	     begin
		data_avail = 0;
		rw_substate = 17;
	     end
	   17:
	     begin
		// Read the data and dump to serial
		send_data={ 4'b0000, ext_ram_out[3:0] };
		send_data = send_data + "0";
		if (send_data > "9") send_data = send_data + 7;
		rw_substate = 18;
	     end
	   18:
	     begin
		data_avail = 1;
		rw_substate = 23;
	     end
	   
	   23:
	     begin
		// Wait for send_strobe toggle low-high
		if (send_strobe == 0) rw_substate = 24;
	     end
	   24:
	     begin
		// Wait for send_strobe toggle low-high
		if (send_strobe == 1) rw_substate = 19;
	     end
	   19:
	     begin
		data_avail = 0;
		rw_substate = 20;
	     end
	   20:
	     begin
		// next address or are we finished?
		rw_addr = rw_addr + 1;
		rcnt = rcnt - 1;
		if (rcnt == 0)
		  begin
		     state = send_ok;
		  end
		else
		  rw_substate = 10;
	     end
	 endcase // case (rw_substate)
	 
	 rw_func={ state, rw_addr, rw_data, rw_ce_n, rw_oe_n, rw_we_n, rw_pek, rw_substate, break_addr, break_flag, rcnt, send_data, data_avail };
      end
   endfunction
      
   always @(posedge clock)
     begin
	case (state)

	  read_write:
	    begin
	       
	       { state, rw_addr, rw_data, rw_ce_n, rw_oe_n, rw_we_n, rw_pek, rw_substate, break_addr, break_flag, rcnt, send_data, data_avail} 
		 = 
		   rw_func(recv_strobe, receive_data, 
			      state, rw_addr, rw_data, rw_ce_n, rw_oe_n, rw_we_n, rw_pek, rw_substate, rcnt, send_strobe, ext_ram_out);

	       case (sit_on)
		 "w":
		   { ri_addr, ri_data, ri_ce_n, ri_oe_n, ri_we_n } = { rw_addr, rw_data[7:0], rw_ce_n, rw_oe_n, rw_we_n };
		 "b":
		   begin
		      // Following syntax "b f aaaa." will land f in addr[16]
		      // and aaaa in addr[15:0]
		      // Remembering break address works in zx81 address space

		      // When all data is shifted in we transfer to pageing logic
		      if (state == send_ok)
			begin
			   break_flag = rw_addr[16];
			   break_addr = rw_addr[15:0];
			end

		   end
		 "r":
		   begin 
		      { ri_addr, ri_ce_n, ri_oe_n, ri_we_n, rcnt } = { rw_addr, rw_ce_n, rw_oe_n, rw_we_n, rcnt };
		   end
		      
	       endcase

	    end
	  
	  idle: // 0
	    begin
	       do_reset=0;
	       if (recv_strobe)
		 begin
		    case (receive_data)
		      
		      "w","r","b":
			begin
			   sit_on = receive_data;
			   state = read_write;
			   rw_substate=0;
			end
		      "a", "h","g","i": sit_on <= receive_data;
		      10, 13:
			begin
			   if (sit_on != 0)
			     begin
				
				case (sit_on)
				  "a": // reset (r is used for read :)
				    begin
				       do_reset=1;
				       state=send_ok;
				       msgpek=0;
				    end

				  "h": state = halt;
				  "g":
				    begin
				       state = go;
				       ri=0;
				    end
				  "i":
				    begin
				       if (ri)
					 begin
					    state=invert;
					    invert_substate=0;
					 end
				       else
					 // TODO: Needs more states return address like or something
					 // state=send_err;
					 state=idle;
				    end
				endcase
			     end // if (sit_on != 0)
			end
		    endcase
		 end
	    end // case: idle
	  invert: // 7
	    begin
	       case (invert_substate)
		 0:
		   begin
		      ri_ce_n=0;
		      ri_oe_n=0;
		      ri_addr = 16514 - 16384;
		      invert_substate=invert_substate+1;
		   end
		 1:
		   begin
		      // Give sram and tristate buffers some
		      // extra time...
		      invert_substate=invert_substate+1;
		   end
		 2:
		   begin
		      temp_byte=ext_ram_out;
		      temp_byte = temp_byte ^ 8'b10000000;
		      ri_data = temp_byte;
		      invert_substate=invert_substate+1;
		   end
		 3:
		   begin
		      ri_we_n=0;
		      invert_substate=invert_substate+1;
		   end
		 4:
		   begin
		      ri_ce_n=1;
		      ri_oe_n=1;
		      ri_we_n=1;
		      msgpek=0;
		      state=send_ok;
		   end
	       endcase // case (invert_substate)
	    end
	  go: // 6
	    {msgpek, busrq_n, state } <= go_func(msgpek, busrq_n, state);
	  halt: // 1
	    begin
	       msgpek<=0;
	       busrq_n<=0;
	       state = halt_busak;
	    end
	  halt_busak: // 2
	    begin
	       if (busak_n == 0)
		 begin
		    state = send_ok;
		    // We also flip the memory access
		    ri=1;
		 end
	    end
	  send_ok: // 3
	    begin
	       sit_on=0;
	       if (send_strobe == 1)
		 begin
		    case (msgpek)
		      0: 
			begin
			   send_data<="O";
			   state <= strobing;
			end
		      1: 
			begin
			   state <= strobing;
			   send_data<="K";
			end
		      2: 
			begin
			   state <= strobing;
			   send_data<=13;
			end
		      3: 
			begin
			   state <= strobing;
			   send_data<=10;
			end
		      4: 
			begin
			   state<=idle;
			end
		    endcase
		 end
	    end
	  send_err: // 8
	    begin
	       if (send_strobe == 1)
		 begin
		    case (msgpek)
		      0: 
			begin
			   send_data<="E";
			   state <= strobing;
			end
		      1: 
			begin
			   state <= strobing;
			   send_data<="R";
			end
		      2: 
			begin
			   state <= strobing;
			   send_data<="R";
			end
		      3: 
			begin
			   state <= strobing;
			   send_data<=13;
			end
		      4: 
			begin
			   state <= strobing;
			   send_data<=10;
			end
		      5: 
			begin
			   state<=idle;
			end
		    endcase
		 end
	    end
	  strobing: // 4
	    begin
	       data_avail <= 1;
	       if (send_strobe == 0)
		 begin
		    msgpek <= msgpek + 1;
		    state = wait_xmit;
		 end
	    end
	  wait_xmit: // 5
	    begin
	       if (send_strobe==1) 
		 begin
		    state = send_ok;
		    data_avail=0;
		 end
	    end
	endcase
     end
endmodule

