`timescale 1ns/1ps
//IEEE Floating Point Multiplier (Single Precision)
//Copyright (C) Haoguang Yang
//2019-06-09

module multiplier(
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
            mult          = 2'd1,
            normalise     = 2'd2,
            pack          = 2'd3;

  reg       [8:0] a_e, b_e;
  
  reg       [31:0] a, b, z;
  wire      [22:0] a_ms, b_ms;
  reg       [23:0] a_m, b_m;
  wire      [7:0] a_es, b_es;
  reg       [8:0] z_e;
  wire      a_ss, b_ss;
  reg       [47:0] z_m;
  
  assign a_ms = a[22 : 0];
  assign b_ms = b[22 : 0];
  assign a_es = a[30 : 23];
  assign b_es = b[30 : 23];
  assign a_ss = a[31];
  assign b_ss = b[31];
  
  task float_shift_left;
  inout [46:0] m;
  inout [7:0] e;
  input [4:0] s_max;
  begin
    if (e > s_max) begin
        m = m <<< s_max;
        e = e - s_max;
    end else if (e>0) begin
        m = m <<< (e-1);
        e = 0;
    end
  end
  endtask

  always @(clk or rst)
  begin

    case(state)

      special_cases:
      begin
		z[31] <= a_ss ^ b_ss;
        //if a is NaN or b is NaN return NaN 
        if ((a_es == 255 && a_ms != 0) || (b_es == 255 && b_ms != 0)) begin
            z[30:23] <= 255;
            z[22] <= 1;
            z[21:0] <= 0;
            s_output_z_stb <= 1;
        //if a is inf return inf
        end else if (a_es == 255) begin
            z[30:23] <= 255;
            //if b is zero return NaN
            if ((b_es == 0) && (b_ms == 0)) begin
                z[22] <= 1;
                z[21:0] <= 0;
            end else begin
                z[22:0] <= 0;
            end
            s_output_z_stb <= 1;
        //if b is inf return inf
        end else if (b_es == 255) begin
            z[30:23] <= 255;
            //if a is zero return NaN
            if ((a_es == 0) && (a_ms == 0)) begin
                z[22] <= 1;
                z[21:0] <= 0;
            end else begin
                z[22:0] <= 0;
            end
            s_output_z_stb <= 1;
        //if overflows return inf
        end else if ((a_es > 191) && (b_es > 191)) begin
            z[30:23] <= 255;
            z[22:0] <= 0;
            s_output_z_stb <= 1;
        //if a or b is zero return zero, if underflows return 0
        end else if (((a_es == 0) && (a_ms == 0)) || ((b_es == 0) && (b_ms == 0)) || ((a_es < 51) && (b_es < 51))) begin
          z[30:0] <= 0;
          s_output_z_stb <= 1;
        end else begin
		  a_m[22:0] <= a_ms;
		  b_m[22:0] <= b_ms;
          //Denormalised Number
          if (a_es == 0) begin
            a_e <= 1;
			a_m[23] <= 0;
          end else begin
		    a_e <= a_es;
            a_m[23] <= 1;
          end
          //Denormalised Number
          if (b_es == 0) begin
            b_e <= 1;
			b_m[23] <= 0;
          end else begin
		    b_e <= b_es;
            b_m[23] <= 1;
          end
          state <= mult;
        end
      end

      mult:
      begin
        z_e <= a_e - 127 + b_e;
        z_m <= a_m * b_m;
        state <= normalise;
      end

      normalise:
      begin
        if (z_m[47] == 1) begin
          z_e <= z_e + 1;
          z_m <= z_m >>> 1;
		end else begin casex (z_m[46:23])
			24'b01??????????????????????: float_shift_left(z_m, z_e, 5'd01);
			24'b001?????????????????????: float_shift_left(z_m, z_e, 5'd02);
			24'b0001????????????????????: float_shift_left(z_m, z_e, 5'd03);
			24'b00001???????????????????: float_shift_left(z_m, z_e, 5'd04);
			24'b000001??????????????????: float_shift_left(z_m, z_e, 5'd05);
			24'b0000001?????????????????: float_shift_left(z_m, z_e, 5'd06);
			24'b00000001????????????????: float_shift_left(z_m, z_e, 5'd07);
			24'b000000001???????????????: float_shift_left(z_m, z_e, 5'd08);
			24'b0000000001??????????????: float_shift_left(z_m, z_e, 5'd09);
			24'b00000000001?????????????: float_shift_left(z_m, z_e, 5'd10);
			24'b000000000001????????????: float_shift_left(z_m, z_e, 5'd11);
			24'b0000000000001???????????: float_shift_left(z_m, z_e, 5'd12);
			24'b00000000000001??????????: float_shift_left(z_m, z_e, 5'd13);
			24'b000000000000001?????????: float_shift_left(z_m, z_e, 5'd14);
			24'b0000000000000001????????: float_shift_left(z_m, z_e, 5'd15);
			24'b00000000000000001???????: float_shift_left(z_m, z_e, 5'd16);
			24'b000000000000000001??????: float_shift_left(z_m, z_e, 5'd17);
			24'b0000000000000000001?????: float_shift_left(z_m, z_e, 5'd18);
			24'b00000000000000000001????: float_shift_left(z_m, z_e, 5'd19);
			24'b000000000000000000001???: float_shift_left(z_m, z_e, 5'd20);
			24'b0000000000000000000001??: float_shift_left(z_m, z_e, 5'd21);
			24'b00000000000000000000001?: float_shift_left(z_m, z_e, 5'd22);
			24'b00000000000000000000000?: float_shift_left(z_m, z_e, 5'd23);
			endcase
	    end
        state <= pack;
      end

      pack:
      begin
      if (~s_output_z_stb) begin
        //z[31] <= z_s;
        // denormalized result
        if (z_e <= 1 && z_m[46] == 0) begin
          z[30 : 23] <= 0;
          z[22 : 0] <= z_m[45:23] + (z_m[22] && (z_m[21] || z_m[20] || z_m[19] || z_m[23]));
        end else if (z_e == 0 && z_m[46] == 1) begin
          z[30 : 24] <= 0;
          z[23 : 0] <= z_m[46:23] + (z_m[22] && (z_m[21] || z_m[20] || z_m[19] || z_m[23]));
        end else if (z_e > 489) begin
          z[30 : 23] <= 0;
          z[22 : 0] <= (z_m[46:23] >>> (511-z_e+2)) +
            (z_m[511-z_e+24] && (z_m[511-z_e+23] || z_m[511-z_e+22] || z_m[511-z_e+21] || z_m[511-z_e+25]));
        end else if (z_e > 383) begin
          z[30 : 0] <= 0;
        end else if (z_e > 254) begin
          //if overflow occurs, return inf
          z[22 : 0] <= 0;
          z[30 : 23] <= 255;
        end else begin
          // default
          z[30 : 23] <= z_e[7:0];
          z[22 : 0] <= z_m[45:23] + (z_m[22] && (z_m[21] || z_m[20] || z_m[19] || z_m[23]));
        end
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

