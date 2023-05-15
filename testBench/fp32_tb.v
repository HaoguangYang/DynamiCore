`timescale 1ns/100ps
// FPU Testbench
// Author: Haoguang Yang

module FPU_TESTBENCH;

  // Inputs
  reg [31:0] Xin, Yin;
  reg clk;
  //reg signed [63:0] i;
  reg reset;

  wire [31:0] Zadd, Zmul;
  wire doneAdd, doneMul;
  
  integer i;
  shortreal Xreal, Yreal, ZaddReal, ZmulReal;
  
  initial begin
      clk = 'b0;
      forever
      begin
        #5 clk = !clk;
      end
  end
  
  adder test_add(Xin, Yin, clk, reset, Zadd, doneAdd);
  multiplier test_mul(Xin, Yin, clk, reset, Zmul, doneMul);
    
  initial begin
    #5
    // generate 1000 random numbers for testing
    for(i=0; i<1000; i=i+1)
    begin
      @(posedge clk)
      Xin = {$random()};
      Yin = {$random()};
      Xreal = $bitstoshortreal(Xin);
      Yreal = $bitstoshortreal(Yin);
      ZaddReal = Xreal + Yreal;
      ZmulReal = Xreal * Yreal;
      reset = 1'b1;
      #5 reset = 1'b0;
      wait (doneAdd == 1'b1);
      if (Zadd != $shortrealtobits(ZaddReal)) begin
        $display("Error in #%d: Verilog and C results are not consistent: %1.20e + %1.20e = %1.20e (0b%b)[got %1.20e (0b%b)]",
          i, $bitstoshortreal(Xin), $bitstoshortreal(Yin), ZaddReal, $shortrealtobits(ZaddReal), $bitstoshortreal(Zadd), Zadd);
      end
      wait (doneMul == 1'b1);
      if (Zmul != $shortrealtobits(ZmulReal)) begin
        $display("Error in #%d: Verilog and C results are not consistent: %1.20e * %1.20e = %1.20e (0b%b)[got %1.20e (0b%b)]",
          i, $bitstoshortreal(Xin), $bitstoshortreal(Yin), ZmulReal, $shortrealtobits(ZmulReal), $bitstoshortreal(Zmul), Zmul);
      end
    end

   $write("Simulation has finished");
   //$stop;

  end

endmodule
