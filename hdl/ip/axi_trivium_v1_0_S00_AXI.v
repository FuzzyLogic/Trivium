//////////////////////////////////////////////////////////////////////////////////
// Engineer:         Christian P. Feist
// 
// Create Date:      20:31:12 10/06/2016 
// Design Name:      /
// Module Name:      axi_trivium_v1_0_S00_AXI
// Project Name:     Trivium
// Target Devices:   Spartan-6, Zynq
// Tool versions:    ISE 14.7, Vivado v2016.2
// Description:      The top module of the Trivium IP core. Its interface is designed
//                   such that it can connected as an AXI4LITE slave.
//                   The module contains several registers that may be read or written to,
//                   a full list is given below.
//                   Register map (All values are interpreted as little-endian):
//                      +0:      Control register (RW)
//                         -0.0: UNUSED | ... | UNUSED | Process (RWS) | Stop (RWS)| Init (RWS) 
//                         -0.1: UNUSED | ... | UNUSED | Ready (R) | Output available (R)
//                         -0.2: UNUSED | ... | UNUSED
//                         -0.3: UNUSED | ... | UNUSED
//                      +1 to 3: Key register (Least significant bytes at bottom of 1, RW)
//                      +4 to 6: IV register (Least significant bytes at bottom of 4, RW)
//                      +7:      Input data register (RW)
//                      +8:      Output data register (R)
//
//                   Notation: R(Read), W(Write), S(Self clearing, will read as zero)
//
// Dependencies:     /
//
// Revision: 
// Revision 0.01 - File Created 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1 ns / 1 ps

module axi_trivium_v1_0_S00_AXI #
(
    /* Width of S_AXI data bus */
    parameter integer C_S_AXI_DATA_WIDTH	= 32,
    /* Width of S_AXI address bus */
    parameter integer C_S_AXI_ADDR_WIDTH	= 6
)
(
    /* Global Clock Signal */
    input wire  S_AXI_ACLK,
    /* Global Reset Signal. This Signal is Active LOW */
    input wire  S_AXI_ARESETN,
    /* Write address (issued by master, acceped by Slave) */
    input wire [C_S_AXI_ADDR_WIDTH - 1:0] S_AXI_AWADDR,
    /* 
     * Write channel Protection type. This signal indicates the
     * privilege and security level of the transaction, and whether
     * the transaction is a data access or an instruction access.
     */
    input wire [2:0] S_AXI_AWPROT,
    /* 
     * Write address valid. This signal indicates that the master signaling
     * valid write address and control information.
     */
    input wire  S_AXI_AWVALID,
    /* 
     * Write address ready. This signal indicates that the slave is ready
     * to accept an address and associated control signals.
     */
    output wire  S_AXI_AWREADY,
    /* Write data (issued by master, acceped by Slave) */ 
    input wire [C_S_AXI_DATA_WIDTH - 1:0] S_AXI_WDATA,
    /* 
     * Write strobes. This signal indicates which byte lanes hold
     * valid data. There is one write strobe bit for each eight
     * bits of the write data bus.
     */    
    input wire [(C_S_AXI_DATA_WIDTH/8) - 1:0] S_AXI_WSTRB,
    /* 
     * Write valid. This signal indicates that valid write
     * data and strobes are available.
     */
    input wire  S_AXI_WVALID,
    /* 
     * Write ready. This signal indicates that the slave
     * can accept the write data.
     */
    output wire  S_AXI_WREADY,
    /* 
     * Write response. This signal indicates the status
     * of the write transaction.
     */
    output wire [1:0] S_AXI_BRESP,
    /* 
     * Write response valid. This signal indicates that the channel
     * is signaling a valid write response.
     */
    output wire  S_AXI_BVALID,
    /* 
     * Response ready. This signal indicates that the master
     * can accept a write response.
     */
    input wire  S_AXI_BREADY,
    /* Read address (issued by master, acceped by Slave) */
    input wire [C_S_AXI_ADDR_WIDTH - 1:0] S_AXI_ARADDR,
    /* 
     * Protection type. This signal indicates the privilege
     * and security level of the transaction, and whether the
     * transaction is a data access or an instruction access.
     */
    input wire [2:0] S_AXI_ARPROT,
    /* 
     * Read address valid. This signal indicates that the channel
     * is signaling valid read address and control information.
     */
    input wire  S_AXI_ARVALID,
    /* 
     * Read address ready. This signal indicates that the slave is
     * ready to accept an address and associated control signals.
     */
    output wire  S_AXI_ARREADY,
    /* Read data (issued by slave) */
    output wire [C_S_AXI_DATA_WIDTH - 1:0] S_AXI_RDATA,
    /* 
     * Read response. This signal indicates the status of the
     * read transfer.
     */
    output wire [1:0] S_AXI_RRESP,
    /* 
     * Read valid. This signal indicates that the channel is
     * signaling the required read data.
     */
    output wire  S_AXI_RVALID,
    /* 
     * Read ready. This signal indicates that the master can
     * accept the read data and response information.
     */
    input wire  S_AXI_RREADY
);

