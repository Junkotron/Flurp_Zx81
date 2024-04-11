

module testbench;
   reg clk;
   
   initial begin
      $dumpfile("testbench.vcd");
      #5 clk = 0;
      repeat (100) clk = ~clk;
      $finish;
   end
   
endmodule
