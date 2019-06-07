`timescale 1ns/100ps
//FPU Testbench

module FPU_TESTBENCH;

  // Inputs
  reg [31:0] Xin, Yin;
  reg clk;
  //reg signed [63:0] i;
  reg reset;

  wire [31:0] Zout;
  wire done;
  
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
    Xin = 'b00000000011111111111111111111111; // 0 deg
    Yin = 'b00000000000000000000000000000001;
    reset = 1'b1;
    #2 reset = 1'b0;
    
    //Test 5
    #80
    Yin = 'b00000000011111111111111111111111; // 0 deg
    Xin = 'b00000000000000000000000000000001;
    reset = 1'b1;
    #2 reset = 1'b0;
    
    //Test 5
    #80
    Xin = 'b00000000100000000000000000000000; // 0 deg
    Yin = 'b10000000000000000000000000000001;
    reset = 1'b1;
    #2 reset = 1'b0;
    
    //Test 5
    #80
    Xin = 'b00000000100000000000000000000000; // 0 deg
    Yin = 'b10000001000000000000000000000001;
    reset = 1'b1;
    #2 reset = 1'b0;

   #500
   $write("Simulation has finished");
   //$stop;

  end

  adder test_run(Xin, Yin, clk, reset, Zout, done);

endmodule
