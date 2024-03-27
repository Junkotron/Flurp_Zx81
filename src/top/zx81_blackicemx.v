`timescale 1ns / 1ps
`default_nettype none

module zx81 (
	     input wire        clk_100mhz,



	     output wire       csync,
	     output wire       lum,

	     input wire        ps2_clk,
	     input wire        ps2_data,

	     output wire [7:0] testch,

	     // Ext mem
	     output reg        cs_n,
	     output reg        we_n,
	     output reg        oe_n,
	     output reg [17:0] a,
	     inout reg [7:0]   d,

	     // Config switches (lets get physical)
	     output wire       led1,
	     output wire       led2,
	     input wire        video_mode, // Has pulldown
	     input wire        ram_size, // Has pulldown

	     // on-board buttons for various tests
	     input wire        but1,
	     input wire        but2,

	     output wire       rx, // sends to serial adapter
	     input wire        tx, // receives from serial
	     
	     input wire        ear,
	     output wire       mic,
	     );

   
   
   wire 		       hsync;
   
   wire 		       vsync;
   
   // Debug wires currently unemployed
   wire [7:0] 		       dbg_key;
   
   wire [2:0] 		       led;

   assign csync = hsync & vsync;
   assign lum = video;
   
   // Should be 1/1000 of 100 MHz clock?
   localparam integer 	       slowDownClkThreshhold = 999;
   reg [31:0] 		       thresholdCounter = 0;
   reg 			       r_LED = 1'b0;
   always @(posedge clk_100mhz)
     begin
        if (thresholdCounter > slowDownClkThreshhold)
          begin
             r_LED <= !r_LED;
             thresholdCounter <= 0;
          end
        else
          begin
             thresholdCounter <= thresholdCounter + 1;
          end
     end

   assign led = 0;

   wire video; // 1-bit video signal (black/white)

   // Trivial conversion for audio
   wire spk;
   
   // Video timing
   wire vga_blank;

   wire do_reset;
   
   // Power-on RESET (8 clocks)
   reg [7:0] poweron_reset = 8'h00;
   always @(posedge clk_sys) begin
      if (do_reset)
	poweron_reset <= 0;
      else
	poweron_reset <= {poweron_reset[6:0],1'b1};
   end

   reg clk_sys; 
   reg clk_50mhz; 
   reg clk_25mhz; 
   wire [10:0] ps2_key;

   
   
   always @(posedge clk_100mhz) clk_50mhz <= ~clk_50mhz;
   always @(posedge clk_50mhz) clk_25mhz <= ~clk_25mhz;
   
   always @(posedge clk_25mhz) clk_sys <= ~clk_sys;

   wire [17:0] a;
   wire [7:0]  d;
   
   wire        cs_n;
   wire        oe_n;
   wire        we_n;
   
   // The ZX80/ZX81 core
   fpga_zx81 the_core (
		       .clk_sys(clk_sys),
		       .buffer_clk(clk_50mhz),
		       .reset_n(poweron_reset[7]),
		       .ear(ear),
		       .ps2_key(ps2_key),
		       .video(video),
		       .hsync(hsync),
		       .vsync(vsync),
		       .vde(vga_blank),
		       .mic(mic),
		       .spk(spk),
		       .zx81(1'b1),

		       // extmem connectors
		       .areg(a),
		       .dmem(d),
		       .ce_n(cs_n),
		       .oe_n(oe_n),
		       .we_n(we_n),
		       
		       .video_mode(video_mode),
		       .ram_size(ram_size),


		       // modify demo
		       .but1(but1),
		       .but2(but2),
		       .led1(led1),
		       .led2(led2),

		       .rx(rx),
		       .tx(tx),

		       .do_reset(do_reset),
		       
		       .testch(testch),
		       );
   
   // Get PS/2 keyboard events
   ps2 ps2_kbd (
		.clk(clk_sys),
		.ps2_clk(ps2_clk),
		.ps2_data(ps2_data),
		.ps2_key(ps2_key)
		);


endmodule