//////////////////////////////////////////////////////////////////////////////////
// AXI4LITE signals
//////////////////////////////////////////////////////////////////////////////////
reg [C_S_AXI_ADDR_WIDTH - 1:0]  axi_awaddr;
reg                             axi_awready;
reg                             axi_wready;
reg [1:0]                       axi_bresp;
reg                             axi_bvalid;
reg [C_S_AXI_ADDR_WIDTH - 1:0]  axi_araddr;
reg                             axi_arready;
reg [C_S_AXI_DATA_WIDTH - 1:0]  axi_rdata;
reg [1:0]                       axi_rresp;
reg                             axi_rvalid;

//////////////////////////////////////////////////////////////////////////////////
// Register space related signals and parameters
//////////////////////////////////////////////////////////////////////////////////
localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
localparam integer OPT_MEM_ADDR_BITS = 3;

reg    [C_S_AXI_DATA_WIDTH - 1:0]  reg_conf_r;      /* Configuration register */
reg    [C_S_AXI_DATA_WIDTH - 1:0]  reg_key_lo_r;    /* Key register LO */
reg    [C_S_AXI_DATA_WIDTH - 1:0]  reg_key_mid_r;   /* Key register MID */
reg    [C_S_AXI_DATA_WIDTH - 1:0]  reg_key_hi_r;    /* Key register HI */
reg    [C_S_AXI_DATA_WIDTH - 1:0]  reg_iv_lo_r;     /* IV register LO */
reg    [C_S_AXI_DATA_WIDTH - 1:0]  reg_iv_mid_r;    /* IV register MID */
reg    [C_S_AXI_DATA_WIDTH - 1:0]  reg_iv_hi_r;     /* IV register HI */
reg    [C_S_AXI_DATA_WIDTH - 1:0]  reg_idat_r;      /* Input data register */
wire   [C_S_AXI_DATA_WIDTH - 1:0]  reg_odat_s;      /* Output data register */
reg    [C_S_AXI_DATA_WIDTH - 1:0]  ld_dat_r;        /* Data loaded into register a or b */
reg    [2:0]                       ld_sel_a_r;      /* Register a slice selection */
reg    [2:0]                       ld_sel_b_r;      /* Register b slice selection */
reg                                init_r;          /* Init cipher */
reg                                stop_r;          /* Stop any calculations and reset the core */
reg                                proc_r;          /* Start processing */                        
wire                               busy_s;          /* Flag indicating whether core is busy */  
wire                               slv_reg_rden_r;  /* Signal that triggers the output of data */
wire                               slv_reg_wren_r;  /* Signal that triggers the capture of input data */
reg    [C_S_AXI_DATA_WIDTH - 1:0]  reg_data_out;    /* Data being read from registers */
integer                            byte_index;      /* Iteration index used for byte access of registers */                                

