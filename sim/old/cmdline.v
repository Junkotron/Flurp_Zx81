


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
   );

   input clock;


   reg [7:0] divi;
   
   always @(posedge clock)
     begin
	divi <= divi + 1;
     end
   
   
   
   input reset;
   input [7:0] receive_data;
   input       recv_strobe;
   output reg [7:0] send_data=0;
   input 	    send_strobe;
   output reg	    data_avail=0;
   
   reg 		    old_recv_strobe=0;
   reg 		    old_send_strobe=0;

   output reg 	    busrq_n=1;
   input wire 	    busak_n;
   
   reg [4:0] 	    state=0;

   parameter idle = 5'b00000;
   parameter halt = 5'b00001; // Halt the z80 cpu
   parameter halt_busak = 5'b00010; // wait for busak
   parameter send_ok = 5'b00011; // wait for busak
   parameter strobing = 5'b00100; // wait for busak

   reg [1:0] 	    msgpek=0;
   
   
   always @(posedge divi[7])
     if (!reset)
       begin
	  // Incoming char
	  if (recv_strobe == 1 && old_recv_strobe == 0)
	    begin
	       old_recv_strobe = 1;
	       
	       case (receive_data)
		 "h": state = halt;
	       endcase
	    end
	  else
	    begin
	       case (state)
		 halt:
		   begin
		      busrq_n<=0;
		      state = halt_busak;
		   end
		 halt_busak:
		   begin
		      if (busak_n == 0)
			state = send_ok;
		   end
		 send_ok:
		   begin
		      data_avail <= 0;
		      if (send_strobe == 1 && old_send_strobe == 0)
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
				  send_data<=10;
			       end
			     3: state<=idle;
			   endcase
			end
		      else
			old_send_strobe <= send_strobe;
		   end
		 strobing:
		   begin
		      data_avail <= 1;
		      msgpek <= msgpek + 1;
		      state = send_ok;
		   end
	       endcase
	    end
       end
endmodule
