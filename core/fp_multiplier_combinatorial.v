`timescale 1 ns / 1 ps
(* use_dsp = "no" *) module fp_multiplier_combinatorial # (
        parameter integer EXPONENT_BITS = 11,
        parameter integer MANTISSA_BITS = 52
    ) (
        input wire [EXPONENT_BITS+MANTISSA_BITS:0] a,  // 64-bit floating-point input a
        input wire [EXPONENT_BITS+MANTISSA_BITS:0] b,  // 64-bit floating-point input b
        output wire [EXPONENT_BITS+MANTISSA_BITS:0] product, // 64-bit floating-point product
        output wire overflow, // Overflow flag
        output wire underflow, // Underflow flag
        output wire output_valid
    );

    // function called clogb2 that returns an integer which has the
    // value of the ceiling of the log base 2.
    function integer clogb2 (input integer bit_depth);
        begin
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    localparam integer FP_MSB = EXPONENT_BITS + MANTISSA_BITS;
    localparam integer SHIFT_COUNTER_BITS = clogb2(MANTISSA_BITS+MANTISSA_BITS+2);

    // Internal signals
    wire sign_a, sign_b, sign_product;
    wire [EXPONENT_BITS-1 : 0] exp_a, exp_b, exp_product;
    wire [MANTISSA_BITS : 0] frac_a, frac_b;
    wire [MANTISSA_BITS-1 : 0] frac_product;
    wire signed [EXPONENT_BITS+1 : 0] exp_sum;
    wire [EXPONENT_BITS : 0] exp_sum_nonneg, exp_prod_prerounding;
    wire [MANTISSA_BITS+MANTISSA_BITS+1 : 0] frac_full_product;
    
    wire zero_a, zero_b, inf_a, inf_b, nan_a, nan_b;

    // Assign sign, exponent, and fraction fields
    assign sign_a = a[FP_MSB];
    assign sign_b = b[FP_MSB];
    assign exp_a = a[FP_MSB-1 : MANTISSA_BITS];
    assign exp_b = b[FP_MSB-1 : MANTISSA_BITS];
    
    // Check if the number is subnormal or zero
    wire is_subnormal_a = (exp_a == {(EXPONENT_BITS){1'b0}});
    wire is_subnormal_b = (exp_b == {(EXPONENT_BITS){1'b0}});
    
    // If the number is subnormal, use the fraction as is; otherwise, add the implicit leading 1
    assign frac_a = is_subnormal_a ? {1'b0, a[MANTISSA_BITS-1 : 0]} : {1'b1, a[MANTISSA_BITS-1 : 0]};
    assign frac_b = is_subnormal_b ? {1'b0, b[MANTISSA_BITS-1 : 0]} : {1'b1, b[MANTISSA_BITS-1 : 0]};
    
    // Check special cases: zero, infinity, NaN
    wire a_mantissa_zero = (a[MANTISSA_BITS-1 : 0] == 0);
    wire b_mantissa_zero = (b[MANTISSA_BITS-1 : 0] == 0);
    assign zero_a = is_subnormal_a && a_mantissa_zero;
    assign zero_b = is_subnormal_b && b_mantissa_zero;
    
    wire a_exp_is_oflow = (exp_a == {(EXPONENT_BITS){1'b1}});
    wire b_exp_is_oflow = (exp_b == {(EXPONENT_BITS){1'b1}});
    assign inf_a = a_exp_is_oflow && a_mantissa_zero;
    assign inf_b = b_exp_is_oflow && b_mantissa_zero;
    assign nan_a = a_exp_is_oflow && (!a_mantissa_zero);
    assign nan_b = b_exp_is_oflow && (!b_mantissa_zero);
    
    // Compute the product sign
    assign sign_product = sign_a ^ sign_b;

    // Multiply the fractions
    assign frac_full_product = frac_a * frac_b;
    
    // Compute the sum of exponents (subtract bias of 1023)
    assign exp_sum = exp_a - {{(EXPONENT_BITS-2){1'b1}}, 1'b0} + exp_b;

    // waterfall to determine how many bits to shift
    wire [SHIFT_COUNTER_BITS-1 : 0] frac_prod_shift_gen [MANTISSA_BITS+MANTISSA_BITS : 0];
    assign frac_prod_shift_gen[MANTISSA_BITS+MANTISSA_BITS] = frac_full_product[1] ? MANTISSA_BITS+MANTISSA_BITS : MANTISSA_BITS+MANTISSA_BITS+1;
    genvar i;
    generate
        for (i = MANTISSA_BITS+MANTISSA_BITS; i > 0; i=i-1)
        begin
            assign frac_prod_shift_gen[i-1] = frac_full_product[MANTISSA_BITS+MANTISSA_BITS+2-i] ? i-1 : frac_prod_shift_gen[i];
        end
    endgenerate
    
    // determine a non-negative exponent
    wire limit_left_shift = (exp_sum <= frac_prod_shift_gen[0]);
    assign exp_sum_nonneg = limit_left_shift ? 0 : (exp_sum - frac_prod_shift_gen[0]);
    

    wire [MANTISSA_BITS+MANTISSA_BITS+1 : 0] frac_prod_shifted;
    assign frac_prod_shifted = (exp_sum > 0) ? (frac_full_product << (limit_left_shift ? exp_sum : frac_prod_shift_gen[0])) :
                                               (frac_full_product >> -exp_sum);
    assign frac_product = frac_prod_shifted[MANTISSA_BITS+MANTISSA_BITS : MANTISSA_BITS+1];
    
    assign exp_prod_prerounding = (!frac_prod_shifted[MANTISSA_BITS+MANTISSA_BITS+1]) ? 0 :
                                  ((exp_sum_nonneg == 0) && frac_prod_shifted[MANTISSA_BITS+MANTISSA_BITS+1]) ? 1 : exp_sum_nonneg;

    // Extract the guard, round, and sticky bits for rounding
    wire guard, round, sticky;
    assign guard = frac_prod_shifted[MANTISSA_BITS];
    assign round = frac_prod_shifted[MANTISSA_BITS-1];
    assign sticky = frac_prod_shifted[MANTISSA_BITS-2]; // |(frac_prod_shifted[MANTISSA_BITS-2:0])

    // Apply round-to-nearest-even
    wire round_up;
    assign round_up = (guard && (round || sticky || frac_product[0]));
    
    wire [FP_MSB : 0] rounded_prod_no_sign = {exp_prod_prerounding, frac_product} + round_up;
    
    // Handle special cases and set the output product
    assign product = (nan_a || nan_b) ? { sign_product, {a[FP_MSB-1:0] | b[FP_MSB-1:0]} } :
                     (inf_a || inf_b) ? ((zero_a || zero_b) ? { 1'b0, {(EXPONENT_BITS){1'b1}}, 1'b1, {(MANTISSA_BITS-1){1'b0}} } : { sign_product, {(EXPONENT_BITS){1'b1}}, {(MANTISSA_BITS){1'b0}} }) :
                     (zero_a || zero_b) ? {sign_product, {(EXPONENT_BITS+MANTISSA_BITS){1'b0}}} :
                     (rounded_prod_no_sign[FP_MSB : MANTISSA_BITS] >= {(EXPONENT_BITS){1'b1}}) ? { sign_product, {(EXPONENT_BITS){1'b1}}, {(MANTISSA_BITS){1'b0}} } :
                     {sign_product, rounded_prod_no_sign[FP_MSB-1 : 0]};
    
    // Overflow and underflow detection
    assign overflow = &(product[FP_MSB-1 : MANTISSA_BITS]);
    assign underflow = !(|(product[FP_MSB-1 : MANTISSA_BITS]));

endmodule
