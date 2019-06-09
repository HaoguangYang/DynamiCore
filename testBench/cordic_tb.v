`timescale 1ns/100ps
//CORDIC Testbench for sine and cosine

module CORDIC_TESTBENCH;

  localparam width = 32; //width of x and y

  // Inputs
  reg [width-1:0] Xin, Yin;
  reg [31:0] angle;
  reg clk;
  //reg signed [63:0] i;
  reg reset;

  wire [width-1:0] COSout, SINout;
  wire done;

  localparam An = 1073741824/0.82338012906;
  //32000/1.647;
  //2147483648/1.64676025812
  
  initial begin
      Xin = An;     // Xout = 32000*cos(angle)
      Yin = 0;      // Yout = 32000*sin(angle)
  
      //set clock
      clk = 'b0;
      forever
      begin
        #2 clk = !clk;
      end
  end
    
  initial begin

    //set initial values
    angle = 'b00110101010101010101010101010101;
    reset = 1'b1;
    #2 reset = 1'b0;

    // Test 1
    #800                                           
    angle = 'b00100000000000000000000000000000;    // example: 45 deg = 45/360 * 2^32 = 32'b00100000000000000000000000000000 = 45.000 degrees -> atan(2^0)
    reset = 1'b1;
    #2 reset = 1'b0;

    // Test 2
    #800
    angle = 'b00101010101010101010101010101010; // 60 deg
    reset = 1'b1;
    #2 reset = 1'b0;

    // Test 3
    #800
    angle = 'b01000000000000000000000000000000; // 90 deg
    reset = 1'b1;
    #2 reset = 1'b0;

    // Test 4
    #800
    angle = 'b00110101010101010101010101010101; // 75 deg
    reset = 1'b1;
    #2 reset = 1'b0;    
    
    //Test 5
    #800
    angle = 'b00000000000000000000000000000000; // 0 deg
    reset = 1'b1;
    #2 reset = 1'b0;

   #500
   $write("Simulation has finished");
   //$stop;

  end

  CORDIC TEST_RUN(clk, COSout, SINout, Xin, Yin, angle,reset, done);

  // Monitor the output
  initial
  $monitor($time, , COSout, , SINout, , angle);

endmodule


