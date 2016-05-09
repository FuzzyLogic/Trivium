//////////////////////////////////////////////////////////////////////////////////
// Engineer:         Christian P. Feist
// 
// Create Date:      17:54:27 05/04/2016 
// Design Name:      /
// Module Name:      trivium_top
// Project Name:     Trivium
// Target Devices:   Spartan-6
// Tool versions:    ISE 14.7
// Description:      The top module of the Trivium core. Its interface is designed
//                   such that it can be interfaced using the MicroBlaze PLB.
//                   The module contains several registers that may be written to,
//                   a full list is given below.
//                   Register map (All values are interpreted as little-endian):
//                      +0:      Control register (RW)
//                         -0.0: UNUSED | ... | UNUSED | Stop (RWS)| Init (RWS) 
//                         -0.1: UNUSED | ... | UNUSED | Ready (R) | Output available (R)
//                         -0.2: UNUSED | ... | UNUSED
//                         -0.3: UNUSED | ... | UNUSED
//                      +1 to 3: Key register (Least significant bytes in top of 1, W)
//                      +4 to 6: IV register (Least significant bytes in top of 4, W)
//                      +7:      Input data register (W)
//                      +8:      Output data register (R)
//
//                   Notation: R(Read), W(Write), S(Self clearing)
//
// Dependencies:     /
//
// Revision: 
// Revision 0.01 - File Created 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
`default_nettype none
`include "trivium_globals.v"

module trivium_top(
   // Module inputs
   input wire           bus2ip_clk_i,     // Bus to IP clock
   input wire           bus2ip_rst_i,     // Bus to IP asynchronous active high reset
   input wire  [3:0]    bus2ip_addr_i,    // Bus to IP address bus
   input wire           bus2ip_rnw_i,     // Bus to IP read/not write
   input wire  [31:0]   bus2ip_dat_i,     // Bus to IP data bus
   input wire  [3:0]    bus2ip_be_i,      // Bus to IP byte enables
   input wire  [8:0]    bus2ip_rdce_i,    // Bus to IP read chip enable
   input wire  [8:0]    bus2ip_wrce_i,    // Bus to IP write chip enable

   // Module outputs
   output reg [31:0]    ip2bus_dat_o,     // IP to bus data bus
   output reg           ip2bus_rdack_o,   // IP to bus read transfer acknowledgement
   output reg           ip2bus_wrack_o,   // IP to bus write transfer acknowledgement
   output wire          ip2bus_err_o      // IP to bus error flag
);

//////////////////////////////////////////////////////////////////////////////////
// Signal definitions
//////////////////////////////////////////////////////////////////////////////////
reg [2:0] next_state_s;       // Next state of the FSM
reg [2:0] cur_state_r;        // Current state of the FSM
reg [31:0] reg_bank_r [2:0];  // Registers (see description at top for register map)
reg [10:0] cntr_r;            // Counter for warm-up and input processing
reg cphr_en_r;                // Cipher enable flag
reg [2:0] ld_reg_a_s;         // Load value into reg_a
reg [2:0] ld_reg_b_s;         // Load value into reg_b
wire bit_out_s;               // Cipher output bit
wire n_rst_s;                 // Asynchronous active low reset for all components
integer i;

//////////////////////////////////////////////////////////////////////////////////
// Local parameter definitions
//////////////////////////////////////////////////////////////////////////////////
parameter   IDLE_e = 0, 
            WARMUP_e = 1, 
            WAIT_INPUT_e = 2, 
            PROC_e = 3, 
            WAIT_OUTPUT_e = 4;
            
parameter   CTRL_REG_IDX_c = 0,  // Control register index for reg_bank_r
            IN_REG_IDX_c = 1,    // Input data register index for reg_bank_r
            OUT_REG_IDX_c = 2;   // Output data register index for reg_bank_r

//////////////////////////////////////////////////////////////////////////////////
// Module instantiations
//////////////////////////////////////////////////////////////////////////////////
cipher_engine cphr(
   .clk_i(bus2ip_clk_i),
   .n_rst_i(n_rst_s),
   .ce_i(cphr_en_r),
   .ld_dat_i(bus2ip_dat_i),
   .ld_reg_a_i(ld_reg_a_s),
   .ld_reg_b_i(ld_reg_b_s),
   .dat_i(reg_bank_r[IN_REG_IDX_c][cntr_r]),
   .dat_o(bit_out_s)
);

