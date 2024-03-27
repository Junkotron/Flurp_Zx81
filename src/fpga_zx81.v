`timescale 1ns / 1ps
`default_nettype none

module fpga_zx81 (
		  input wire 	    clk_sys,
		  input wire 	    buffer_clk,
		  input wire 	    reset_n,
		  input wire 	    ear,
		  input wire [10:0] ps2_key,
		  output reg 	    video,
		  output reg 	    hsync,
		  output reg 	    vsync,
		  output wire 	    vde,
		  output wire 	    mic,
		  output wire 	    spk,
		  input wire 	    zx81,

		  // ext membus
		  output reg 	    ce_n,
		  output reg 	    we_n,
		  output reg 	    oe_n,
		  output reg [17:0] areg,
		  inout reg [7:0]   dmem,

		  // Switches
		  input wire 	    video_mode,
		  input wire 	    ram_size,

		  // Buttons for various tests
		  input wire 	    but1,
		  input wire 	    but2,

		  // leds
		  output wire 	    led1,
		  output wire 	    led2,

		  // serial dbg and management
		  output wire 	    rx, // sends to serial adapter
		  input wire 	    tx, // receives from serial
		  
		  output wire 	    do_reset, // From serial

		  output wire [7:0] testch,
		  
		  );

   reg 				    bank_e=0;
   reg [2:0] 			    bank_state = 0;

   
   // assign led1 = 0;

   assign led2 = 0;

   assign testch[0] = dbg_cs;
   assign testch[1] = dbg_data;
   assign testch[2] = doing_load;
   assign testch[3] = 0;
   assign testch[4] = 0;
   assign testch[5] = 0;
   assign testch[6] = 0;
   assign testch[7] = 0;

   
   always @(posedge buffer_clk) begin
      case (bank_state)
	0:
	  begin
	     // Wait for user of serial line to activate break point
	     if (break_flag == 1)
	       bank_state = 1;
	  end
	1:
	  begin
	     // Now we wait for the pivot point when the CPU
	     // addresses our break point fetching the first byte of
	     // the instruction
	     if (addr==break_addr && mreq_n==0 && m1_n==0)
	       bank_state = 2;
	  end
	2:
	  begin
	     // So now we just wait for mreq to go high again and then do the actual
	     // flip
	     if (mreq_n==1)
	       begin
		  // CPU will now start to fetch whatever madness was put into the
		  // sram at the corresponding address or go back to the original
		  // ROM
		  bank_e=1;
		  bank_state = 3;
	       end
	  end
	3:
	  begin
	     // Have we returned to the scene of the crime?
	     if (addr==break_addr && mreq_n==0 && m1_n==0)
	       bank_state=4;
	  end
	4:
	  begin
	     // Now the break_addr should have settled 
	     if (mreq_n==1)
	       begin
		  // CPU will now get back to its original exec
		  // We will execute the same mnemonic twice
		  // so any side effects if might have must be "reversed"
		  // before the call
		  bank_e=0;
		  bank_state = 5;
	       end
	  end
	5:
	  begin
	     // Wait for break_flag to toggle back again
	     if (break_flag==0)
	       begin
		  bank_state=0;
	       end
	  end
      endcase
   end
   
   // Switches are transfered to these registers at
   // reset since hot swap is not possible and potentially
   // dangerous
   reg 				    video_mode_r=1;
   reg 				    ram_size_r=1;

   always @(posedge buffer_clk) begin
      if (~reset_n)
	begin
	   video_mode_r<=~video_mode;
	   ram_size_r<=~ram_size;
	end
   end
   
   // Clock generation
   reg 				    ce_cpu_p;
   reg 				    ce_cpu_n;
   reg 				    ce_65, ce_psg;
   reg [2:0] 			    counter = 0;

   // Use a 13MHz clock. When bit zero of counter is low, a 6.5MHz cycle is active
   // ce_psg is a slower clock used by the sound generator
   always @(negedge clk_sys) begin
      counter  <=  counter + 1'd1;
      ce_cpu_p <= !counter[1] & !counter[0];
      ce_cpu_n <=  counter[1] & !counter[0];
      ce_65    <= !counter[0];
      ce_psg   <= !counter;
   end

   // Diagnostics
   //assign led = {ce_cpu_p, rom_e, ram_e, ram_we, mreq_n, nopgen_store, inverse};
   //assign led1 = {mod[0], 2'b0, key_data};

   //always @(posedge clk_sys) led2 <= ram_data_latch;
   assign led1 = bank_state >= 2;
   
   // We have our own pin but we get the same signal as the video
   // perhaps this is unecessary?
   assign mic = video_out;


   // Audio: TODO (original ZX81  does not have speaker)
   assign spk = 0;
   
   wire v;
   wire h;
   
   // Memory control signals
   wire iorq_n, mreq_n, rd_n, wr_n, wait_n, m1_n, int_n, rfsh_n, halt_n, nmi_n;

   wire busak_n;

   // Maskable interrupt
   wire int_n = addr[6];

   // ZX81 Logic
   reg [7:0] cpu_din;

   wire [7:0] cpu_dout;
   wire [15:0] addr;

   wire [4:0]  key_data;
   wire [11:1] Fn;
   wire [2:0]  mod;

   // Quantisize this so we get same signal into cpu as we
   // get out on the logic probe (offline simulator debug)
   reg 	       ear_r;
   // This will be set when instruction fetch from load code
   reg 	       doing_load=0;
	       
   reg 	       dbg_cs=1;
   reg 	       dbg_data=1;
   
   always @(posedge clk_sys) begin

      // Start the capture of the RC filtered analog sound
      if (~mreq_n && (addr == 16'h352 || addr == 16'h38b))
	doing_load=1;
      
      if (~iorq_n)
	begin
	   ear_r = ear;
	   if (doing_load)
	     begin
		dbg_data = ear;
		dbg_cs = 1;
	     end
	end
      else
	begin
	   dbg_data = 0;
	   dbg_cs = 0;
	end
      

   end

   
