`timescale 1 ns / 1 ps

module user_logic # (
        parameter integer C_M_AXI_ADDR_WIDTH = 32,
        parameter integer C_M_AXI_DATA_WIDTH = 32,
        parameter integer C_S_AXI_ADDR_WIDTH = 6,
        parameter integer C_S_AXI_DATA_WIDTH = 32
    ) (
        // Global Clock Signal
        input wire  ACLK,
        // Global Reset Signal. This Signal is Active LOW
        input wire  ARESETN,

        // interface to the slave bus
        // write enabled
        input wire mosi_req_in,
        // Target address to write
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] mosi_addr_in,
        // Data to write
        input wire [C_S_AXI_DATA_WIDTH-1 : 0] mosi_data_in,
        // Mask applied to MOSI data, aligned in bytes
        input wire [C_S_AXI_DATA_WIDTH/8-1 : 0] mosi_data_in_mask,
        // Master In Slave Out (Read) ports
        input wire miso_req_in,
        // Target address to read
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] miso_addr_in,
        // Data to be sent out by this slave. Ignored in master-write direction
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] miso_data_out,

        // interface to the master bus
        // User need to unset this bit to wait for miso_data_valid, if reading miso_data.
        output reg  mosi_data_out_valid,
        // Whether to perform master-write (MOSI)
        output reg  mosi_req_out,
        // Target addr to master-write
        output reg [C_M_AXI_ADDR_WIDTH-1 : 0] mosi_addr_out,
        // Data to be written to mosi_addr, ignored if not mosi_req
        output reg [C_M_AXI_DATA_WIDTH-1 : 0] mosi_data_out,
        // Mask applied to MOSI data, aligned in bytes
        output reg [C_M_AXI_DATA_WIDTH/8-1 : 0] mosi_data_out_mask,
        // whether all writes have been flushed
        input wire mosi_out_queue_empty,
        // Whether to perform master-read (MISO)
        output reg miso_req_out,
        // Target addr to master-read
        output reg [C_M_AXI_ADDR_WIDTH-1 : 0] miso_addr_out,
        // Whether input is acknoledged and output (miso data) is valid
        input wire miso_data_in_valid,
        // Data read from miso_addr, not updated if not miso_req
        input wire [C_M_AXI_DATA_WIDTH-1 : 0] miso_data_in,
        // Whether read queue is empty. The signal is useful when ensuring write-after-read and read-after-read data consistency
        input wire miso_queue_empty,
        // Indicator for upstream core to wait
        input wire master_stalled
    );

    // function called clogb2 that returns an integer which has the
    // value of the ceiling of the log base 2.
    function integer clogb2 (input integer bit_depth);
        begin
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    localparam integer S_AXI_ADDR_LSB = clogb2((C_S_AXI_DATA_WIDTH/8) - 1);

    // local memory
    reg [C_S_AXI_DATA_WIDTH-1 : 0] mem [(1<<(C_S_AXI_ADDR_WIDTH-S_AXI_ADDR_LSB))-1 : 0];

    wire [C_S_AXI_ADDR_WIDTH-S_AXI_ADDR_LSB-1 : 0] mosi_reg_addr;
    assign mosi_reg_addr = mosi_addr_in[C_S_AXI_ADDR_WIDTH-1 : S_AXI_ADDR_LSB];
    wire [C_S_AXI_ADDR_WIDTH-S_AXI_ADDR_LSB-1 : 0] miso_reg_addr;
    assign miso_reg_addr = miso_addr_in[C_S_AXI_ADDR_WIDTH-1 : S_AXI_ADDR_LSB];
    
    // MISO read from address space of this module
    always @(posedge ACLK)
        miso_data_out <= miso_req_in ? mem[miso_reg_addr] : miso_data_out;

    // MOSI write to address space of this module
    wire [C_S_AXI_DATA_WIDTH-1 : 0] data_to_write;
    // generate masked write data signal
    genvar k;
    generate
        for(k=0; k<C_S_AXI_DATA_WIDTH/8; k=k+1)
        begin
            wire [7:0] passthrough_byte;
            assign passthrough_byte = mem[mosi_reg_addr][k*8+7:k*8];
            wire [7:0] wr_byte;
            assign wr_byte = mosi_data_in[k*8+7:k*8];
            assign data_to_write[k*8+7:k*8] = mosi_data_in_mask[k] ? wr_byte : passthrough_byte;
        end
    endgenerate
    
    // logic of the master interface, currently inactive
    always @(posedge ACLK)
    begin
        mosi_data_out_valid <= 1'b0;
        mosi_req_out <= 1'b0;
        mosi_addr_out <= 0;
        mosi_data_out <= 0;
        mosi_data_out_mask <= 0;
        miso_req_out <= 1'b0;
        miso_addr_out <= 0;
    end
    
    // TODO: USER declare user registers and nets
    // let's implement a floating point summation within address space of this module
    reg [63:0] a;
    reg [63:0] b;
    reg [63:0] c;
    wire [63:0] ab, ab_c;
    wire overflow1, underflow1, out_valid1, overflow2, underflow2, out_valid2;

    // actually write to local memory
    // handle master write
    always @(posedge ACLK)
    begin
        if (mosi_req_in)
            mem[mosi_reg_addr] <= data_to_write;

        // TODO: USER fill master read-only memory segment
        mem[9][2:0] <= {overflow1 || overflow2, underflow1 || underflow2, out_valid1 && out_valid2};
        mem[8] <= ab_c[63:32];
        mem[7] <= ab_c[31:0];
    end

    // TODO: USER instantiate user logic
    fp_multiplier_combinatorial # (.EXPONENT_BITS(11), .MANTISSA_BITS(52)) mult_f64_inst (a, b, ab, overflow1, underflow1, out_valid1);
    fp_adder_combinatorial # (.EXPONENT_BITS(11), .MANTISSA_BITS(52)) add_f64_inst (ab, c, ab_c, overflow2, underflow2, out_valid2);

    always @(posedge ACLK)
        if (mem[0][0])  // LSB in first address indicate task submission
        begin
            a <= {mem[6], mem[5]};
            b <= {mem[4], mem[3]};
            c <= {mem[2], mem[1]};
        end

endmodule