//////////////////////////////////////////////////////////////////////////////////
// Initial register values
//////////////////////////////////////////////////////////////////////////////////
assign n_rst_s = ~(bus2ip_rst_i | reg_bank_r[CTRL_REG_IDX_c][STOP_BIT_POS_c]);
assign ip2bus_err_o = 1'b0;
initial begin
   cur_state_r = IDLE_e;
   
   // Initialize register bank
   for (i = 0; i < 3; i = i + 1)
      reg_bank_r[0] = 0;
   reg_bank_r[CTRL_REG_IDX_c][READY_BIT_POS_c] = 1'b1;
  
   cntr_r = 0;
   cphr_en_r = 1'b0;
   ld_reg_a_s = 0;
   ld_reg_b_s = 0;
end

//////////////////////////////////////////////////////////////////////////////////
// Manage write acknowledgement and access to key/IV registers
//////////////////////////////////////////////////////////////////////////////////
always @(*) begin
   // Defaults
   ld_reg_a_s = 0;
   ld_reg_b_s = 0;
   ip2bus_wrack_o = 1'b0;

   if (!bus2ip_rnw_i) begin
      case (bus2ip_addr_i)
         CTRL_REG_ADDR_c:
            if (bus2ip_wrce_i[CTRL_REG_ADDR_c] && bus2ip_be_i[0])
               ip2bus_wrack_o = 1'b1;
               
         KEY_REG_0_ADDR_c:
            if (bus2ip_wrce_i[KEY_REG_0_ADDR_c] && cur_state_r == IDLE_e) begin
               ld_reg_a_s[0] = 1'b1;
               ip2bus_wrack_o = 1'b1;
            end
            
         KEY_REG_1_ADDR_c:
            if (bus2ip_wrce_i[KEY_REG_1_ADDR_c] && cur_state_r == IDLE_e) begin
               ld_reg_a_s[1] = 1'b1;
               ip2bus_wrack_o = 1'b1;
            end
            
         KEY_REG_2_ADDR_c:
            if (bus2ip_wrce_i[KEY_REG_2_ADDR_c] && cur_state_r == IDLE_e) begin
               ld_reg_a_s[2] = 1'b1;
               ip2bus_wrack_o = 1'b1;
            end
         
         IV_REG_0_ADDR_c:
            if (bus2ip_wrce_i[IV_REG_0_ADDR_c] && cur_state_r == IDLE_e) begin
               ld_reg_b_s[0] = 1'b1;
               ip2bus_wrack_o = 1'b1;
            end
            
         IV_REG_1_ADDR_c:
            if (bus2ip_wrce_i[IV_REG_1_ADDR_c] && cur_state_r == IDLE_e) begin
               ld_reg_b_s[1] = 1'b1;
               ip2bus_wrack_o = 1'b1;
            end
            
         IV_REG_2_ADDR_c:
            if (bus2ip_wrce_i[IV_REG_2_ADDR_c] && cur_state_r == IDLE_e) begin
               ld_reg_b_s[2] = 1'b1;
               ip2bus_wrack_o = 1'b1;
            end

         IN_REG_ADDR_c:
            if (bus2ip_wrce_i[IN_REG_ADDR_c] && cur_state_r == WAIT_INPUT_e)
               ip2bus_wrack_o = 1'b1;
            
      endcase
   end
end

//////////////////////////////////////////////////////////////////////////////////
// Capture data from write operations
//////////////////////////////////////////////////////////////////////////////////
always @(posedge bus2ip_clk_i or negedge n_rst_s) begin
   if (~n_rst_s) begin
      // Clear registers that are driven in this process
      {reg_bank_r[CTRL_REG_IDX_c][31:16], reg_bank_r[CTRL_REG_IDX_c][7:0]} <= {16'h0000, 16'h0};
      reg_bank_r[IN_REG_IDX_c] <= 0;
   end
   else begin
      // Default values for CTRL register such that the bits are self-clearing
      reg_bank_r[CTRL_REG_IDX_c][7:0] <= 0;
   
      if (!bus2ip_rnw_i) begin
         case (bus2ip_addr_i)
            CTRL_REG_ADDR_c:
               // Allow access to the init and stop bits
               if (bus2ip_wrce_i[CTRL_REG_ADDR_c] && bus2ip_be_i[0]) begin
                  reg_bank_r[CTRL_REG_IDX_c][7:0] <= bus2ip_dat_i[7:0] & 8'h03;
               end
               
            IN_REG_ADDR_c:
               if (bus2ip_wrce_i[IN_REG_ADDR_c] && cur_state_r == WAIT_INPUT_e)
                  reg_bank_r[IN_REG_IDX_c] <= bus2ip_dat_i;

         endcase
      end
   end
end

