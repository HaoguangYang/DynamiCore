`timescale 1ns/1ps
//IEEE Floating Point Adder (Single Precision)
//Copyright (C) Haoguang Yang
//2019-06-05

module adder(
        input_a,
        input_b,
        clk,
        rst,
        output_z,
        done);

  input     clk;
  input     rst;

  input     [31:0] input_a;
  input     [31:0] input_b;
  output    [31:0] output_z;
  output    done;

  reg       s_output_z_stb;

  reg       [1:0] state;
  parameter special_cases = 2'd0,
            add           = 2'd1,
            normalise     = 2'd2,
            pack          = 2'd3;

  reg       [31:0] a, b, z;
  wire      [22:0] a_ms, b_ms;
  reg       [26:0] a_m, b_m;
  wire      [7:0] a_es, b_es;
  reg       [7:0] z_e;
  wire      a_ss, b_ss;
  reg       z_s;
  reg       [27:0] z_m;
  
  assign a_ms = a[22 : 0];
  assign b_ms = b[22 : 0];
  assign a_es = a[30 : 23];
  assign b_es = b[30 : 23];
  assign a_ss = a[31];
  assign b_ss = b[31];

  task float_shift_left;
  inout [27:0] m;
  inout [7:0] e;
  input [4:0] s_max;
  begin
    if (e >= s_max) begin
        m = m <<< s_max;
        e = e - s_max + 1;
    end else begin
        m = m <<< e;
        e = 0;
    end
  end
  endtask
  

  always @(clk or rst)
  begin
    case(state)
      special_cases:
      begin
        //if a is NaN or b is NaN return NaN 
        if ((a_es == 255 && a_ms != 0) || (b_es == 255 && b_ms != 0)) begin
          z[31] <= 1;
          z[30:23] <= 255;
          z[22] <= 1;
          z[21:0] <= 0;
          s_output_z_stb <= 1;
        //if a is inf return inf
        end else if (a_es == 255) begin
          z[30:23] <= 255;
          //if b is inf and signs don't match return nan
          if ((b_es == 255) && (a_ss != b_ss)) begin
              z[31] <= b_ss;
              z[22] <= 1;
              z[21:0] <= 0;
          end else begin
              z[31] <= a_ss;
              z[22:0] <= 0;
          end
          s_output_z_stb <= 1;
        //if b is inf return inf
        end else if (b_es == 255) begin
          z[31] <= b_ss;
          z[30:23] <= 255;
          z[22:0] <= 0;
          s_output_z_stb <= 1;
        // 0 + 0
        end else if (((a_es == 0) && (a_ms == 0)) && ((b_es == 0) && (b_ms == 0))) begin
          z[31] <= a_ss & b_ss;
          z[30:0] <= 31'b0;
          s_output_z_stb <= 1;
        //if a is zero return b
        end else if (((a_es == 0) && (a_ms == 0)) || ((b_es > a_es) && (b_es - a_es > 27))) begin
          z[31] <= b_ss;
          z[30:23] <= b_es[7:0];
          z[22:0] <= b_ms;
          s_output_z_stb <= 1;
        //if b is zero return a
        end else if (((b_es == 0) && (b_ms == 0)) || ((b_es < a_es) && (a_es - b_es > 27))) begin
          z[31] <= a_ss;
          z[30:23] <= a_es[7:0];
          z[22:0] <= a_ms;
          s_output_z_stb <= 1;
        end else if ((a_ss == ~b_ss) && (a_es == b_es) && (a_ms == b_ms)) begin
          //a-a = 0
          z <= 32'b0;
          s_output_z_stb <= 1;
        end else begin
          // alignment, determining approx. final exp.
          if (a_es > b_es) begin
            if (b_es == 0) begin
                // b_es actually is 1 but denoted as 0
                if (a_es > 4 && b_ms[a_es - 5])
                    b_m <= ({1'b0, b_ms, 3'b000} >>> (a_es - 1)) + 27'h0000001;
                else
                    b_m <= ({1'b0, b_ms, 3'b000} >>> (a_es - 1));
            end else begin
                if (a_es - b_es > 3 && b_ms[a_es - b_es - 4])
                    b_m <= ({1'b1, b_ms, 3'b000} >>> (a_es - b_es)) + 27'h0000001;
                else
                    b_m <= ({1'b1, b_ms, 3'b000} >>> (a_es - b_es));
            end
            a_m <= {1'b1, a_ms, 3'b000};
            z_e <= a_es;
          end else if (a_es < b_es) begin
            if (a_es == 0) begin
                // a_es actually is 1 but denoted as 0
                if (b_es > 4 && a_ms[b_es - 5])
                    a_m <= ({1'b0, a_ms, 3'b000} >>> (b_es - 1)) + 27'h0000001;
                else
                    a_m <= ({1'b0, a_ms, 3'b000} >>> (b_es - 1));
            end else begin
                if (b_es - a_es > 3 && a_ms[b_es - a_es - 4])
                    a_m <= ({1'b1, a_ms, 3'b000} >>> (b_es - a_es)) + 27'h0000001;
                else
                    a_m <= ({1'b1, a_ms, 3'b000} >>> (b_es - a_es));
            end
            b_m <= {1'b1, b_ms, 3'b000};
            z_e <= b_es;
          end else begin    // a_es == b_es
            if (a_es == 0) begin
                z_e <= 1;
                a_m <= {1'b0, a_ms, 3'b000};
                b_m <= {1'b0, b_ms, 3'b000};
            end else begin
                z_e <= a_es;
                a_m <= {1'b1, a_ms, 3'b000};
                b_m <= {1'b1, b_ms, 3'b000};
            end
          end
          state <= add;
        end
      end

      add:
      begin
        z_s <= (~(a_ss == b_ss) && (a_m < b_m))? b_ss : a_ss;
        z_m <= (a_ss == b_ss)? a_m + b_m:
               (a_m >= b_m)?   a_m - b_m:
                               b_m - a_m;
        state <= normalise;
      end

      normalise:
      begin
      if (z_m[27]) begin
        z_e <= z_e + 1;
      end else begin
        casex(z_m[26:0])
            27'b1??????????????????????????: float_shift_left(z_m, z_e, 5'd01);
	        27'b01?????????????????????????: float_shift_left(z_m, z_e, 5'd02);
            27'b001????????????????????????: float_shift_left(z_m, z_e, 5'd03);
	        27'b0001???????????????????????: float_shift_left(z_m, z_e, 5'd04);
	        27'b00001??????????????????????: float_shift_left(z_m, z_e, 5'd05);
	        27'b000001?????????????????????: float_shift_left(z_m, z_e, 5'd06);
	        27'b0000001????????????????????: float_shift_left(z_m, z_e, 5'd07);
	        27'b00000001???????????????????: float_shift_left(z_m, z_e, 5'd08);
	        27'b000000001??????????????????: float_shift_left(z_m, z_e, 5'd09);
	        27'b0000000001?????????????????: float_shift_left(z_m, z_e, 5'd10);
	        27'b00000000001????????????????: float_shift_left(z_m, z_e, 5'd11);
	        27'b000000000001???????????????: float_shift_left(z_m, z_e, 5'd12);
	        27'b0000000000001??????????????: float_shift_left(z_m, z_e, 5'd13);
	        27'b00000000000001?????????????: float_shift_left(z_m, z_e, 5'd14);
	        27'b000000000000001????????????: float_shift_left(z_m, z_e, 5'd15);
	        27'b0000000000000001???????????: float_shift_left(z_m, z_e, 5'd16);
	        27'b00000000000000001??????????: float_shift_left(z_m, z_e, 5'd17);
	        27'b000000000000000001?????????: float_shift_left(z_m, z_e, 5'd18);
	        27'b0000000000000000001????????: float_shift_left(z_m, z_e, 5'd19);
	        27'b00000000000000000001???????: float_shift_left(z_m, z_e, 5'd20);
	        27'b000000000000000000001??????: float_shift_left(z_m, z_e, 5'd21);
	        27'b0000000000000000000001?????: float_shift_left(z_m, z_e, 5'd22);
	        27'b00000000000000000000001????: float_shift_left(z_m, z_e, 5'd23);
	        27'b000000000000000000000001???: float_shift_left(z_m, z_e, 5'd24);
            27'b0000000000000000000000001??: float_shift_left(z_m, z_e, 5'd25);
            27'b00000000000000000000000001?: float_shift_left(z_m, z_e, 5'd26);
            27'b00000000000000000000000000?: float_shift_left(z_m, z_e, 5'd27);
	    endcase
      end
      state <= pack;
      end

      pack:
      begin
      if (~s_output_z_stb) begin
        //z[22 : 0] <= (z_e[7:0] == 8'b11111111)? 23'b0 : z_m[26:4];
        z[22 : 0] <= (z_e[7:0] == 8'b11111111)? 23'b0 : z_m[26:4] + (z_m[3] && (z_m[2] || z_m[1] || z_m[0] || z_m[4]));
        //z[30 : 23] <= z_e[7:0];
        z[30 : 23] <= z_e[7:0] + ((z_m[26:4] == 23'h7fffff) && (z_m[3] && (z_m[2] || z_m[1] || z_m[0] || z_m[4])));
        z[31] <= z_s;
        s_output_z_stb <= 1;
      end
      end

    endcase

    if (rst == 1) begin
      a <= input_a;
      b <= input_b;
      state <= special_cases;
      z <= 32'bZ;
      s_output_z_stb <= 0;
    end

  end

  assign done = s_output_z_stb;
  assign output_z = z;

endmodule