//////////////////////////////////////////////////////////////////////////////////
// I/O Connection Assignments
//////////////////////////////////////////////////////////////////////////////////
assign S_AXI_AWREADY    = axi_awready;
assign S_AXI_WREADY     = axi_wready;
assign S_AXI_BRESP      = axi_bresp;
assign S_AXI_BVALID     = axi_bvalid;
assign S_AXI_ARREADY    = axi_arready;
assign S_AXI_RDATA      = axi_rdata;
assign S_AXI_RRESP      = axi_rresp;
assign S_AXI_RVALID     = axi_rvalid;
	
//////////////////////////////////////////////////////////////////////////////////
// Module instantiations
//////////////////////////////////////////////////////////////////////////////////
trivium_top trivium(
    .clk_i(S_AXI_ACLK),
    .n_rst_i(S_AXI_ARESETN & ~stop_r),
    .dat_i(reg_idat_r),
    .ld_dat_i(ld_dat_r),
    .ld_reg_a_i(ld_sel_a_r),
    .ld_reg_b_i(ld_sel_b_r),   
    .init_i(init_r),
    .proc_i(proc_r),
    .dat_o(reg_odat_s),
    .busy_o(busy_s)
);

/* 
 * Implement axi_awready generation
 * axi_awready is asserted for one S_AXI_ACLK clock cycle when both
 * S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
 * de-asserted when reset is low.
 */
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0)
        axi_awready <= 1'b0;
    else begin    
        if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
          /* 
           * Slave is ready to accept write address when 
           * there is a valid write address and write data
           * on the write address and data bus. This design 
           * expects no outstanding transactions.
           */ 
            axi_awready <= 1'b1;
        end
        else
            axi_awready <= 1'b0;
    end 
end       

/* 
 * Implement axi_awaddr latching
 * This process is used to latch the address when both 
 * S_AXI_AWVALID and S_AXI_WVALID are valid.
 */ 
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0)
        axi_awaddr <= 0;
    else begin    
        if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
            /* Write Address latching */ 
            axi_awaddr <= S_AXI_AWADDR;
        end
    end 
end       

/* 
 * Implement axi_wready generation
 * axi_wready is asserted for one S_AXI_ACLK clock cycle when both
 * S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
 * de-asserted when reset is low.
 */ 
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0)
        axi_wready <= 1'b0;
    else begin    
        if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID) begin
            /* 
             * Slave is ready to accept write data when 
             * there is a valid write address and write data
             * on the write address and data bus. This design 
             * expects no outstanding transactions.
             */ 
            axi_wready <= 1'b1;
        end
        else
            axi_wready <= 1'b0;
    end 
end       

/* 
 * Implement memory mapped register select and write logic generation
 * The write data is accepted and written to memory mapped registers when
 * axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
 * select byte enables of slave registers while writing.
 * These registers are cleared when reset (active low) is applied.
 * Slave register write enable is asserted when valid address and data are available
 * and the slave is ready to accept the write address and write data.
 */