//   wire [7:0]  io_dout = kbd_n ? 8'hff : {1'b0, video_mode_r, 1'b0, key_data};
   wire [7:0]  io_dout = kbd_n ? 8'hff : {ear_r, video_mode_r, 1'b0, key_data};

   // When refresh is low, the ram_data_latch and row_counter are used to load
   // pixels corresponding to a character from the font in the rom
   wire [12:0] rom_a = rfsh_n ? addr[12:0] : { addr[12:9], ram_data_latch[5:0], row_counter };

   reg [1:0]   mem_size = { 1'b0, ram_size_r }; //00-1k, 01 - 16k 10 - 32k

   // Ram address
   reg [15:0]  ram_a;

   // These selectors are active-high
   
   // Selector for 64k ram extension
   wire        ram_e_64k = &mem_size & (addr[13] | (addr[15] & m1_n));

   // Selector for rom
   wire        rom_e  = ~addr[14] & (~addr[12] | zx81) & ~ram_e_64k;

   // Selector for ram 1k
//    wire        ram_e  = 0;
   wire        ram_e = (addr[14] & (mem_size == 2'b00)) | ram_e_64k;
//   wire        ram_e = (addr[14] | ram_e_64k);
 
   // Selector for ext ram
//   wire        ext_ram_e=0;
   wire        ext_ram_e  = (addr[14] & (mem_size == 2'b01)) | ram_e_64k;
//   wire        ext_ram_e  = addr[14] | ram_e_64k;
   
   // Write enable for ram
   wire        ram_we = ~wr_n & ~mreq_n & ram_e;

   // Selector for ouput data to ram
   wire [7:0]  ram_in = cpu_dout;

   // Selectors for data from ram or rom
   wire [7:0]  rom_out;
   wire [7:0]  ram_out;
   wire [7:0]  ext_ram_out;
   reg [7:0]   mem_out;
   
   // Address and data decoder
   always @* begin
      case({ rom_e, ram_e, ext_ram_e, bank_e })
        'b1000: mem_out = rom_out;
        'b0100: mem_out = ram_out;
	'b0010: mem_out = ext_ram_out;

	// experimenting with the bank, currently just rom :)
        'b1001: mem_out = ext_ram_out;
        'b0101: mem_out = ram_out;
	'b0011: mem_out = ext_ram_out;
        default: mem_out = 8'd0;
      endcase

      case(mem_size)
        'b00: ram_a = { 6'b010000,             addr[9:0] }; //1k
        'b01: ram_a = { 2'b01,                 addr[13:0] }; //16k
        'b10: ram_a = { 1'b0, addr[15] & m1_n, addr[13:0] } + 16'h4000; //32k
        'b11: ram_a = { addr[15] & m1_n,       addr[14:0] }; //64k
      endcase
      
      case({mreq_n, ~m1_n | iorq_n | rd_n})
	// Generate NOP during memory request when nopgen set 
	'b01: cpu_din = (~m1_n & nopgen) ? 8'h00 : mem_out; 
	'b10: cpu_din = io_dout;
	default cpu_din = 8'hFF;
      endcase
   end

   // Video 
   // Character generation
   
   localparam option_inverse = 1'b0;
   
   // Generate a NOP when executing a display list
   // NOP is generated when address bit 15 is set and stopped by a halt instruction (which has bit 6 set)
   // During this period mem_out will contain 6 pixels, with bit 6 low and bit 7 indicating invert
   wire      nopgen = addr[15] & ~mem_out[6] & halt_n;
   // Nopgen_store is set one cycle after nopgen
   reg       nopgen_store;
   wire      data_latch_enable = rfsh_n & ce_cpu_n & ~mreq_n;
   reg [7:0] ram_data_latch;
   reg [2:0] row_counter;
   wire      shifter_start = mreq_n & nopgen_store & ce_cpu_p & (~zx81 | ~nmi_latch);
   reg [7:0] shifter_reg;
   wire      video_out = (~option_inverse ^ shifter_reg[7] ^ inverse) & !back_porch_counter & csync;
   reg       inverse;
   reg [2:0] col_count;

   reg [4:0] back_porch_counter = 1;
   reg       old_csync;
   reg       old_shifter_start;

   reg       ic11,ic18,ic19_1,ic19_2;
   reg [7:0] sync_counter = 0;
   reg       nmi_latch;

   wire      kbd_n = iorq_n | rd_n | addr[0];
   wire      vsync_in = ic11;
   wire      hsync_in = ~(sync_counter >= 16 && sync_counter <= 31);
   wire      csync = vsync_in & hsync_in;
   
   always @(posedge clk_sys) begin
      old_csync <= csync;
      old_shifter_start <= shifter_start;

      if (data_latch_enable) begin
	 ram_data_latch <= mem_out;
	 nopgen_store <= nopgen;
      end
      
      if (mreq_n & ce_cpu_p) inverse <= 0;

      if (~old_shifter_start & shifter_start)
	inverse <= ram_data_latch[7];

      if (~old_shifter_start & shifter_start & (col_count > 2)) begin // col_count is a hack to avoid shifter_reg
	 col_count <= 0;                                               // getting reset early for some unknown reason
	 shifter_reg <= (~m1_n & nopgen) ? 8'h0 : mem_out;
      end else if (ce_65) begin
	 shifter_reg <= { shifter_reg[6:0], 1'b0 };
	 col_count <= col_count + 1;
      end

      if (old_csync & ~csync) row_counter <= row_counter + 1'd1;
      if (~vsync_in) row_counter <= 0;

      if (~old_csync & csync) back_porch_counter <= 1;
      if (ce_65 && back_porch_counter) back_porch_counter <= back_porch_counter + 1'd1;

   end
   
   // ZX80 sync generator
   //wire csync = ic19_2; // ZX80 original
   reg old_m1_n;

   always @(posedge clk_sys) begin
      old_m1_n <= m1_n;
      
      if (~(iorq_n | wr_n) & (~zx81 | ~nmi_latch)) ic11 <= 1;
      if (~kbd_n & (~zx81 | ~nmi_latch)) ic11 <= 0;

      if (~iorq_n) ic18 <= 1;
      if (~ic19_2) ic18 <= 0;

      if (old_m1_n & ~m1_n) begin
	 ic19_1 <= ~ic18;
	 ic19_2 <= ic19_1;
      end

      if (~ic11) ic19_2 <= 0;
   end

   // ZX81 upgrade
   reg    old_cpu_n;

   assign wait_n = ~(halt_n & ~nmi_n) | ~zx81;
   assign nmi_n = ~(nmi_latch & ~hsync_in) | ~zx81;
   
   always @(posedge clk_sys) begin
      old_cpu_n <= ce_cpu_n;

      if (old_cpu_n & ~ce_cpu_n) begin
	 sync_counter <= sync_counter + 1'd1;
	 if (sync_counter == 8'd206 | (~m1_n & ~iorq_n)) sync_counter <= 0;
      end

      if (zx81) begin
	 if (~iorq_n & ~wr_n & (addr[0] ^ addr[1])) nmi_latch <= addr[1];
      end
   end

   /* RAM */
   ram1k ram(
	     .clk(clk_sys),
	     .ce(ram_e),
	     .a(ram_a),
	     .din(cpu_dout),
	     .dout(ram_out),
	     .we(~wr_n & ~mreq_n)
	     );
   
   /* ROM */
   rom the_rom(
	       .clk(clk_sys),
	       .ce(rom_e),
	       .a({(zx81 ? rom_a[12] : 2'h2), rom_a[11:0]}), // Select ZX80 or ZX81 rom
	       //.din(cpu_dout),
	       .dout(rom_out),
	       //.we(1'b0)
	       );

   wire send_busrq_n;
   
   /* CPU */
   tv80n cpu(
	     // Outputs
	     .m1_n(m1_n), 
	     .mreq_n(mreq_n), 
	     .iorq_n(iorq_n), 
	     .rd_n(rd_n), 
	     .wr_n(wr_n), 
	     .rfsh_n(rfsh_n), 
	     .halt_n(halt_n), 
	     .busak_n(busak_n), 
	     .A(addr), 
	     .do(cpu_dout),
	     // Inputs
	     .di(cpu_din), 
	     .reset_n(reset_n), 
	     .clk(ce_cpu_n), 
	     .wait_n(wait_n), 
	     .int_n(int_n), 
	     .nmi_n(nmi_n), 
	     .busrq_n(send_busrq_n),
	     );

   // Keyboard matrix
   keyboard the_keyboard (
			  .reset(~reset_n),
			  .clk_sys(clk_sys),
			  .ps2_key(ps2_key),
			  .addr(addr),
			  .key_data(key_data),
			  .Fn(Fn),
			  .mod(mod),
			  );

   // Just pass composite video back to top level and pins
   always @(posedge clk_sys) begin

      video <= video_out;
      hsync <= hsync_in;
      vsync <= vsync_in;

   end

   // ram inject & friends 
   wire ri;
   wire ri_ce_n;
   wire ri_oe_n;
   wire ri_we_n;
   wire [17:0] ri_addr;
   wire [7:0]  ri_data;

   wire        ext_ram_e_sel;
   
   reg [7:0]  dataextmem=0;
  
   // We also now activate the extmem if the "bank_e" signal
   // goes high (needs sync when flipping)
   assign ext_ram_e_sel = bank_e ? rom_e | ext_ram_e : ext_ram_e;
   
   always @(posedge buffer_clk) begin
      // Simpleton logic for 16k extra RAM
      // Now with selector ram inject
      ce_n <= ri ? ri_ce_n : mreq_n | ~ext_ram_e_sel;

      we_n <= ri ? ri_we_n : wr_n | mreq_n | ~ext_ram_e_sel;
      oe_n <= ri ? ri_oe_n : rd_n | mreq_n | ~ext_ram_e_sel;

      // Ram injector can use full ram address range
//      areg[13:0] <= bank_e ? { 0, addr[12:0] } : (ri ? ri_addr[13:0] : addr[13:0]);
      areg[13:0] <= ri ? ri_addr[13:0] : (bank_e ? { 0, addr[12:0] } : addr[13:0]);

      
      // bank_e should now use 8k of the next 16k in the linear
      // sram area, so the start of rom area is from 16384 dec and on
      // when accessing from the ram inject mode (with the z80 halted
      // via BUSRQ.
//      areg[17:14] <= bank_e ? (rom_e ? 4'b0001 : 4'b0000) : (ri ? ri_addr[17:14] : 4'b0);
      areg[17:14] <= ri ? ri_addr[17:14] : (bank_e ? (rom_e ? 4'b0001 : 4'b0000) : 4'b0);
      
      dataextmem <= ri ? ri_data : cpu_dout;
      
   end

   tristate databus
     (
      .clk(buffer_clk),
      .dir(~we_n),
      .i(dataextmem),
      .o(ext_ram_out),
      .buff(dmem),
      );

   wire data_avail;
   wire send_strobe;
   wire [7:0] send_data;
   wire recv_strobe;
   wire [7:0] receive_data;
   
   // loop test
   serial ser(
	      .clock(buffer_clk), // 50mhz
	      .reset(~reset_n),
	      .dce_rxd(tx),
	      .dce_txd(rx),
	      .receive_data(receive_data),
	      .recv_strobe(recv_strobe),
	      .send_data(send_data),
	      .send_strobe(send_strobe),
	      .data_avail(data_avail),
	      );
   
   wire [15:0] break_addr;
   wire        break_flag;
   
   cmdline cmd(
	       .clock(buffer_clk),
	       .reset(~reset_n),
	       .receive_data(receive_data),
	       .recv_strobe(recv_strobe),
	       .send_data(send_data),
	       .send_strobe(send_strobe),
	       .data_avail(data_avail),
	       .busrq_n(send_busrq_n),
	       .busak_n(busak_n),

	       .ri(ri),
	       .ri_ce_n(ri_ce_n),
	       .ri_oe_n(ri_oe_n),
	       .ri_we_n(ri_we_n),
	       .ri_addr(ri_addr),
	       .ri_data(ri_data),
	       .ext_ram_out(ext_ram_out),
	       .addr(addr),

	       .break_addr(break_addr),
	       .break_flag(break_flag),
	       
	       .do_reset(do_reset),
	       );
   
     
endmodule

