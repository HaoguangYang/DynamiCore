`timescale 1 ns / 1 ps

module axi4_master_pipelined #
    (
        // Users to add parameters here
        // bits for FIFO counter of input/output data. Allows 2^N - 1 commands in flight
        parameter integer FIFO_DEPTH_BITS = 8,

        // User parameters ends
        // Do not modify the parameters beyond this line

        /*
        // NOTE: not used -- target address comes from input, bust length fixed to 1 for pipelining
        // Base address of targeted slave
        parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
        // Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
        parameter integer C_M_AXI_BURST_LEN	= 16,
        */

        // Thread ID Width
        parameter integer C_M_AXI_ID_WIDTH	= 2,
        // Width of Address Bus
        parameter integer C_M_AXI_ADDR_WIDTH	= 32,
        // Width of Data Bus
        parameter integer C_M_AXI_DATA_WIDTH	= 32,

        // AXI Write worker ID
        parameter [C_M_AXI_ID_WIDTH-1:0] C_M_AXI_ADDR_WRITE_ID = 1'b0,
        // AXI Read worker ID
        parameter [C_M_AXI_ID_WIDTH-1:0] C_M_AXI_ADDR_READ_ID  = 1'b1,

        // NOTE: not used, fixed to 0
        // Width of User Write Address Bus
        parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
        // Width of User Read Address Bus
        parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
        // Width of User Write Data Bus
        parameter integer C_M_AXI_WUSER_WIDTH	= 0,
        // Width of User Read Data Bus
        parameter integer C_M_AXI_RUSER_WIDTH	= 0,
        // Width of User Response Bus
        parameter integer C_M_AXI_BUSER_WIDTH	= 0
    )
    (
        // Users to add ports here
        // Whether input (addrs, reqs, mosi data) is valid.
        // This bit creates a back pressure to flush things down the bus.
        // User need to unset this bit to wait for miso_data_valid, if reading miso_data.
        input wire  mosi_data_valid,
        // Whether to perform master-write (MOSI)
        input wire  mosi_req,
        // Target addr to master-write
        input wire [C_M_AXI_ADDR_WIDTH-1 : 0] mosi_addr,
        // Data to be written to mosi_addr, ignored if not mosi_req
        input wire [C_M_AXI_DATA_WIDTH-1 : 0] mosi_data,
        // Mask applied to MOSI data, aligned in bytes
        input wire [C_M_AXI_DATA_WIDTH/8-1 : 0] mosi_data_mask,
        // whether write queue is empty, the signal is useful when ensuring read-after-write data consistency
        output reg mosi_queue_empty,
        // Whether to perform master-read (MISO)
        input wire miso_req,
        // Target addr to master-read
        input wire [C_M_AXI_ADDR_WIDTH-1 : 0] miso_addr,
        // Whether input is acknoledged and output (miso data) is valid
        output reg miso_data_valid,
        // Data read from miso_addr, not updated if not miso_req
        output reg [C_M_AXI_DATA_WIDTH-1 : 0] miso_data,
        // Whether read queue is empty. The signal is useful when ensuring write-after-read and read-after-read data consistency
        output reg miso_queue_empty,
        // Indicator for upstream core to wait
        output reg stalled,
        // User ports ends
        // Do not modify the ports beyond this line

        /*
        // Initiate AXI transactions
        input wire  INIT_AXI_TXN,
        // Asserts when transaction is complete
        output wire  TXN_DONE,
        */
        // Asserts when ERROR is detected
        output reg  ERROR,

        // Global Clock Signal.
        input wire  M_AXI_ACLK,
        // Global Reset Singal. This Signal is Active Low
        input wire  M_AXI_ARESETN,

        // Master Interface Write Address ID
        output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
        // Master Interface Write Address
        output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        output wire [7 : 0] M_AXI_AWLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        output wire [2 : 0] M_AXI_AWSIZE,
        // Burst type. The burst type and the size information,
        // determine how the address for each transfer within the burst is calculated.
        output wire [1 : 0] M_AXI_AWBURST,
        // Lock type. Provides additional information about the
        // atomic characteristics of the transfer.
        output wire  M_AXI_AWLOCK,
        // Memory type. This signal indicates how transactions
        // are required to progress through a system.
        output wire [3 : 0] M_AXI_AWCACHE,
        // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
        output wire [2 : 0] M_AXI_AWPROT,
        // Quality of Service, QoS identifier sent for each write transaction.
        output wire [3 : 0] M_AXI_AWQOS,
        // Optional User-defined signal in the write address channel.
        output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
        // Write address valid. This signal indicates that
        // the channel is signaling valid write address and control information.
        output wire  M_AXI_AWVALID,
        // Write address ready. This signal indicates that
        // the slave is ready to accept an address and associated control signals
        input wire  M_AXI_AWREADY,

        // Master Interface Write Data.
        output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
        // Write strobes. This signal indicates which byte
        // lanes hold valid data. There is one write strobe
        // bit for each eight bits of the write data bus.
        output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
        // Write last. This signal indicates the last transfer in a write burst.
        output wire  M_AXI_WLAST,
        // Optional User-defined signal in the write data channel.
        output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
        // Write valid. This signal indicates that valid write
        // data and strobes are available
        output wire  M_AXI_WVALID,
        // Write ready. This signal indicates that the slave
        // can accept the write data.
        input wire  M_AXI_WREADY,

        // Master Interface Write Response.
        input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
        // Write response. This signal indicates the status of the write transaction.
        input wire [1 : 0] M_AXI_BRESP,
        // Optional User-defined signal in the write response channel
        input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
        // Write response valid. This signal indicates that the
        // channel is signaling a valid write response.
        input wire  M_AXI_BVALID,
        // Response ready. This signal indicates that the master
        // can accept a write response.
        output wire  M_AXI_BREADY,

        // Master Interface Read Address.
        output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
        // Read address. This signal indicates the initial
        // address of a read burst transaction.
        output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        output wire [7 : 0] M_AXI_ARLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        output wire [2 : 0] M_AXI_ARSIZE,
        // Burst type. The burst type and the size information,
        // determine how the address for each transfer within the burst is calculated.
        output wire [1 : 0] M_AXI_ARBURST,
        // Lock type. Provides additional information about the
        // atomic characteristics of the transfer.
        output wire  M_AXI_ARLOCK,
        // Memory type. This signal indicates how transactions
        // are required to progress through a system.
        output wire [3 : 0] M_AXI_ARCACHE,
        // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
        output wire [2 : 0] M_AXI_ARPROT,
        // Quality of Service, QoS identifier sent for each read transaction
        output wire [3 : 0] M_AXI_ARQOS,
        // Optional User-defined signal in the read address channel.
        output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
        // Write address valid. This signal indicates that
        // the channel is signaling valid read address and control information
        output wire  M_AXI_ARVALID,
        // Read address ready. This signal indicates that
        // the slave is ready to accept an address and associated control signals
        input wire  M_AXI_ARREADY,

        // Read ID tag. This signal is the identification tag
        // for the read data group of signals generated by the slave.
        input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
        // Master Read Data
        input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
        // Read response. This signal indicates the status of the read transfer
        input wire [1 : 0] M_AXI_RRESP,
        // Read last. This signal indicates the last transfer in a read burst
        input wire  M_AXI_RLAST,
        // Optional User-defined signal in the read address channel.
        input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
        // Read valid. This signal indicates that the channel
        // is signaling the required read data.
        input wire  M_AXI_RVALID,
        // Read ready. This signal indicates that the master can
        // accept the read data and response information.
        output wire  M_AXI_RREADY
    );

    // function called clogb2 that returns an integer which has the
    // value of the ceiling of the log base 2.
    function integer clogb2 (input integer bit_depth);
        begin
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    /*
    // C_TRANSACTIONS_NUM is the width of the index counter for
    // number of write or read transaction.
    localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);

    // Burst length for transactions, in C_M_AXI_DATA_WIDTHs.
    // Non-2^n lengths will eventually cause bursts across 4K address boundaries.
    localparam integer C_MASTER_LENGTH	= 12;
    // total number of burst transfers is master length divided by burst length and burst size
    localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
    // Example State machine to initialize counter, initialize write transactions,
    // initialize read transactions and comparison of read data with the
    // written data words.
    parameter [1:0] IDLE = 2'b00, // This state initiates AXI4Lite transaction
              // after the state machine changes state to INIT_WRITE
              // when there is 0 to 1 transition on INIT_AXI_TXN
              INIT_WRITE   = 2'b01, // This state initializes write transaction,
              // once writes are done, the state machine
              // changes state to INIT_READ
              INIT_READ = 2'b10, // This state initializes read transaction
              // once reads are done, the state machine
              // changes state to INIT_COMPARE
              INIT_COMPARE = 2'b11; // This state issues the status of comparison
    // of the written data with the read data

    reg [1:0] mst_exec_state;
    */
    localparam integer C_M_AXI_BURST_LEN = 1;
    localparam integer ADDR_LSB = clogb2((C_M_AXI_DATA_WIDTH/8) - 1);
    localparam axi_wlast = 1;
    localparam axi_bready = 1;
    localparam axi_rready = 1;
    // AXI4LITE signals
    //AXI4 internal temp signals
    reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
    reg  	axi_awvalid;
    reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
    // reg  	axi_wlast;              // NOTE: hard-wired to 1
    reg  	axi_wvalid;
    // reg  	axi_bready;             // NOTE: hard-wired to 1
    reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
    reg  	axi_arvalid;
    // reg  	axi_rready;             // NOTE: hard-wired to 1
    /*
    // NOTE: burst length is hard-wired to 1
    //write beat count in a burst
    reg [C_TRANSACTIONS_NUM : 0] 	write_index;
    //read beat count in a burst
    reg [C_TRANSACTIONS_NUM : 0] 	read_index;
    //size of C_M_AXI_BURST_LEN length burst in bytes
    wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
    //The burst counters are used to track the number of burst transfers of C_M_AXI_BURST_LEN burst length needed to transfer 2^C_MASTER_LENGTH bytes of data.
    reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
    reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
    reg  	start_single_burst_write;
    reg  	start_single_burst_read;
    */
    /*
    reg  	writes_done;
    reg  	reads_done;
    reg  	error_reg;
    reg  	compare_done;
    reg  	read_mismatch;
    reg  	burst_write_active;
    reg  	burst_read_active;
    reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
    //Interface response error flags
    wire  	write_resp_error;
    wire  	read_resp_error;
    wire  	wnext;
    wire  	rnext;
    reg  	init_txn_ff;
    reg  	init_txn_ff2;
    reg  	init_txn_edge;
    wire  	init_txn_pulse;
    */
    reg [C_M_AXI_DATA_WIDTH/8-1 : 0] axi_wstrb;
    reg     mosi_queue_full, mosi_queue_nearfull, miso_queue_full, miso_queue_nearfull, flushing;
    reg [FIFO_DEPTH_BITS-1 : 0] mosi_pending, miso_pending;
    wire    skid_ready, buffered_mosi_valid, buffered_mosi_req, buffered_miso_req;
    reg     m_ready;
    // force address alignment by setting lower data_wisth_size bits to 0
    wire [C_M_AXI_ADDR_WIDTH-ADDR_LSB-1 : 0] buffered_mosi_addr, buffered_miso_addr;
    wire [C_M_AXI_DATA_WIDTH-1 : 0] buffered_mosi_data;
    wire [C_M_AXI_DATA_WIDTH/8-1 : 0] buffered_mosi_data_mask;

    // I/O Connections assignments

    //I/O Connections. Write Address (AW)
    assign M_AXI_AWID	= C_M_AXI_ADDR_WRITE_ID;
    //The AXI address is a concatenation of the target base address + active offset range
    assign M_AXI_AWADDR	= axi_awaddr;
    //Burst LENgth is number of transaction beats, minus 1
    assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
    //Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
    assign M_AXI_AWSIZE	= ADDR_LSB;
    //INCR burst type is usually used, except for keyhole bursts
    assign M_AXI_AWBURST	= 2'b01;
    // Normal signaling
    assign M_AXI_AWLOCK	= 1'b0;
    //Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache.
    //assign M_AXI_AWCACHE	= 4'b0010;
    assign M_AXI_AWCACHE	= 4'b0011;  // NOTE: Normal: no cache, modifiable
    //assign M_AXI_AWPROT	= 3'h0;
    assign M_AXI_AWPROT	= 3'b010;       // NOTE: Unpriviledged, unsecure, data access
    // Lowest quality of service (unused)
    assign M_AXI_AWQOS	= 4'h0;
    assign M_AXI_AWUSER	= 'b1;
    assign M_AXI_AWVALID	= axi_awvalid;
    //Write Data(W)
    assign M_AXI_WDATA	= axi_wdata;
    //All bursts are complete and aligned in this example
    assign M_AXI_WSTRB	= axi_wstrb;    // NOTE: changed from hard-coded {(C_M_AXI_DATA_WIDTH/8){1'b1}};
    assign M_AXI_WLAST	= axi_wlast;
    assign M_AXI_WUSER	= 'b0;
    assign M_AXI_WVALID	= axi_wvalid;
    //Write Response (B)
    assign M_AXI_BREADY	= axi_bready;
    //Read Address (AR)
    assign M_AXI_ARID	= C_M_AXI_ADDR_READ_ID;
    assign M_AXI_ARADDR	= axi_araddr;
    //Burst LENgth is number of transaction beats, minus 1
    assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
    //Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
    assign M_AXI_ARSIZE	= ADDR_LSB;
    //INCR burst type is usually used, except for keyhole bursts
    assign M_AXI_ARBURST	= 2'b01;
    // Normal signaling
    assign M_AXI_ARLOCK	= 1'b0;
    //Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache.
    //assign M_AXI_ARCACHE	= 4'b0010;
    assign M_AXI_ARCACHE	= 4'b0011;  // NOTE: Normal: no cache, modifiable
    //assign M_AXI_ARPROT	= 3'h0;
    assign M_AXI_ARPROT	= 3'b010;       // NOTE: Unpriviledged, unsecure, data access
    // Lowest quality of service (unused)
    assign M_AXI_ARQOS	= 4'h0;
    assign M_AXI_ARUSER	= 'b1;
    assign M_AXI_ARVALID	= axi_arvalid;
    //Read and Read Response (R)
    assign M_AXI_RREADY	= axi_rready;
    //Example design I/O
    //assign TXN_DONE	= compare_done;
    //Burst size in bytes
    //assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
    //assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;


    ////////////////////////////////////////////////////////////////////////
    //
    // Overarching command logic
    // {{{
    ////////////////////////////////////////////////////////////////////////
    //
    //

    /*
    //Generate a pulse to initiate AXI transaction.
    always @(posedge M_AXI_ACLK)
    begin
        // Initiates AXI transaction delay
        if (M_AXI_ARESETN == 0 )
        begin
            init_txn_ff <= 1'b0;
            init_txn_ff2 <= 1'b0;
        end
        else
        begin
            init_txn_ff <= INIT_AXI_TXN;
            init_txn_ff2 <= init_txn_ff;
        end
    end
    */

    initial
        mosi_pending        = 0;
    initial
        mosi_queue_empty    = 1;
    initial
        mosi_queue_full     = 0;
    initial
        mosi_queue_nearfull = 0;
    initial
        miso_pending        = 0;
    initial
        miso_queue_empty    = 1;
    initial
        miso_queue_full     = 0;
    initial
        miso_queue_nearfull = 0;

    wire incoming_reqs_valid;
    assign incoming_reqs_valid = buffered_mosi_valid && m_ready;

    always @(posedge M_AXI_ACLK)
        if (!M_AXI_ARESETN)
        begin   // reset
            mosi_pending <= 0;
            mosi_queue_empty <= 1;
            mosi_queue_full <= 0;
            mosi_queue_nearfull <= 0;
            miso_pending <= 0;
            miso_queue_empty <= 1;
            miso_queue_full <= 0;
            miso_queue_nearfull <= 0;
        end
        else
        begin
            case ({incoming_reqs_valid, mosi_req, M_AXI_BVALID})
                3'b110: begin
                    // input queue is valid and taking in new values. Update pending operations
                    // No new acks. Pending += incoming requests
                    mosi_pending <= mosi_pending + 1;
                    mosi_queue_empty <= 0;
                    mosi_queue_nearfull <= &(mosi_pending[FIFO_DEPTH_BITS-1 : 1]);
                    mosi_queue_full <= mosi_queue_nearfull && mosi_pending[0];
                end
                3'b101,
                3'b011,
                3'b001: begin
                    // no incoming reqs, new acks. Pending -= acks
                    mosi_pending <= mosi_pending - 1;
                    mosi_queue_empty <= (mosi_pending == 1);
                    mosi_queue_nearfull <= mosi_queue_full;
                    mosi_queue_full <= 0;
                end
                default: begin
                    mosi_pending <= mosi_pending;
                    mosi_queue_empty <= mosi_queue_empty;
                    mosi_queue_nearfull <= mosi_queue_nearfull;
                    mosi_queue_full <= mosi_queue_full;
                end
            endcase
            case ({incoming_reqs_valid, miso_req, M_AXI_RVALID})
                3'b110: begin
                    // input queue is valid and taking in new values. Update pending operations
                    // No new acks. Pending += incoming requests
                    miso_pending <= miso_pending + 1;
                    miso_queue_empty <= 0;
                    miso_queue_nearfull <= &(miso_pending[FIFO_DEPTH_BITS-1 : 1]);
                    miso_queue_full <= miso_queue_nearfull && miso_pending[0];
                end
                3'b101,
                3'b011,
                3'b001: begin
                    // no incoming reqs, new acks. Pending -= acks
                    miso_pending <= miso_pending - 1;
                    miso_queue_empty <= (miso_pending == 1);
                    miso_queue_nearfull <= miso_queue_full;
                    miso_queue_full <= 0;
                end
                default: begin
                    miso_pending <= miso_pending;
                    miso_queue_empty <= miso_queue_empty;
                    miso_queue_nearfull <= miso_queue_nearfull;
                    miso_queue_full <= miso_queue_full;
                end
            endcase
        end

    wire empty;
    assign empty = mosi_queue_empty && miso_queue_empty;

    initial
        flushing = 0;
    always @(posedge M_AXI_ACLK)
        if (!M_AXI_ARESETN)         // reset
            flushing <= 0;
        else if ((M_AXI_RVALID && M_AXI_RRESP[1])
                 ||(M_AXI_BVALID && M_AXI_BRESP[1])
                 ||(!mosi_data_valid && !empty))
            flushing <= 1'b1;
        else if (empty)
            flushing <= 1'b0;
    // }}}

    ////////////////////////////////////////////////////////////////////////
    //
    // Input skidbuffer
    // {{{
    ////////////////////////////////////////////////////////////////////////
    //
    //

    skidbuffer #(
                   // {{{
                   .DW(1 + (C_M_AXI_ADDR_WIDTH-ADDR_LSB) + C_M_AXI_DATA_WIDTH +
                       (C_M_AXI_DATA_WIDTH/8) + 1 + (C_M_AXI_ADDR_WIDTH-ADDR_LSB)),
                   .OPT_OUTREG(1'b0)
                   // }}}
               ) skid (
                   // {{{
                   .i_clk(M_AXI_ACLK), .i_reset(!M_AXI_ARESETN),
                   .i_valid(mosi_data_valid), .o_ready(skid_ready),
                   // force target_addr alignment
                   .i_data({ mosi_req,
                             mosi_addr[C_M_AXI_ADDR_WIDTH-1 : ADDR_LSB],
                             mosi_data,
                             mosi_data_mask,
                             miso_req,
                             miso_addr[C_M_AXI_ADDR_WIDTH-1 : ADDR_LSB] }),
                   .o_valid(buffered_mosi_valid), .i_ready(m_ready),
                   .o_data({ buffered_mosi_req,
                             buffered_mosi_addr,
                             buffered_mosi_data,
                             buffered_mosi_data_mask,
                             buffered_miso_req,
                             buffered_miso_addr })
                   // }}}
               );

    always @(*)
        stalled = !skid_ready;

    always @(*)
    begin
        m_ready = 1;

        if (flushing || mosi_queue_nearfull || miso_queue_nearfull)   // || ((buffered_direction != direction)&&(!empty))
            m_ready = 1'b0;
        // wait for bus state to catch up
        if (axi_awvalid && !M_AXI_AWREADY)
            m_ready = 1'b0;
        if (axi_wvalid && !M_AXI_WREADY)
            m_ready = 1'b0;
        if (axi_arvalid && !M_AXI_ARREADY)
            m_ready = 1'b0;
    end
    // }}}

    ////////////////////////////////////////////////////////////////////////
    //
    // AXI Signaling
    // {{{
    ////////////////////////////////////////////////////////////////////////
    //
    //

    //
    // Write transactions
    //

    /*
    //--------------------
    //Write Address Channel
    //--------------------

    // The purpose of the write address channel is to request the address and
    // command information for the entire transaction.  It is a single beat
    // of information.

    // The AXI4 Write address channel in this example will continue to initiate
    // write commands as fast as it is allowed by the slave/interconnect.
    // The address will be incremented on each accepted address transaction,
    // by burst_size_byte to point to the next address.

    always @(posedge M_AXI_ACLK)
    begin

        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 )
        begin
            axi_awvalid <= 1'b0;
        end
        // If previously not valid , start next transaction
        else if (~axi_awvalid && start_single_burst_write)
        begin
            axi_awvalid <= 1'b1;
        end
        // Once asserted, VALIDs cannot be deasserted, so axi_awvalid
        // must wait until transaction is accepted
        else if (M_AXI_AWREADY && axi_awvalid)
        begin
            axi_awvalid <= 1'b0;
        end
        else
            axi_awvalid <= axi_awvalid;
    end


    // Next address after AWREADY indicates previous address acceptance
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)
        begin
            axi_awaddr <= 'b0;
        end
        else if (M_AXI_AWREADY && axi_awvalid)
        begin
            axi_awaddr <= axi_awaddr + burst_size_bytes;
        end
        else
            axi_awaddr <= axi_awaddr;
    end

    //--------------------
    //Write Data Channel
    //--------------------

    //The write data will continually try to push write data across the interface.

    //The amount of data accepted will depend on the AXI slave and the AXI
    //Interconnect settings, such as if there are FIFOs enabled in interconnect.

    //Note that there is no explicit timing relationship to the write address channel.
    //The write channel has its own throttling flag, separate from the AW channel.

    //Synchronization between the channels must be determined by the user.

    //The simpliest but lowest performance would be to only issue one address write
    //and write data burst at a time.

    //In this example they are kept in sync by using the same address increment
    //and burst sizes. Then the AW and W channels have their transactions measured
    //with threshold counters as part of the user logic, to make sure neither
    //channel gets too far ahead of each other.

    //Forward movement occurs when the write channel is valid and ready

    assign wnext = M_AXI_WREADY & axi_wvalid;

    // WVALID logic, similar to the axi_awvalid always block above
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 )
        begin
            axi_wvalid <= 1'b0;
        end
        // If previously not valid, start next transaction
        else if (~axi_wvalid && start_single_burst_write)
        begin
            axi_wvalid <= 1'b1;
        end
        // If WREADY and too many writes, throttle WVALID
        // Once asserted, VALIDs cannot be deasserted, so WVALID
        // must wait until burst is complete with WLAST
        else if (wnext && axi_wlast)
            axi_wvalid <= 1'b0;
        else
            axi_wvalid <= axi_wvalid;
    end


    //WLAST generation on the MSB of a counter underflow
    // WVALID logic, similar to the axi_awvalid always block above
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 )
        begin
            axi_wlast <= 1'b0;
        end
        // axi_wlast is asserted when the write index
        // count reaches the penultimate count to synchronize
        // with the last write data when write_index is b1111
        // else if (&(write_index[C_TRANSACTIONS_NUM-1:1])&& ~write_index[0] && wnext)
        else if (((write_index == C_M_AXI_BURST_LEN-2 && C_M_AXI_BURST_LEN >= 2) && wnext) || (C_M_AXI_BURST_LEN == 1 ))
        begin
            axi_wlast <= 1'b1;
        end
        // Deassrt axi_wlast when the last write data has been
        // accepted by the slave with a valid response
        else if (wnext)
            axi_wlast <= 1'b0;
        else if (axi_wlast && C_M_AXI_BURST_LEN == 1)
            axi_wlast <= 1'b0;
        else
            axi_wlast <= axi_wlast;
    end


    // Burst length counter. Uses extra counter register bit to indicate terminal
    // count to reduce decode logic
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 || start_single_burst_write == 1'b1)
        begin
            write_index <= 0;
        end
        else if (wnext && (write_index != C_M_AXI_BURST_LEN-1))
        begin
            write_index <= write_index + 1;
        end
        else
            write_index <= write_index;
    end
    */

    // awvalid, wvalid
    // {{{
    // Send write transactions
    initial
        axi_awvalid = 0;
    initial
        axi_wvalid = 0;
    always @(posedge M_AXI_ACLK)
        if (!M_AXI_ARESETN)
        begin   // reset
            axi_awvalid <= 0;
            axi_wvalid  <= 0;
        end
        else if (buffered_mosi_valid && buffered_mosi_req && m_ready)
        begin
            axi_awvalid <= 1;
            axi_wvalid  <= 1;
        end
        else
        begin
            if (M_AXI_AWREADY)
                axi_awvalid <= 0;
            if (M_AXI_WREADY)
                axi_wvalid <= 0;
        end
    // }}}

    /*
    // Write Data Generator
    // Data pattern is only a simple incrementing count from 0 for each burst
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)
            axi_wdata <= 'b1;
        //else if (wnext && axi_wlast)
        //  axi_wdata <= 'b0;
        else if (wnext)
            axi_wdata <= axi_wdata + 1;
        else
            axi_wdata <= axi_wdata;
    end
    */

    // wdata
    // {{{
    always @(posedge M_AXI_ACLK)
        if (!axi_wvalid || M_AXI_WREADY)
            axi_wdata <= buffered_mosi_data;
    // }}}

    // wstrb
    // {{{
    always @(posedge M_AXI_ACLK)
        if (!axi_wvalid || M_AXI_WREADY)
            axi_wstrb <= buffered_mosi_data_mask;
    // }}}


    /*
    //----------------------------
    //Write Response (B) Channel
    //----------------------------

    //The write response channel provides feedback that the write has committed
    //to memory. BREADY will occur when all of the data and the write address
    //has arrived and been accepted by the slave.

    //The write issuance (number of outstanding write addresses) is started by
    //the Address Write transfer, and is completed by a BREADY/BRESP.

    //While negating BREADY will eventually throttle the AWREADY signal,
    //it is best not to throttle the whole data channel this way.

    //The BRESP bit [1] is used indicate any errors from the interconnect or
    //slave for the entire write burst. This example will capture the error
    //into the ERROR output.

    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 )
        begin
            axi_bready <= 1'b0;
        end
        // accept/acknowledge bresp with axi_bready by the master
        // when M_AXI_BVALID is asserted by slave
        else if (M_AXI_BVALID && ~axi_bready)
        begin
            axi_bready <= 1'b1;
        end
        // deassert after one clock cycle
        else if (axi_bready)
        begin
            axi_bready <= 1'b0;
        end
        // retain the previous value
        else
            axi_bready <= axi_bready;
    end

    //Flag any write response errors
    assign write_resp_error = axi_bready & M_AXI_BVALID & M_AXI_BRESP[1];
    */

    /*
    //----------------------------
    //Read Address Channel
    //----------------------------

    //The Read Address Channel (AW) provides a similar function to the
    //Write Address channel- to provide the tranfer qualifiers for the burst.

    //In this example, the read address increments in the same
    //manner as the write address channel.

    always @(posedge M_AXI_ACLK)
    begin

        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 )
        begin
            axi_arvalid <= 1'b0;
        end
        // If previously not valid , start next transaction
        else if (~axi_arvalid && start_single_burst_read)
        begin
            axi_arvalid <= 1'b1;
        end
        else if (M_AXI_ARREADY && axi_arvalid)
        begin
            axi_arvalid <= 1'b0;
        end
        else
            axi_arvalid <= axi_arvalid;
    end


    // Next address after ARREADY indicates previous address acceptance
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)
        begin
            axi_araddr <= 'b0;
        end
        else if (M_AXI_ARREADY && axi_arvalid)
        begin
            axi_araddr <= axi_araddr + burst_size_bytes;
        end
        else
            axi_araddr <= axi_araddr;
    end
    */

    //
    // Read transactions
    //

    // arvalid
    // {{{
    initial
        axi_arvalid = 0;
    always @(posedge M_AXI_ACLK)
        if (!M_AXI_ARESETN)             // reset
            axi_arvalid <= 0;
        else if (buffered_mosi_valid && buffered_miso_req && m_ready)
            axi_arvalid <= 1;
        else if (axi_rready)
        begin
            axi_arvalid <= 0;
        end
    // }}}

    // awaddr, araddr
    // {{{
    always @(posedge M_AXI_ACLK)
        if (!axi_awvalid || M_AXI_AWREADY)
        begin
            // force address alignment
            axi_awaddr <= { buffered_mosi_addr, {(ADDR_LSB){1'b0}} };
        end

    always @(posedge M_AXI_ACLK)
        if (!axi_arvalid || M_AXI_ARREADY)
        begin
            // force address alignment
            axi_araddr <= { buffered_miso_addr, {(ADDR_LSB){1'b0}} };
        end
    // }}}

    /*
    //--------------------------------
    //Read Data (and Response) Channel
    //--------------------------------

    // Forward movement occurs when the channel is valid and ready
    assign rnext = M_AXI_RVALID && axi_rready;


    // Burst length counter. Uses extra counter register bit to indicate
    // terminal count to reduce decode logic
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 || start_single_burst_read)
        begin
            read_index <= 0;
        end
        else if (rnext && (read_index != C_M_AXI_BURST_LEN-1))
        begin
            read_index <= read_index + 1;
        end
        else
            read_index <= read_index;
    end


    // The Read Data channel returns the results of the read request
    // In this example the data checker is always able to accept
    // more data, so no need to throttle the RREADY signal
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 )
        begin
            axi_rready <= 1'b0;
        end
        // accept/acknowledge rdata/rresp with axi_rready by the master
        // when M_AXI_RVALID is asserted by slave
        else if (M_AXI_RVALID)
        begin
            if (M_AXI_RLAST && axi_rready)
            begin
                axi_rready <= 1'b0;
            end
            else
            begin
                axi_rready <= 1'b1;
            end
        end
        // retain the previous value
    end

    //Check received read data against data generator
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)
        begin
            read_mismatch <= 1'b0;
        end
        //Only check data when RVALID is active
        else if (rnext && (M_AXI_RDATA != expected_rdata))
        begin
            read_mismatch <= 1'b1;
        end
        else
            read_mismatch <= 1'b0;
    end

    //Flag any read response errors
    assign read_resp_error = axi_rready & M_AXI_RVALID & M_AXI_RRESP[1];
    */

    // rdata, and returned o_wb_data, o_wb_ack, o_wb_err
    // {{{
    always @(*)
        miso_data = M_AXI_RDATA;

    always @(*)
        miso_data_valid = !flushing&&(M_AXI_RVALID && !M_AXI_RRESP[1]);

    always @(*)
        ERROR = !flushing&&((M_AXI_RVALID && M_AXI_RRESP[1])
                            ||(M_AXI_BVALID && M_AXI_BRESP[1]));
    // }}}

    /*
    //----------------------------------------
    //Example design read check data generator
    //-----------------------------------------

    //Generate expected read data to check against actual read data

    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)// || M_AXI_RLAST)
            expected_rdata <= 'b1;
        else if (M_AXI_RVALID && axi_rready)
            expected_rdata <= expected_rdata + 1;
        else
            expected_rdata <= expected_rdata;
    end


    //----------------------------------
    //Example design error register
    //----------------------------------

    //Register and hold any data mismatches, or read/write interface errors

    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)
        begin
            error_reg <= 1'b0;
        end
        else if (read_mismatch || write_resp_error || read_resp_error)
        begin
            error_reg <= 1'b1;
        end
        else
            error_reg <= error_reg;
    end


    //--------------------------------
    //Example design throttling
    //--------------------------------

    // For maximum port throughput, this user example code will try to allow
    // each channel to run as independently and as quickly as possible.

    // However, there are times when the flow of data needs to be throtted by
    // the user application. This example application requires that data is
    // not read before it is written and that the write channels do not
    // advance beyond an arbitrary threshold (say to prevent an
    // overrun of the current read address by the write address).

    // From AXI4 Specification, 13.13.1: "If a master requires ordering between
    // read and write transactions, it must ensure that a response is received
    // for the previous transaction before issuing the next transaction."

    // This example accomplishes this user application throttling through:
    // -Reads wait for writes to fully complete
    // -Address writes wait when not read + issued transaction counts pass
    // a parameterized threshold
    // -Writes wait when a not read + active data burst count pass
    // a parameterized threshold

    // write_burst_counter counter keeps track with the number of burst transaction initiated
    // against the number of burst transactions the master needs to initiate
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 )
        begin
            write_burst_counter <= 'b0;
        end
        else if (M_AXI_AWREADY && axi_awvalid)
        begin
            if (write_burst_counter[C_NO_BURSTS_REQ] == 1'b0)
            begin
                write_burst_counter <= write_burst_counter + 1'b1;
                //write_burst_counter[C_NO_BURSTS_REQ] <= 1'b1;
            end
        end
        else
            write_burst_counter <= write_burst_counter;
    end

    // read_burst_counter counter keeps track with the number of burst transaction initiated
    // against the number of burst transactions the master needs to initiate
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)
        begin
            read_burst_counter <= 'b0;
        end
        else if (M_AXI_ARREADY && axi_arvalid)
        begin
            if (read_burst_counter[C_NO_BURSTS_REQ] == 1'b0)
            begin
                read_burst_counter <= read_burst_counter + 1'b1;
                //read_burst_counter[C_NO_BURSTS_REQ] <= 1'b1;
            end
        end
        else
            read_burst_counter <= read_burst_counter;
    end


    //implement master command interface state machine

    always @ ( posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 1'b0 )
        begin
            // reset condition
            // All the signals are assigned default values under reset condition
            mst_exec_state      <= IDLE;
            start_single_burst_write <= 1'b0;
            start_single_burst_read  <= 1'b0;
            compare_done      <= 1'b0;
            ERROR <= 1'b0;
        end
        else
        begin

            // state transition
            case (mst_exec_state)

                IDLE:
                    // This state is responsible to wait for user defined C_M_START_COUNT
                    // number of clock cycles.
                    if ( init_txn_pulse == 1'b1)
                    begin
                        mst_exec_state  <= INIT_WRITE;
                        ERROR <= 1'b0;
                        compare_done <= 1'b0;
                    end
                    else
                    begin
                        mst_exec_state  <= IDLE;
                    end

                INIT_WRITE:
                    // This state is responsible to issue start_single_write pulse to
                    // initiate a write transaction. Write transactions will be
                    // issued until burst_write_active signal is asserted.
                    // write controller
                    if (writes_done)
                    begin
                        mst_exec_state <= INIT_READ;//
                    end
                    else
                    begin
                        mst_exec_state  <= INIT_WRITE;

                        if (~axi_awvalid && ~start_single_burst_write && ~burst_write_active)
                        begin
                            start_single_burst_write <= 1'b1;
                        end
                        else
                        begin
                            start_single_burst_write <= 1'b0; //Negate to generate a pulse
                        end
                    end

                INIT_READ:
                    // This state is responsible to issue start_single_read pulse to
                    // initiate a read transaction. Read transactions will be
                    // issued until burst_read_active signal is asserted.
                    // read controller
                    if (reads_done)
                    begin
                        mst_exec_state <= INIT_COMPARE;
                    end
                    else
                    begin
                        mst_exec_state  <= INIT_READ;

                        if (~axi_arvalid && ~burst_read_active && ~start_single_burst_read)
                        begin
                            start_single_burst_read <= 1'b1;
                        end
                        else
                        begin
                            start_single_burst_read <= 1'b0; //Negate to generate a pulse
                        end
                    end

                INIT_COMPARE:
                    // This state is responsible to issue the state of comparison
                    // of written data with the read data. If no error flags are set,
                    // compare_done signal will be asseted to indicate success.
                    //if (~error_reg)
                begin
                    ERROR <= error_reg;
                    mst_exec_state <= IDLE;
                    compare_done <= 1'b1;
                end
                default :
                begin
                    mst_exec_state  <= IDLE;
                end
            endcase
        end
    end //MASTER_EXECUTION_PROC


    // burst_write_active signal is asserted when there is a burst write transaction
    // is initiated by the assertion of start_single_burst_write. burst_write_active
    // signal remains asserted until the burst write is accepted by the slave
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)
            burst_write_active <= 1'b0;

        //The burst_write_active is asserted when a write burst transaction is initiated
        else if (start_single_burst_write)
            burst_write_active <= 1'b1;
        else if (M_AXI_BVALID && axi_bready)
            burst_write_active <= 0;
    end

    // Check for last write completion.

    // This logic is to qualify the last write count with the final write
    // response. This demonstrates how to confirm that a write has been
    // committed.

    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)
            writes_done <= 1'b0;

        //The writes_done should be associated with a bready response
        //else if (M_AXI_BVALID && axi_bready && (write_burst_counter == {(C_NO_BURSTS_REQ-1){1}}) && axi_wlast)
        else if (M_AXI_BVALID && (write_burst_counter[C_NO_BURSTS_REQ]) && axi_bready)
            writes_done <= 1'b1;
        else
            writes_done <= writes_done;
    end

    // burst_read_active signal is asserted when there is a burst write transaction
    // is initiated by the assertion of start_single_burst_write. start_single_burst_read
    // signal remains asserted until the burst read is accepted by the master
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)
            burst_read_active <= 1'b0;

        //The burst_write_active is asserted when a write burst transaction is initiated
        else if (start_single_burst_read)
            burst_read_active <= 1'b1;
        else if (M_AXI_RVALID && axi_rready && M_AXI_RLAST)
            burst_read_active <= 0;
    end


    // Check for last read completion.

    // This logic is to qualify the last read count with the final read
    // response. This demonstrates how to confirm that a read has been
    // committed.

    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1)
            reads_done <= 1'b0;

        //The reads_done should be associated with a rready response
        //else if (M_AXI_BVALID && axi_bready && (write_burst_counter == {(C_NO_BURSTS_REQ-1){1}}) && axi_wlast)
        else if (M_AXI_RVALID && axi_rready && (read_index == C_M_AXI_BURST_LEN-1) && (read_burst_counter[C_NO_BURSTS_REQ]))
            reads_done <= 1'b1;
        else
            reads_done <= reads_done;
    end
    */

    // Add user logic here

    // User logic ends

endmodule
