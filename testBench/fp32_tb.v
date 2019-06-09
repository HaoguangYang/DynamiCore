`timescale 1ns/100ps
// FPU Testbench
// Author: Haoguang Yang

module FPU_TESTBENCH;

  // Inputs
  reg [31:0] Xin, Yin;
  reg clk;
  //reg signed [63:0] i;
  reg reset;

  wire [31:0] Zout, Zout2;
  wire done, done2;
  
  initial begin
      clk = 'b0;
      forever
      begin
        #2 clk = !clk;
      end
  end
    
  initial begin

    //set initial values
    //Xin = 'b00110101010101010101010101010101;
    //Yin = 'b00110101010101010101010101010101;
    //reset = 1'b1;
    //#2 reset = 1'b0;

    // Test 1
    //#80                                           
    Xin = 'b00111111010011001100110011001101;    // 0.8
    Yin = 'b10111111001100110011001100110011;    // -0.7
    reset = 1'b1;
    #2 reset = 1'b0;

    // Test 2
    #80
    Yin = 'b00111111010011001100110011001101;    // 0.8
    Xin = 'b10111111001100110011001100110011;    // -0.7
    reset = 1'b1;
    #2 reset = 1'b0;

    // Test 3
    #80
    Xin = 'b10111111010011001100110011001101;    // -0.8
    Yin = 'b00111111001100110011001100110011;    // 0.7
    reset = 1'b1;
    #2 reset = 1'b0;

    // Test 4
    #80
    Yin = 'b10111111010011001100110011001101;    // -0.8
    Xin = 'b00111111001100110011001100110011;    // 0.7
    reset = 1'b1;
    #2 reset = 1'b0;    
    
    //Test 5
    #80
    Xin = 'b00000000011111111111111111111111;   //1.1754942E-38
    Yin = 'b00000000000000000000000000000001;   //1.4E-45
    reset = 1'b1;
    #2 reset = 1'b0;
    
    //Test 6
    #80
    Yin = 'b00000000111111111111111111111111; // 2.3509886E-38
    Xin = 'b00000000000000000000000000000001; // 1.4E-45
    reset = 1'b1;
    #2 reset = 1'b0;
    
    //Test 7
    #80
    Xin = 'b00000000100000000000000000000000; // 1.17549435E-38
    Yin = 'b10000000000000000000000000000001; // -1.4E-45
    reset = 1'b1;
    #2 reset = 1'b0;
    
    //Test 8
    #80
    Xin = 'b00000000100000000000000000000000; // 1.17549435E-38
    Yin = 'b10000001000000000000000000000001; //-2.350989E-38
    reset = 1'b1;
    #2 reset = 1'b0;
    
    //Test 9
    #80
    Xin = 'b01000000001000000000000000000000; // 2.5
    Yin = 'b11000000001000000000000000000000; //-2.5
    reset = 1'b1;
    #2 reset = 1'b0;

   #500
   $write("Simulation has finished");
   //$stop;

  end

  adder test_run(Xin, Yin, clk, reset, Zout, done);
  multiplier test_run2(Xin, Yin, clk, reset, Zout2, done2);

endmodule