assign slv_reg_wren_r = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        /* Reset addressable registers driven here */
        reg_conf_r <= 0;
        reg_key_lo_r <= 0;
        reg_key_mid_r <= 0;
        reg_key_hi_r <= 0;
        reg_iv_lo_r <= 0;
        reg_iv_mid_r <= 0;
        reg_iv_hi_r <= 0;
        reg_idat_r <= 0;
        
        /* Reset any other registers driven here */
        init_r <= 0;
        stop_r <= 0;
        proc_r <= 0;
        ld_dat_r <= 0;
        ld_sel_a_r <= 0;
        ld_sel_b_r <= 0;
    end 
    else begin
        if (slv_reg_wren_r) begin
            case (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
                4'h0:       /* Configuration register */
                    /* Currently only byte 0 of configuration register is writable */
                    if (S_AXI_WSTRB[0] == 1'b1) begin
                        if (S_AXI_WDATA[1] == 1'b1)                 /* Bit 1 resets core in any case */
                            stop_r <= 1'b1;
                        else if (S_AXI_WDATA[0] == 1'b1 & !busy_s)  /* Bit 0 triggers init if core is not busy */
                            init_r <= 1'b1;
                        else if (S_AXI_WDATA[2] == 1'b1 & !busy_s)  /* Bit 2 triggers processing if core is not busy */
                        proc_r <= 1'b1;
                    end
                4'h1: begin /* LO key register */
                    /* Reconstruct key LO value written so far */
                    ld_dat_r <= reg_key_lo_r;
                    ld_sel_a_r[0] <= 1'b1;
                    for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1) begin
                        /* Incorporate the rest that is currently being written */
                        if (S_AXI_WSTRB[byte_index] == 1) begin
                            ld_dat_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            reg_key_lo_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end 
                    end 
                end
                4'h2: begin /* MID key register */
                    /* Reconstruct key MID value written so far */
                    ld_dat_r <= reg_key_mid_r;
                    ld_sel_a_r[1] <= 1'b1;
                    for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1) begin
                        /* Incorporate the rest that is currently being written */
                        if (S_AXI_WSTRB[byte_index] == 1) begin
                            ld_dat_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            reg_key_mid_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end 
                    end 
                end  
                4'h3: begin /* HI key register */
                    /* Reconstruct key HI value written so far */
                    ld_dat_r <= reg_key_hi_r;
                    ld_sel_a_r[2] <= 1'b1;
                    for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1) begin
                        /* Incorporate the rest that is currently being written */
                        if (S_AXI_WSTRB[byte_index] == 1) begin
                            ld_dat_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            reg_key_hi_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end 
                    end 
                end  
                4'h4: begin /* LO IV register */
                    /* Reconstruct IV LO value written so far */
                    ld_dat_r <= reg_iv_lo_r;
                    ld_sel_b_r[0] <= 1'b1;
                    for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1) begin
                        /* Incorporate the rest that is currently being written */
                        if (S_AXI_WSTRB[byte_index] == 1) begin
                            ld_dat_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            reg_iv_lo_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end 
                    end 
                end  
                4'h5:begin /* MID IV register */
                    /* Reconstruct IV MID value written so far */
                    ld_dat_r <= reg_iv_mid_r;
                    ld_sel_b_r[1] <= 1'b1;
                    for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1) begin
                        /* Incorporate the rest that is currently being written */
                        if (S_AXI_WSTRB[byte_index] == 1) begin
                            ld_dat_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            reg_iv_mid_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end 
                    end 
                end  
                4'h6:begin /* LO IV register */
                    /* Reconstruct IV HI value written so far */
                    ld_dat_r <= reg_iv_hi_r;
                    ld_sel_b_r[2] <= 1'b1;
                    for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1) begin
                        /* Incorporate the rest that is currently being written */
                        if (S_AXI_WSTRB[byte_index] == 1) begin
                            ld_dat_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            reg_iv_hi_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end 
                    end 
                end
                4'h7:   /* Input data register */
                    /* Respective byte enables are asserted as per write strobes */
                    for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                        if (S_AXI_WSTRB[byte_index] == 1) begin
                            reg_idat_r[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end  
                default: begin
                    reg_conf_r <= reg_conf_r;
                    reg_key_lo_r <= reg_key_lo_r;
                    reg_key_mid_r <= reg_key_mid_r;
                    reg_key_hi_r <= reg_key_hi_r;
                    reg_iv_lo_r <= reg_iv_lo_r;
                    reg_iv_mid_r <= reg_iv_mid_r;
                    reg_iv_hi_r <= reg_iv_hi_r;
                    reg_idat_r <= reg_idat_r;
                end
            endcase
        end
        else begin
            /* Reset all strobes/pulses that resulted from a register write */
            init_r <= 0;
            stop_r <= 0;
            proc_r <= 0;
            ld_sel_a_r <= 0;
            ld_sel_b_r <= 0;
        end
    end
end    

/* 
 * Implement write response logic generation
 * The write response and response valid signals are asserted by the slave 
 * when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
 * This marks the acceptance of address and indicates the status of 
 * write transaction.
 */
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        axi_bvalid  <= 0;
        axi_bresp   <= 2'b0;
    end 
    else begin    
        if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
            /* Indicates a valid write response is available */
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b0; /* 'OKAY' response */ 
        end                   /* work error responses in future */
        else begin
            if (S_AXI_BREADY && axi_bvalid) begin
                /* Check if bready is asserted while bvalid is high) */ 
                /* (there is a possibility that bready is always asserted high) */   
                axi_bvalid <= 1'b0; 
            end  
        end
    end
end   

/* 
 * Implement axi_arready generation
 * axi_arready is asserted for one S_AXI_ACLK clock cycle when
 * S_AXI_ARVALID is asserted. axi_awready is 
 * de-asserted when reset (active low) is asserted. 
 * The read address is also latched when S_AXI_ARVALID is 
 * asserted. axi_araddr is reset to zero on reset assertion.
 */
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        axi_arready <= 1'b0;
        axi_araddr  <= 32'b0;
    end 
    else begin    
        if (~axi_arready && S_AXI_ARVALID) begin
            /* Indicates that the slave has acceped the valid read address */
            axi_arready <= 1'b1;
            /* Read address latching */
            axi_araddr  <= S_AXI_ARADDR;
        end
        else
            axi_arready <= 1'b0;
    end 
end       

/* 
 * Implement axi_arvalid generation
 * axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
 * S_AXI_ARVALID and axi_arready are asserted. The slave registers 
 * data are available on the axi_rdata bus at this instance. The 
 * assertion of axi_rvalid marks the validity of read data on the 
 * bus and axi_rresp indicates the status of read transaction.axi_rvalid 
 * is deasserted on reset (active low). axi_rresp and axi_rdata are 
 * cleared to zero on reset (active low).
 */  
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        axi_rvalid <= 0;
        axi_rresp  <= 0;
    end 
    else begin    
        if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
            /* Valid read data is available at the read data bus */
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b0; /* 'OKAY' response */
        end   
        else if (axi_rvalid && S_AXI_RREADY) begin
            /* Read data is accepted by the master */
            axi_rvalid <= 1'b0;
        end                
    end
end    

/* 
* Implement memory mapped register select and read logic generation
* Slave register read enable is asserted when valid address is available
* and the slave is ready to accept the read address.
*/
assign slv_reg_rden_r = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
always @(*)	begin
    /* Address decoding for reading registers */
    case (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
        4'h0:       reg_data_out <= {16'h0000, 6'b000000, ~busy_s, 1'b0, 8'h00};
        4'h1:       reg_data_out <= reg_key_lo_r;
        4'h2:       reg_data_out <= reg_key_mid_r;
        4'h3:       reg_data_out <= reg_key_hi_r;
        4'h4:       reg_data_out <= reg_iv_lo_r;
        4'h5:       reg_data_out <= reg_iv_mid_r;
        4'h6:       reg_data_out <= reg_iv_hi_r;
        4'h7:       reg_data_out <= reg_idat_r;
        4'h8:       reg_data_out <= reg_odat_s;
        default:    reg_data_out <= 0;
    endcase
end

/* Output register or memory read data */
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0)
        axi_rdata  <= 0;
    else begin    
        /* 
         * When there is a valid read address (S_AXI_ARVALID) with 
         * acceptance of read address by the slave (axi_arready), 
         * output the read dada
         */ 
        if (slv_reg_rden_r)
            axi_rdata <= reg_data_out;  /* Register read data */
    end
end    

endmodule
