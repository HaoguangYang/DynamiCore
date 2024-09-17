`timescale 1 ns / 1 ps

module axi4_slave_pipelined #
    (
        // Users to add parameters here

        // User parameters ends
        // Do not modify the parameters beyond this line

        // Width of ID for for write address, write data, read address and read data
        parameter integer C_S_AXI_ID_WIDTH = 1,
        // Width of S_AXI data bus
        parameter integer C_S_AXI_DATA_WIDTH = 32,
        // Width of S_AXI address bus
        parameter integer C_S_AXI_ADDR_WIDTH = 6,

        // Width of optional user defined signal in write address channel
        parameter integer C_S_AXI_AWUSER_WIDTH = 0,
        // Width of optional user defined signal in read address channel
        parameter integer C_S_AXI_ARUSER_WIDTH = 0,
        // Width of optional user defined signal in write data channel
        parameter integer C_S_AXI_WUSER_WIDTH = 0,
        // Width of optional user defined signal in read data channel
        parameter integer C_S_AXI_RUSER_WIDTH = 0,
        // Width of optional user defined signal in write response channel
        parameter integer C_S_AXI_BUSER_WIDTH = 0,

        // optimization checkboxes
        parameter [0:0] OPT_LOCK     = 1'b0,
        parameter [0:0] OPT_LOCKID   = 1'b1,
        parameter [0:0] OPT_LOWPOWER = 1'b0
    )
    (
        // Users to add ports here

        // A very basic protocol-independent peripheral interface
        // 1. A value will be written any time mosi_req is true
        // 2. A value will be read any time miso_req is true
        // 3. Such a slave might just as easily be written as:
        //
        // always @(posedge S_AXI_ACLK)
        // if (mosi_req)
        // begin
        //     for(k=0; k<C_S_AXI_DATA_WIDTH/8; k=k+1)
        //     begin
        //     if (mosi_data_mask[k])
        //         mem[mosi_addr[C_S_AXI_ADDR_WIDTH-1 : ADDR_LSB]][k*8+:8] <= mosi_data[k*8+:8];
        //     end
        // end
        //
        // always @(posedge S_AXI_ACLK)
        // if (miso_req)
        //      miso_data <= mem[miso_addr[C_S_AXI_ADDR_WIDTH-1 : ADDR_LSB]];
        // end
        //
        // 4. The rule on the input is that miso_data must be registered,
        //    and that it must only change if miso_req is true.  Violating
        //    this rule will cause this core to violate the AXI
        //    protocol standard, as this value is not registered within
        //    this core

        // Master Out Slave In (Write) ports
        // write enabled
        output reg mosi_req,
        // Target address to write
        output reg [C_S_AXI_ADDR_WIDTH-1 : 0] mosi_addr,
        // Data to write
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] mosi_data,
        // Mask applied to MOSI data, aligned in bytes
        output reg [C_S_AXI_DATA_WIDTH/8-1 : 0] mosi_data_mask,
        // Master In Slave Out (Read) ports
        output reg miso_req,
        // Target address to read
        output reg [C_S_AXI_ADDR_WIDTH-1 : 0] miso_addr,
        // Data to be sent out by this slave. Ignored in master-write direction
        input wire [C_S_AXI_DATA_WIDTH-1 : 0] miso_data,
        // User ports ends
        // Do not modify the ports beyond this line

        // Global Clock Signal
        input wire  S_AXI_ACLK,
        // Global Reset Signal. This Signal is Active LOW
        input wire  S_AXI_ARESETN,
        // Write Address ID
        input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_AWID,
        // Write address
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        input wire [7 : 0] S_AXI_AWLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        input wire [2 : 0] S_AXI_AWSIZE,
        // Burst type. The burst type and the size information,
        // determine how the address for each transfer within the burst is calculated.
        input wire [1 : 0] S_AXI_AWBURST,
        // Lock type. Provides additional information about the
        // atomic characteristics of the transfer.
        input wire  S_AXI_AWLOCK,
        // Memory type. This signal indicates how transactions
        // are required to progress through a system.
        // NOTE: not used for now
        input wire [3 : 0] S_AXI_AWCACHE,
        // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
        // NOTE: not used for now
        input wire [2 : 0] S_AXI_AWPROT,
        // Quality of Service, QoS identifier sent for each
        // write transaction.
        // NOTE: not used for now
        input wire [3 : 0] S_AXI_AWQOS,
        // Region identifier. Permits a single physical interface
        // on a slave to be used for multiple logical interfaces.
        // NOTE: not used for now
        input wire [3 : 0] S_AXI_AWREGION,
        // Optional User-defined signal in the write address channel.
        input wire [C_S_AXI_AWUSER_WIDTH-1 : 0] S_AXI_AWUSER,
        // Write address valid. This signal indicates that
        // the channel is signaling valid write address and
        // control information.
        input wire  S_AXI_AWVALID,
        // Write address ready. This signal indicates that
        // the slave is ready to accept an address and associated
        // control signals.
        output wire  S_AXI_AWREADY,

        // Write Data
        input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
        // Write strobes. This signal indicates which byte
        // lanes hold valid data. There is one write strobe
        // bit for each eight bits of the write data bus.
        input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
        // Write last. This signal indicates the last transfer
        // in a write burst.
        input wire  S_AXI_WLAST,
        // Optional User-defined signal in the write data channel.
        input wire [C_S_AXI_WUSER_WIDTH-1 : 0] S_AXI_WUSER,
        // Write valid. This signal indicates that valid write
        // data and strobes are available.
        input wire  S_AXI_WVALID,
        // Write ready. This signal indicates that the slave
        // can accept the write data.
        output wire  S_AXI_WREADY,

        // Response ID tag. This signal is the ID tag of the
        // write response.
        output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_BID,
        // Write response. This signal indicates the status
        // of the write transaction.
        output wire [1 : 0] S_AXI_BRESP,
        // Optional User-defined signal in the write response channel.
        output wire [C_S_AXI_BUSER_WIDTH-1 : 0] S_AXI_BUSER,
        // Write response valid. This signal indicates that the
        // channel is signaling a valid write response.
        output wire  S_AXI_BVALID,
        // Response ready. This signal indicates that the master
        // can accept a write response.
        input wire  S_AXI_BREADY,

        // Read address ID. This signal is the identification
        // tag for the read address group of signals.
        input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_ARID,
        // Read address. This signal indicates the initial
        // address of a read burst transaction.
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        input wire [7 : 0] S_AXI_ARLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        input wire [2 : 0] S_AXI_ARSIZE,
        // Burst type. The burst type and the size information,
        // determine how the address for each transfer within the burst is calculated.
        input wire [1 : 0] S_AXI_ARBURST,
        // Lock type. Provides additional information about the
        // atomic characteristics of the transfer.
        input wire  S_AXI_ARLOCK,
        // Memory type. This signal indicates how transactions
        // are required to progress through a system.
        // NOTE: not used for now
        input wire [3 : 0] S_AXI_ARCACHE,
        // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
        // NOTE: not used for now
        input wire [2 : 0] S_AXI_ARPROT,
        // Quality of Service, QoS identifier sent for each
        // read transaction.
        // NOTE: not used for now
        input wire [3 : 0] S_AXI_ARQOS,
        // Region identifier. Permits a single physical interface
        // on a slave to be used for multiple logical interfaces.
        // NOTE: not used for now
        input wire [3 : 0] S_AXI_ARREGION,
        // Optional User-defined signal in the read address channel.
        input wire [C_S_AXI_ARUSER_WIDTH-1 : 0] S_AXI_ARUSER,
        // Write address valid. This signal indicates that
        // the channel is signaling valid read address and
        // control information.
        input wire  S_AXI_ARVALID,

        // Read address ready. This signal indicates that
        // the slave is ready to accept an address and associated
        // control signals.
        output wire  S_AXI_ARREADY,
        // Read ID tag. This signal is the identification tag
        // for the read data group of signals generated by the slave.
        output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_RID,
        // Read Data
        output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
        // Read response. This signal indicates the status of
        // the read transfer.
        output wire [1 : 0] S_AXI_RRESP,
        // Read last. This signal indicates the last transfer
        // in a read burst.
        output wire  S_AXI_RLAST,
        // Optional User-defined signal in the read address channel.
        output wire [C_S_AXI_RUSER_WIDTH-1 : 0] S_AXI_RUSER,
        // Read valid. This signal indicates that the channel
        // is signaling the required read data.
        output wire  S_AXI_RVALID,
        // Read ready. This signal indicates that the master can
        // accept the read data and response information.
        input wire  S_AXI_RREADY
    );

    // function called clogb2 that returns an integer which has the
    // value of the ceiling of the log base 2.
    function integer clogb2 (input integer bit_depth);
        begin
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    // AXI4FULL signals
    reg   axi_awready;
    reg   axi_wready;
    reg   axi_bvalid;
    reg   axi_arready;

    reg [C_S_AXI_BUSER_WIDTH-1 : 0]  axi_buser;
    reg [C_S_AXI_RUSER_WIDTH-1 : 0]  axi_ruser;

    /*
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_awaddr;
    reg [1 : 0]  axi_bresp;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_araddr;
    reg [C_S_AXI_DATA_WIDTH-1 : 0]  axmiso_data;
    reg [1 : 0]  axi_rresp;
    reg   axi_rlast;
    reg   axi_rvalid;
    // aw_wrap_en determines wrap boundary and enables wrapping
    wire aw_wrap_en;
    // ar_wrap_en determines wrap boundary and enables wrapping
    wire ar_wrap_en;
    // aw_wrap_size is the size of the write transfer, the
    // write address wraps to a lower address if upper address
    // limit is reached
    wire [31:0]  aw_wrap_size ;
    // ar_wrap_size is the size of the read transfer, the
    // read address wraps to a lower address if upper address
    // limit is reached
    wire [31:0]  ar_wrap_size ;
    // The axi_awv_awr_flag flag marks the presence of write address valid
    reg axi_awv_awr_flag;
    //The axi_arv_arr_flag flag marks the presence of read address valid
    reg axi_arv_arr_flag;
    // The axi_awlen_cntr internal write address counter to keep track of beats in a burst transaction
    reg [7:0] axi_awlen_cntr;
    //The axi_arlen_cntr internal read address counter to keep track of beats in a burst transaction
    reg [7:0] axi_arlen_cntr;
    reg [1:0] axi_arburst;
    reg [1:0] axi_awburst;
    reg [7:0] axi_arlen;
    reg [7:0] axi_awlen;
    //local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
    //ADDR_LSB is used for addressing 32/64 bit registers/memories
    //ADDR_LSB = 2 for 32 bits (n downto 2)
    //ADDR_LSB = 3 for 42 bits (n downto 3)

    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32)+ 1;
    localparam integer OPT_MEM_ADDR_BITS = 3;
    localparam integer USER_NUM_MEM = 1;
    */

    localparam axi_rresp1 = 0;
    localparam integer ADDR_LSB = clogb2((C_S_AXI_DATA_WIDTH/8) - 1);

    /*
    //----------------------------------------------
    //-- Signals for user logic memory space example
    //------------------------------------------------
    wire [OPT_MEM_ADDR_BITS:0] mem_address;
    wire [USER_NUM_MEM-1:0] mem_select;
    reg [C_S_AXI_DATA_WIDTH-1:0] mem_data_out[0 : USER_NUM_MEM-1];

    genvar i;
    genvar j;
    genvar mem_byte_index;

    // I/O Connections assignments

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY = axi_wready;
    assign S_AXI_BRESP = axi_bresp;
    assign S_AXI_BVALID = axi_bvalid;
    assign S_AXI_RDATA = axmiso_data;
    assign S_AXI_RLAST = axi_rlast;
    assign S_AXI_RVALID = axi_rvalid;
    assign S_AXI_BID = S_AXI_AWID;
    assign S_AXI_RID = S_AXI_ARID;
    assign  aw_wrap_size = (C_S_AXI_DATA_WIDTH/8 * (axi_awlen));
    assign  ar_wrap_size = (C_S_AXI_DATA_WIDTH/8 * (axi_arlen));
    assign  aw_wrap_en = ((axi_awaddr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;
    assign  ar_wrap_en = ((axi_araddr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;
    */

    assign S_AXI_BUSER = axi_buser;
    assign S_AXI_RUSER = axi_ruser;
    assign S_AXI_RRESP[1]   = axi_rresp1;
    assign S_AXI_ARREADY    = axi_arready;


    ////////////////////////////////////////////////////////////////////////
    //
    // Write processing
    // {{{
    ////////////////////////////////////////////////////////////////////////
    //
    //

    // m_awready
    // {{{
    reg m_awready;
    always @(*)
    begin
        m_awready = axi_awready;
        if (S_AXI_WVALID && S_AXI_WREADY && S_AXI_WLAST
                && (!S_AXI_BVALID || S_AXI_BREADY))
            m_awready = 1;
    end
    // }}}

    // AW Skid buffer
    // {{{
    wire m_awvalid, m_awlock;
    wire [C_S_AXI_ADDR_WIDTH-1:0] m_awaddr;
    wire [1:0]  m_awburst;
    wire [2:0]  m_awsize;
    wire [7:0]  m_awlen;
    wire [C_S_AXI_ID_WIDTH-1:0] m_awid;
    localparam integer AWBUF_DW = C_S_AXI_ID_WIDTH + C_S_AXI_ADDR_WIDTH + 2 + 3 + 1 + 8;
    skidbuffer #(
                   // {{{
                   .DW(AWBUF_DW),
                   .OPT_LOWPOWER(OPT_LOWPOWER),
                   .OPT_OUTREG(1'b0)
                   // }}}
               ) awbuf(
                   // {{{
                   .i_clk(S_AXI_ACLK), .i_reset(!S_AXI_ARESETN),
                   .i_valid(S_AXI_AWVALID), .o_ready(S_AXI_AWREADY),
                   .i_data({ S_AXI_AWID, S_AXI_AWBURST, S_AXI_AWSIZE,
                             S_AXI_AWLOCK, S_AXI_AWLEN, S_AXI_AWADDR }),
                   .o_valid(m_awvalid), .i_ready(m_awready),
                   .o_data({ m_awid, m_awburst, m_awsize,
                             m_awlock, m_awlen, m_awaddr })
                   // }}}
               );
    // }}}

    //
    // Write return path
    // {{{
    // r_bvalid
    // {{{
    reg r_bvalid;
    initial
        r_bvalid = 0;
    always @(posedge S_AXI_ACLK)
        if (!S_AXI_ARESETN)
            r_bvalid <= 1'b0;
        else if (S_AXI_WVALID && S_AXI_WREADY && S_AXI_WLAST
                 &&(S_AXI_BVALID && !S_AXI_BREADY))
            r_bvalid <= 1'b1;
        else if (S_AXI_BREADY)
            r_bvalid <= 1'b0;
    // }}}

    // r_bid, axi_bid
    // {{{
    // Double buffer the write response channel only
    reg [C_S_AXI_ID_WIDTH-1 : 0] r_bid;
    initial
        r_bid = 0;
    reg [C_S_AXI_ID_WIDTH-1 : 0] axi_bid;
    initial
        axi_bid = 0;
    always @(posedge S_AXI_ACLK)
    begin
        if (m_awready && (!OPT_LOWPOWER || m_awvalid))
            r_bid    <= m_awid;

        if (!S_AXI_BVALID || S_AXI_BREADY)
            axi_bid <= r_bid;

        if (OPT_LOWPOWER && !S_AXI_ARESETN)
        begin
            r_bid <= 0;
            axi_bid <= 0;
        end
    end
    // }}}

    // axi_bvalid
    // {{{
    initial
        axi_bvalid = 0;
    always @(posedge S_AXI_ACLK)
        if (!S_AXI_ARESETN)
            axi_bvalid <= 0;
        else if (S_AXI_WVALID && S_AXI_WREADY && S_AXI_WLAST)
            axi_bvalid <= 1;
        else if (S_AXI_BREADY)
            axi_bvalid <= r_bvalid;
    // }}}

    /*
       // Implement axi_awready generation

       // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
       // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
       // de-asserted when reset is low.

       always @( posedge S_AXI_ACLK )
       begin
           if ( S_AXI_ARESETN == 1'b0 )
           begin
               axi_awready <= 1'b0;
               axi_awv_awr_flag <= 1'b0;
           end
           else
           begin
               if (~axi_awready && S_AXI_AWVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag)
               begin
                   // slave is ready to accept an address and
                   // associated control signals
                   axi_awready <= 1'b1;
                   axi_awv_awr_flag  <= 1'b1;
                   // used for generation of bresp() and bvalid
               end
               else if (S_AXI_WLAST && axi_wready)
                   // preparing to accept next address after current write burst tx completion
               begin
                   axi_awv_awr_flag  <= 1'b0;
               end
               else
               begin
                   axi_awready <= 1'b0;
               end
           end
       end

       // Implement axi_wready generation

       // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
       // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is
       // de-asserted when reset is low.

       always @( posedge S_AXI_ACLK )
       begin
           if ( S_AXI_ARESETN == 1'b0 )
           begin
               axi_wready <= 1'b0;
           end
           else
           begin
               if ( ~axi_wready && S_AXI_WVALID && axi_awv_awr_flag)
               begin
                   // slave can accept the write data
                   axi_wready <= 1'b1;
               end
               //else if (~axi_awv_awr_flag)
               else if (S_AXI_WLAST && axi_wready)
               begin
                   axi_wready <= 1'b0;
               end
           end
       end
    */

    // axi_awready, axi_wready
    // {{{
    initial
        axi_awready = 1;
    initial
        axi_wready  = 0;
    always @(posedge S_AXI_ACLK)
        if (!S_AXI_ARESETN)
        begin
            axi_awready  <= 1;
            axi_wready   <= 0;
        end
        else if (m_awvalid && m_awready)
        begin
            axi_awready <= 0;
            axi_wready  <= 1;
        end
        else if (S_AXI_WVALID && S_AXI_WREADY)
        begin
            axi_awready <= (S_AXI_WLAST)&&(!S_AXI_BVALID || S_AXI_BREADY);
            axi_wready  <= (!S_AXI_WLAST);
        end
        else if (!axi_awready)
        begin
            if (S_AXI_WREADY)
                axi_awready <= 1'b0;
            else if (r_bvalid && !S_AXI_BREADY)
                axi_awready <= 1'b0;
            else
                axi_awready <= 1'b1;
        end
    // }}}

    // Exclusive write calculation
    // {{{
    // Exclusive address register checking
    reg exclusive_write, block_write;
    wire write_lock_valid;
    always @(posedge S_AXI_ACLK)
        if (!S_AXI_ARESETN || !OPT_LOCK)
        begin
            exclusive_write <= 0;
            block_write <= 0;
        end
        else if (m_awvalid && m_awready)
        begin
            exclusive_write <= 1'b0;
            block_write     <= 1'b0;
            if (write_lock_valid)
                exclusive_write <= 1'b1;
            else if (m_awlock)
                block_write <= 1'b1;
        end
        else if (m_awready)
        begin
            exclusive_write <= 1'b0;
            block_write     <= 1'b0;
        end

    reg axi_exclusive_write;
    always @(posedge S_AXI_ACLK)
        if (!S_AXI_ARESETN || !OPT_LOCK)
            axi_exclusive_write <= 0;
        else if (!S_AXI_BVALID || S_AXI_BREADY)
        begin
            axi_exclusive_write <= exclusive_write;
            if (OPT_LOWPOWER && (!S_AXI_WVALID || !S_AXI_WREADY || !S_AXI_WLAST)
                    && !r_bvalid)
                axi_exclusive_write <= 0;
        end
    // }}}

    /*
       // Implement axi_awaddr latching

       // This process is used to latch the address when both
       // S_AXI_AWVALID and S_AXI_WVALID are valid.

       always @( posedge S_AXI_ACLK )
       begin
           if ( S_AXI_ARESETN == 1'b0 )
           begin
               axi_awaddr <= 0;
               axi_awlen_cntr <= 0;
               axi_awburst <= 0;
               axi_awlen <= 0;
           end
           else
           begin
               if (~axi_awready && S_AXI_AWVALID && ~axi_awv_awr_flag)
               begin
                   // address latching
                   axi_awaddr <= S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH - 1:0];
                   axi_awburst <= S_AXI_AWBURST;
                   axi_awlen <= S_AXI_AWLEN;
                   // start address of transfer
                   axi_awlen_cntr <= 0;
               end
               else if((axi_awlen_cntr <= axi_awlen) && axi_wready && S_AXI_WVALID)
               begin

                   axi_awlen_cntr <= axi_awlen_cntr + 1;

                   case (axi_awburst)
                       2'b00: // fixed burst
                           // The write address for all the beats in the transaction are fixed
                       begin
                           axi_awaddr <= axi_awaddr;
                           //for awsize = 4 bytes (010)
                       end
                       2'b01: //incremental burst
                           // The write address for all the beats in the transaction are increments by awsize
                       begin
                           axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                           //awaddr aligned to 4 byte boundary
                           axi_awaddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};
                           //for awsize = 4 bytes (010)
                       end
                       2'b10: //Wrapping burst
                           // The write address wraps when the address reaches wrap boundary
                           if (aw_wrap_en)
                           begin
                               axi_awaddr <= (axi_awaddr - aw_wrap_size);
                           end
                           else
                           begin
                               axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                               axi_awaddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};
                           end
                       default: //reserved (incremental burst for example)
                       begin
                           axi_awaddr <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                           //for awsize = 4 bytes (010)
                       end
                   endcase
               end
           end
       end
    */

    // Next write address calculation
    // {{{
    reg [C_S_AXI_ADDR_WIDTH-1:0]  waddr;
    // Vivado will warn about wlen only using 4-bits.  This is
    // to be expected, since the axi_addr module only needs to use
    // the bottom four bits of wlen to determine address increments
    reg [7:0]      wlen;
    // Vivado will also warn about the top bit of wsize being unused.
    // This is also to be expected for a DATA_WIDTH of 32-bits.
    reg [2:0]      wsize;
    reg [1:0]      wburst;
    wire [C_S_AXI_ADDR_WIDTH-1:0]  next_wr_addr;

    always @(posedge S_AXI_ACLK)
        if (m_awready)
        begin
            waddr    <= m_awaddr;
            wburst   <= m_awburst;
            wsize    <= m_awsize;
            wlen     <= m_awlen;
        end
        else if (S_AXI_WVALID)
            waddr <= next_wr_addr;

    axi_addr #(
                 // {{{
                 .AW(C_S_AXI_ADDR_WIDTH), .DW(C_S_AXI_DATA_WIDTH)
                 // }}}
             ) get_next_wr_addr(
                 // {{{
                 waddr, wsize, wburst, wlen,
                 next_wr_addr
                 // }}}
             );
    // }}}

    /*
       // Implement write response logic generation

       // The write response and response valid signals are asserted by the slave
       // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.
       // This marks the acceptance of address and indicates the status of
       // write transaction.

       always @( posedge S_AXI_ACLK )
       begin
           if ( S_AXI_ARESETN == 1'b0 )
           begin
               axi_bvalid <= 0;
               axi_bresp <= 2'b0;
               axi_buser <= 0;
           end
           else
           begin
               if (axi_awv_awr_flag && axi_wready && S_AXI_WVALID && ~axi_bvalid && S_AXI_WLAST )
               begin
                   axi_bvalid <= 1'b1;
                   axi_bresp  <= 2'b0;
                   // 'OKAY' response
               end
               else
               begin
                   if (S_AXI_BREADY && axi_bvalid)
                       //check if bready is asserted while bvalid is high)
                       //(there is a possibility that bready is always asserted high)
                   begin
                       axi_bvalid <= 1'b0;
                   end
               end
           end
       end
    */
    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 )
            axi_buser <= 0;
    end

    // At one time, axi_awready was the same as S_AXI_AWREADY.  Now, though,
    // with the extra write address skid buffer, this is no longer the case.
    // S_AXI_AWREADY is handled/created/managed by the skid buffer.
    //
    // assign S_AXI_AWREADY = axi_awready;
    //
    // The rest of these signals can be set according to their registered
    // values above.
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_BID     = axi_bid;
    //
    // This core does not produce any bus errors, nor does it support
    // exclusive access, so 2'b00 will always be the correct response.
    assign S_AXI_BRESP = { 1'b0, axi_exclusive_write };
    // }}}

    // }}}
    ////////////////////////////////////////////////////////////////////////
    //
    // Read processing
    // {{{
    ////////////////////////////////////////////////////////////////////////
    //
    //

    /*
       // Implement axi_arready generation

       // axi_arready is asserted for one S_AXI_ACLK clock cycle when
       // S_AXI_ARVALID is asserted. axi_awready is
       // de-asserted when reset (active low) is asserted.
       // The read address is also latched when S_AXI_ARVALID is
       // asserted. axi_araddr is reset to zero on reset assertion.

       always @( posedge S_AXI_ACLK )
       begin
           if ( S_AXI_ARESETN == 1'b0 )
           begin
               axi_arready <= 1'b0;
               axi_arv_arr_flag <= 1'b0;
           end
           else
           begin
               if (~axi_arready && S_AXI_ARVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag)
               begin
                   axi_arready <= 1'b1;
                   axi_arv_arr_flag <= 1'b1;
               end
               else if (axi_rvalid && S_AXI_RREADY && axi_arlen_cntr == axi_arlen)
                   // preparing to accept next address after current read completion
               begin
                   axi_arv_arr_flag  <= 1'b0;
               end
               else
               begin
                   axi_arready <= 1'b0;
               end
           end
       end
    */

    // axi_rlen
    // {{{
    reg [8:0] axi_rlen;
    initial
        axi_rlen = 0;
    always @(posedge S_AXI_ACLK)
        if (!S_AXI_ARESETN)
            axi_rlen <= 0;
        else if (S_AXI_ARVALID && S_AXI_ARREADY)
            axi_rlen <= S_AXI_ARLEN + (miso_req ? 0:1);
        else if (miso_req)
            axi_rlen <= axi_rlen - 1;
    // }}}

    // axi_arready
    // {{{
    initial
        axi_arready = 1;
    always @(posedge S_AXI_ACLK)
        if (!S_AXI_ARESETN)
            axi_arready <= 1;
        else if (S_AXI_ARVALID && S_AXI_ARREADY)
            axi_arready <= (S_AXI_ARLEN==0)&&(miso_req);
        else if (miso_req)
            axi_arready <= (axi_rlen <= 1);
    // }}}

    /*
       // Implement axi_araddr latching

       //This process is used to latch the address when both
       //S_AXI_ARVALID and S_AXI_RVALID are valid.
       always @( posedge S_AXI_ACLK )
       begin
           if ( S_AXI_ARESETN == 1'b0 )
           begin
               axi_araddr <= 0;
               axi_arlen_cntr <= 0;
               axi_arburst <= 0;
               axi_arlen <= 0;
               axi_rlast <= 1'b0;
               axi_ruser <= 0;
           end
           else
           begin
               if (~axi_arready && S_AXI_ARVALID && ~axi_arv_arr_flag)
               begin
                   // address latching
                   axi_araddr <= S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH - 1:0];
                   axi_arburst <= S_AXI_ARBURST;
                   axi_arlen <= S_AXI_ARLEN;
                   // start address of transfer
                   axi_arlen_cntr <= 0;
                   axi_rlast <= 1'b0;
               end
               else if((axi_arlen_cntr <= axi_arlen) && axi_rvalid && S_AXI_RREADY)
               begin

                   axi_arlen_cntr <= axi_arlen_cntr + 1;
                   axi_rlast <= 1'b0;

                   case (axi_arburst)
                       2'b00: // fixed burst
                           // The read address for all the beats in the transaction are fixed
                       begin
                           axi_araddr       <= axi_araddr;
                           //for arsize = 4 bytes (010)
                       end
                       2'b01: //incremental burst
                           // The read address for all the beats in the transaction are increments by awsize
                       begin
                           axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                           //araddr aligned to 4 byte boundary
                           axi_araddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};
                           //for awsize = 4 bytes (010)
                       end
                       2'b10: //Wrapping burst
                           // The read address wraps when the address reaches wrap boundary
                           if (ar_wrap_en)
                           begin
                               axi_araddr <= (axi_araddr - ar_wrap_size);
                           end
                           else
                           begin
                               axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                               //araddr aligned to 4 byte boundary
                               axi_araddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};
                           end
                       default: //reserved (incremental burst for example)
                       begin
                           axi_araddr <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB]+1;
                           //for arsize = 4 bytes (010)
                       end
                   endcase
               end
               else if((axi_arlen_cntr == axi_arlen) && ~axi_rlast && axi_arv_arr_flag )
               begin
                   axi_rlast <= 1'b1;
               end
               else if (S_AXI_RREADY)
               begin
                   axi_rlast <= 1'b0;
               end
           end
       end
    */
    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 )
            axi_ruser <= 0;
    end

    // Vivado will warn about rlen only using 4-bits.  This is
    // to be expected, since for a DATA_WIDTH of 32-bits, the axi_addr
    // module only uses the bottom four bits of rlen to determine
    // address increments
    reg [7:0]  rlen;
    // Vivado will also warn about the top bit of wsize being unused.
    // This is also to be expected for a DATA_WIDTH of 32-bits.
    reg [2:0]  rsize;
    reg [1:0]  rburst;
    reg [C_S_AXI_ADDR_WIDTH-1:0] raddr;
    wire [C_S_AXI_ADDR_WIDTH-1:0] next_rd_addr;
    axi_addr #(
                 // {{{
                 .AW(C_S_AXI_ADDR_WIDTH), .DW(C_S_AXI_DATA_WIDTH)
                 // }}}
             ) get_next_rd_addr(
                 // {{{
                 (S_AXI_ARREADY ? S_AXI_ARADDR : raddr),
                 (S_AXI_ARREADY  ? S_AXI_ARSIZE : rsize),
                 (S_AXI_ARREADY  ? S_AXI_ARBURST: rburst),
                 (S_AXI_ARREADY  ? S_AXI_ARLEN  : rlen),
                 next_rd_addr
                 // }}}
             );

    // Next read address calculation
    // {{{
    always @(posedge S_AXI_ACLK)
        if (miso_req)
            raddr <= next_rd_addr;
        else if (S_AXI_ARREADY)
        begin
            raddr <= S_AXI_ARADDR;
            if (OPT_LOWPOWER && !S_AXI_ARVALID)
                raddr <= 0;
        end

    // r*
    // {{{
    reg [C_S_AXI_ID_WIDTH-1:0] rid;
    reg rlock;
    always @(posedge S_AXI_ACLK)
        if (S_AXI_ARREADY)
        begin
            rburst   <= S_AXI_ARBURST;
            rsize    <= S_AXI_ARSIZE;
            rlen     <= S_AXI_ARLEN;
            rid      <= S_AXI_ARID;
            rlock    <= S_AXI_ARLOCK && S_AXI_ARVALID && OPT_LOCK;

            if (OPT_LOWPOWER && !S_AXI_ARVALID)
            begin
                rburst   <= 0;
                rsize    <= 0;
                rlen     <= 0;
                rid      <= 0;
                rlock    <= 0;
            end
        end
    // }}}

    // }}}

    // READ SKID BUFFER
    wire rskd_ready;

    // rskd_valid
    // {{{
    reg rskd_valid;
    initial
        rskd_valid = 0;
    always @(posedge S_AXI_ACLK)
        if (!S_AXI_ARESETN)
            rskd_valid <= 0;
        else if (miso_req)
            rskd_valid <= 1;
        else if (rskd_ready)
            rskd_valid <= 0;
    // }}}

    // rskd_id
    // {{{
    reg [C_S_AXI_ID_WIDTH-1:0] rskd_id;
    always @(posedge S_AXI_ACLK)
        if (!rskd_valid || rskd_ready)
        begin
            if (S_AXI_ARVALID && S_AXI_ARREADY)
                rskd_id <= S_AXI_ARID;
            else
                rskd_id <= rid;
        end
    // }}}

    // rskd_last
    // {{{
    reg rskd_last;
    initial
        rskd_last   = 0;
    always @(posedge S_AXI_ACLK)
        if (!rskd_valid || rskd_ready)
        begin
            rskd_last <= 0;
            if (miso_req && axi_rlen == 1)
                rskd_last <= 1;
            if (S_AXI_ARVALID && S_AXI_ARREADY && S_AXI_ARLEN == 0)
                rskd_last <= 1;
        end
    // }}}

    // rskd_lock
    // {{{
    reg rskd_lock;
    always @(posedge S_AXI_ACLK)
        if (!S_AXI_ARESETN || !OPT_LOCK)
            rskd_lock <= 1'b0;
        else if (!rskd_valid || rskd_ready)
        begin
            rskd_lock <= 0;
            if (!OPT_LOWPOWER || miso_req)
            begin
                if (S_AXI_ARVALID && S_AXI_ARREADY)
                    rskd_lock <= S_AXI_ARLOCK;
                else
                    rskd_lock <= rlock;
            end
        end
    // }}}


    // Outgoing read skidbuffer
    // {{{
    localparam integer RSKID_DW = C_S_AXI_ID_WIDTH + C_S_AXI_DATA_WIDTH + 2;
    skidbuffer #(
                   // {{{
                   .OPT_LOWPOWER(OPT_LOWPOWER),
                   .OPT_OUTREG(1),
                   .DW(RSKID_DW)
                   // }}}
               ) rskid (
                   // {{{
                   .i_clk(S_AXI_ACLK), .i_reset(!S_AXI_ARESETN),
                   .i_valid(rskd_valid), .o_ready(rskd_ready),
                   .i_data({ rskd_id, rskd_lock, rskd_last, miso_data }),
                   .o_valid(S_AXI_RVALID), .i_ready(S_AXI_RREADY),
                   .o_data({ S_AXI_RID, S_AXI_RRESP[0], S_AXI_RLAST, S_AXI_RDATA })
                   // }}}
               );
    // }}}

    assign S_AXI_RRESP[1] = 1'b0;
    assign S_AXI_ARREADY = axi_arready;

    // }}}
    ////////////////////////////////////////////////////////////////////////
    //
    // Exclusive address caching
    // {{{
    ////////////////////////////////////////////////////////////////////////
    //
    //

    generate if (OPT_LOCK && !OPT_LOCKID)
        begin : EXCLUSIVE_ACCESS_BLOCK
            // {{{
            // The AXI4 specification requires that we check one address
            // per ID.  This isn't that.  This algorithm checks one ID,
            // whichever the last ID was.  It's designed to be lighter on
            // the logic requirements, and (unnoticably) not (fully) spec
            // compliant.  (The difference, if noticed at all, will be in
            // performance when multiple masters try to perform an exclusive
            // transaction at once.)

            // Local declarations
            // {{{
            reg   w_valid_lock_request, w_cancel_lock,
                  w_lock_request,
                  lock_valid, returned_lock_valid;
            reg [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] lock_start, lock_end;
            reg [3:0]  lock_len;
            reg [1:0]  lock_burst;
            reg [2:0]  lock_size;
            reg [C_S_AXI_ID_WIDTH-1:0] lock_id;
            reg   w_write_lock_valid;
            // }}}

            // w_lock_request
            // {{{
            always @(*)
            begin
                w_lock_request = 0;
                if (S_AXI_ARVALID && S_AXI_ARREADY && S_AXI_ARLOCK)
                    w_lock_request = 1;
            end
            // }}}

            // w_valid_lock_request
            // {{{
            always @(*)
            begin
                w_valid_lock_request = 0;
                if (w_lock_request)
                    w_valid_lock_request = 1;
                if (mosi_req && mosi_addr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] == S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB])
                    w_valid_lock_request = 0;
            end
            // }}}

            // returned_lock_valid
            // {{{
            initial
                returned_lock_valid = 0;
            always @(posedge S_AXI_ACLK)
                if (!S_AXI_ARESETN)
                    returned_lock_valid <= 0;
                else if (S_AXI_ARVALID && S_AXI_ARREADY
                         && S_AXI_ARLOCK && S_AXI_ARID== lock_id)
                    returned_lock_valid <= 0;
                else if (w_cancel_lock)
                    returned_lock_valid <= 0;
                else if (rskd_valid && rskd_lock && rskd_ready)
                    returned_lock_valid <= lock_valid;
            // }}}

            // w_cancel_lock
            // {{{
            always @(*)
                w_cancel_lock = (lock_valid && w_lock_request)
                              || (lock_valid && mosi_req
                                  && mosi_addr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] >= lock_start
                                  && mosi_addr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= lock_end
                                  && mosi_data_mask != 0);
            // }}}

            // lock_valid
            // {{{
            initial
                lock_valid = 0;
            always @(posedge S_AXI_ACLK)
                if (!S_AXI_ARESETN || !OPT_LOCK)
                    lock_valid <= 0;
                else
                begin
                    if (S_AXI_ARVALID && S_AXI_ARREADY
                            && S_AXI_ARLOCK && S_AXI_ARID== lock_id)
                        lock_valid <= 0;
                    if (w_cancel_lock)
                        lock_valid <= 0;
                    if (w_valid_lock_request)
                        lock_valid <= 1;
                end
            // }}}

            // lock_start, lock_end, lock_len, lock_size, lock_id
            // {{{
            always @(posedge S_AXI_ACLK)
                if (w_valid_lock_request)
                begin
                    lock_start <= S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB];
                    lock_end <= S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB]
                             + ((S_AXI_ARBURST == 2'b00) ? 0 : S_AXI_ARLEN[3:0]);
                    lock_len   <= S_AXI_ARLEN[3:0];
                    lock_burst <= S_AXI_ARBURST;
                    lock_size  <= S_AXI_ARSIZE;
                    lock_id    <= S_AXI_ARID;
                end
            // }}}

            // w_write_lock_valid
            // {{{
            always @(*)
            begin
                w_write_lock_valid = returned_lock_valid;
                if (!m_awvalid || !m_awready || !m_awlock || !lock_valid)
                    w_write_lock_valid = 0;
                if (m_awaddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] != lock_start)
                    w_write_lock_valid = 0;
                if (m_awid != lock_id)
                    w_write_lock_valid = 0;
                if (m_awlen[3:0] != lock_len) // MAX transfer size is 16 beats
                    w_write_lock_valid = 0;
                if (m_awburst != 2'b01 && lock_len != 0)
                    w_write_lock_valid = 0;
                if (m_awsize != lock_size)
                    w_write_lock_valid = 0;
            end
            // }}}

            assign write_lock_valid = w_write_lock_valid;
            // }}}
        end
        else if (OPT_LOCK) // && OPT_LOCKID
        begin : EXCLUSIVE_ACCESS_PER_ID
            // {{{

            genvar gk;
            wire [(1<<C_S_AXI_ID_WIDTH)-1:0] write_lock_valid_per_id;

            for(gk=0; gk<(1<<C_S_AXI_ID_WIDTH); gk=gk+1)
            begin : PER_ID_LOGIC
                // {{{
                // Local declarations
                // {{{
                reg   w_valid_lock_request,
                      w_cancel_lock,
                      lock_valid, returned_lock_valid;
                reg [1:0]  lock_burst;
                reg [2:0]  lock_size;
                reg [3:0]  lock_len;
                reg [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] lock_start, lock_end;
                reg   w_write_lock_valid;
                // }}}

                // valid_lock_request
                // {{{
                always @(*)
                begin
                    w_valid_lock_request = 0;
                    if (S_AXI_ARVALID && S_AXI_ARREADY
                            && S_AXI_ARID == gk[C_S_AXI_ID_WIDTH-1:0]
                            && S_AXI_ARLOCK)
                        w_valid_lock_request = 1;
                    if (mosi_req && mosi_addr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] == S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB])
                        w_valid_lock_request = 0;
                end
                // }}}

                // returned_lock_valid
                // {{{
                initial
                    returned_lock_valid = 0;
                always @(posedge S_AXI_ACLK)
                    if (!S_AXI_ARESETN)
                        returned_lock_valid <= 0;
                    else if (S_AXI_ARVALID && S_AXI_ARREADY
                             &&S_AXI_ARLOCK&&S_AXI_ARID== gk[C_S_AXI_ID_WIDTH-1:0])
                        returned_lock_valid <= 0;
                    else if (w_cancel_lock)
                        returned_lock_valid <= 0;
                    else if (rskd_valid && rskd_lock && rskd_ready
                             && rskd_id == gk[C_S_AXI_ID_WIDTH-1:0])
                        returned_lock_valid <= lock_valid;
                // }}}

                // w_cancel_lock
                // {{{
                always @(*)
                    w_cancel_lock=(lock_valid&&w_valid_lock_request)
                                 || (lock_valid && mosi_req
                                     && mosi_addr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] >= lock_start
                                     && mosi_addr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= lock_end
                                     && mosi_data_mask != 0);
                // }}}

                // lock_valid
                // {{{
                initial
                    lock_valid = 0;
                always @(posedge S_AXI_ACLK)
                    if (!S_AXI_ARESETN || !OPT_LOCK)
                        lock_valid <= 0;
                    else
                    begin
                        if (S_AXI_ARVALID && S_AXI_ARREADY
                                && S_AXI_ARLOCK
                                && S_AXI_ARID == gk[C_S_AXI_ID_WIDTH-1:0])
                            lock_valid <= 0;
                        if (w_cancel_lock)
                            lock_valid <= 0;
                        if (w_valid_lock_request)
                            lock_valid <= 1;
                    end
                // }}}

                // lock_start, lock_end, lock_len, lock_size
                // {{{
                always @(posedge S_AXI_ACLK)
                    if (w_valid_lock_request)
                    begin
                        lock_start <= S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB];
                        // Verilator lint_off WIDTH
                        lock_end <= S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB]
                                 + ((S_AXI_ARBURST == 2'b00) ? 4'h0 : S_AXI_ARLEN[3:0]);
                        // Verilator lint_on  WIDTH
                        lock_len   <= S_AXI_ARLEN[3:0];
                        lock_size  <= S_AXI_ARSIZE;
                        lock_burst <= S_AXI_ARBURST;
                    end
                // }}}

                // w_write_lock_valid
                // {{{
                always @(*)
                begin
                    w_write_lock_valid = returned_lock_valid;
                    if (!m_awvalid || !m_awready || !m_awlock || !lock_valid)
                        w_write_lock_valid = 0;
                    if (m_awaddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] != lock_start)
                        w_write_lock_valid = 0;
                    if (m_awid[C_S_AXI_ID_WIDTH-1:0] != gk[C_S_AXI_ID_WIDTH-1:0])
                        w_write_lock_valid = 0;
                    if (m_awlen[3:0] != lock_len) // MAX transfer size is 16 beats
                        w_write_lock_valid = 0;
                    if (m_awburst != 2'b01 && lock_len != 0)
                        w_write_lock_valid = 0;
                    if (m_awsize != lock_size)
                        w_write_lock_valid = 0;
                end
                // }}}

                assign write_lock_valid_per_id[gk]= w_write_lock_valid;
                // }}}
            end

            assign write_lock_valid = |write_lock_valid_per_id;
            // }}}
        end
        else
        begin : NO_LOCKING
            // {{{

            assign write_lock_valid = 1'b0;
            // Verilator lint_off UNUSED
            wire unused_lock;
            assign unused_lock = &{ 1'b0, S_AXI_ARLOCK, S_AXI_AWLOCK };
            // Verilator lint_on  UNUSED
            // }}}
        end
    endgenerate
    // }}}

    /*
       // ------------------------------------------
       // -- Example code to access user logic memory region
       // ------------------------------------------

       generate
           if (USER_NUM_MEM >= 1)
           begin
               assign mem_select  = 1;
               assign mem_address = (axi_arv_arr_flag? axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]:(axi_awv_awr_flag? axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]:0));
           end
       endgenerate

       // implement Block RAM(s)
       generate
           for(i=0; i<= USER_NUM_MEM-1; i=i+1)
           begin:BRAM_GEN
               wire mem_rden;
               wire mem_wren;

               assign mem_wren = axi_wready && S_AXI_WVALID ;

               assign mem_rden = axi_arv_arr_flag ; //& ~axi_rvalid

               for(mem_byte_index=0; mem_byte_index<= (C_S_AXI_DATA_WIDTH/8-1); mem_byte_index=mem_byte_index+1)
               begin:BYTE_BRAM_GEN
                   wire [8-1:0] data_in ;
                   wire [8-1:0] data_out;
                   reg  [8-1:0] byte_ram [0 : 15];
                   integer  j;

                   //assigning 8 bit data
                   assign data_in  = S_AXI_WDATA[(mem_byte_index*8+7) -: 8];
                   assign data_out = byte_ram[mem_address];

                   always @( posedge S_AXI_ACLK )
                   begin
                       if (mem_wren && S_AXI_WSTRB[mem_byte_index])
                       begin
                           byte_ram[mem_address] <= data_in;
                       end
                   end

                   always @( posedge S_AXI_ACLK )
                   begin
                       if (mem_rden)
                       begin
                           mem_data_out[i][(mem_byte_index*8+7) -: 8] <= data_out;
                       end
                   end

               end
           end
       endgenerate
       //Output register or memory read data

       always @( mem_data_out, axi_rvalid)
       begin
           if (axi_rvalid)
           begin
               // Read address mux
               axmiso_data <= mem_data_out[0];
           end
           else
           begin
               axmiso_data <= 32'h00000000;
           end
       end
    */


    ////////////////////////////////////////////////////////////////////////
    //
    // Read/Write processing
    // {{{
    ////////////////////////////////////////////////////////////////////////

    // o_w*
    // {{{
    always @(posedge S_AXI_ACLK)
    begin
        mosi_req <= (S_AXI_WVALID && S_AXI_WREADY && S_AXI_ARESETN);
        mosi_addr <= {waddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB], {(ADDR_LSB){1'b0}}};
        mosi_data <= S_AXI_WDATA;
        if (block_write)
            mosi_data_mask <= 0;
        else
            mosi_data_mask <= S_AXI_WSTRB;

        if (OPT_LOWPOWER && (!S_AXI_ARESETN || !S_AXI_WVALID
                             || !S_AXI_WREADY))
        begin
            mosi_addr <= 0;
            mosi_data <= 0;
            mosi_data_mask <= 0;
        end
    end
    // }}}
    // o_rd, o_raddr
    // {{{
    always @(*)
    begin
        miso_req = (S_AXI_ARVALID || !S_AXI_ARREADY) && (!S_AXI_RVALID || S_AXI_RREADY) && (!rskd_valid || rskd_ready);
        miso_addr = {(S_AXI_ARREADY ? S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] : raddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB]), {(ADDR_LSB){1'b0}}};
    end
    // }}}
    // }}}

    // Add user logic here

    // User logic ends

endmodule