//////////////////////////////////////////////////////////////////////////////////
// Read operation MUX
//////////////////////////////////////////////////////////////////////////////////
always @(*) begin
   ip2bus_rdack_o = 1'b0;
   ip2bus_dat_o = 0;
   if (bus2ip_rnw_i) begin
      case (bus2ip_addr_i)
         CTRL_REG_ADDR_c:
            if (bus2ip_rdce_i[CTRL_REG_ADDR_c]) begin
               ip2bus_dat_o = reg_bank_r[CTRL_REG_IDX_c];
               ip2bus_rdack_o = 1'b1;
            end
               
         OUT_REG_ADDR_c:
            if (bus2ip_rdce_i[OUT_REG_ADDR_c]) begin
               ip2bus_dat_o = reg_bank_r[OUT_REG_IDX_c];
               ip2bus_rdack_o = 1'b1;
            end
               
      endcase
   end
end

//////////////////////////////////////////////////////////////////////////////////
// Next state logic of the FSM
//////////////////////////////////////////////////////////////////////////////////
always @(*) begin
   case (cur_state_r)
      IDLE_e:
         // Wait until the user initializes the module
         if (reg_bank_r[0][0])
            next_state_s = WARMUP_e;
         else
            next_state_s = IDLE_e;
            
      WARMUP_e:
         // Warm up the cipher
         if (cntr_r == 1151)
            next_state_s = WAIT_INPUT_e;
         else
            next_state_s = WARMUP_e;
            
      WAIT_INPUT_e:
         // Wait until input is being presented
         if (bus2ip_wrce_i[IN_REG_ADDR_c])
            next_state_s = PROC_e;
         else
            next_state_s = WAIT_INPUT_e;
            
      PROC_e:
         // Process all 32 input data bits
         if (cntr_r == 31)
            next_state_s = WAIT_OUTPUT_e;
         else
            next_state_s = PROC_e;
            
      WAIT_OUTPUT_e:
         // Wait until the output is read
         if (bus2ip_rdce_i[OUT_REG_ADDR_c])
            next_state_s = WAIT_INPUT_e;
         else
            next_state_s = WAIT_OUTPUT_e;
            
      default:
         next_state_s = cur_state_r;
   endcase
end

//////////////////////////////////////////////////////////////////////////////////
// State save and output logic of the FSM
//////////////////////////////////////////////////////////////////////////////////
always @(posedge bus2ip_clk_i or negedge n_rst_s) begin
   if (~n_rst_s) begin
      // Reset registers driven here
      cntr_r <= 0;
      cur_state_r <= IDLE_e;
      cphr_en_r <= 1'b0;
      reg_bank_r[CTRL_REG_IDX_c][15:8] <= 0;
      reg_bank_r[CTRL_REG_IDX_c][READY_BIT_POS_c] <= 1'b1;
      reg_bank_r[OUT_REG_IDX_c] <= 0;
   end
   else begin
      // State save logic
      cur_state_r <= next_state_s;
      
      // Output logic
      case (cur_state_r)
         IDLE_e: begin
            if (next_state_s == WARMUP_e) begin
               // Enable cipher and initialize
               cphr_en_r <= 1'b1;
               reg_bank_r[CTRL_REG_IDX_c][READY_BIT_POS_c] <= 1'b0;
            end
         end
         
         WARMUP_e: begin
            if (next_state_s == WAIT_INPUT_e) begin
               cntr_r <= 0;
               cphr_en_r <= 1'b0;
            end
            else begin
               // Increment the warm-up phase counter
               cntr_r <= cntr_r + 1;
            end
         end
         
         WAIT_INPUT_e: begin
            // Wait until data to encrypt/decrypt is being presented
            if (next_state_s == PROC_e)
               cphr_en_r <= 1'b1;
         end
         
         PROC_e: begin
            if (next_state_s == WAIT_OUTPUT_e) begin
               cphr_en_r <= 1'b0;
               cntr_r <= 0;
               reg_bank_r[CTRL_REG_IDX_c][AVAIL_BIT_POS_c] <= 1'b1;
            end
            else
               cntr_r <= cntr_r + 1;
            
            // Shift the output bits into the output register
            reg_bank_r[OUT_REG_IDX_c] <= {bit_out_s, reg_bank_r[OUT_REG_IDX_c][31:1]};
         end
         
         WAIT_OUTPUT_e: begin
            if (next_state_s != WAIT_OUTPUT_e)
               reg_bank_r[CTRL_REG_IDX_c][AVAIL_BIT_POS_c] <= 1'b0;
         end
         
      endcase
   end
end

endmodule
