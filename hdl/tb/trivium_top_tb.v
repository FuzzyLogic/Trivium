////////////////////////////////////////////////////////////////////////////////
// Engineer:      Christian P. Feist
//
// Create Date:   16:33:45 05/05/2016
// Design Name:   trivium_top
// Module Name:   /home/chris/Documents/FPGA/Work/Trivium/hdl/tb/trivium_top_tb.v
// Project Name:  Trivium
// Target Device: Spartan-6  
// Tool versions: ISE 14.7
// Description:   The module trivium_top is tested using reference I/O files. Each
//                test incorporates the pre-loading with a new key and IV, as well
//                as providing input words and checking the correctness of the
//                encrypted output words.
//
// Verilog Test Fixture created by ISE for module: trivium_top
//
// Dependencies:  /
// 
// Revision:
// Revision 0.01 - File Created
// 
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
module trivium_top_tb;

////////////////////////////////////////////////////////////////////////////////
// Helper function definitions
////////////////////////////////////////////////////////////////////////////////

// Get the number of tests contained in a specified file
function [31:0] get_num_tests;
   input [8*20:1] i_file_name;
   reg [8*20:1] cur_line;
   integer cur_num;
   integer fd;
begin
   cur_num = 0;
   fd = $fopen(i_file_name, "r");
   if (!fd) begin
      $display("ERROR: Could not open '%s'", i_file_name);
      get_num_tests = 0;
   end
   else begin
      // Iterate over lines
      while ($fscanf(fd, "%s", cur_line)) begin
         if (cur_line == "-")
            cur_num = cur_num + 1;
      end
      
      $fclose(fd);
      get_num_tests = cur_num;
   end
end
endfunction

// Returns the key or IV of a particular test
function [79:0] get_key_iv;
   input [8*20:1] i_file_name;
   input [8*3:1] key_or_iv;
   input [31:0] test_num;
   reg [8*20:1] cur_line;
   reg [79:0] ret_val;
   integer cur_num;
   integer fd;
begin
   cur_num = 0;
   fd = $fopen(i_file_name, "r");
   if (!fd) begin
      $display("ERROR: Could not open '%s'", i_file_name);
      $finish;
   end
   else begin
      // Iterate until specified test is found
      while (cur_num < test_num && $fscanf(fd, "%s", cur_line)) begin
         if (cur_line == "-")
            cur_num = cur_num + 1;
      end
      
      if (cur_line == ".") begin
         $display("ERROR: Incorrect test number specified: %d", test_num);
         $fclose(fd);
         $finish;
      end
      
      // Get key or IV and return
      if (key_or_iv == "key")
         $fscanf(fd, "%h", ret_val);
      else if (key_or_iv == "iv") begin
         $fscanf(fd, "%h", ret_val);
         $fscanf(fd, "%h", ret_val);
      end
      else begin
         $display("ERROR: Could not read requested value!");
         $fclose(fd);
         $finish;
      end
      
      $fclose(fd);
      get_key_iv = ret_val;
   end
end 
endfunction

// Return the number of 32-bit words in specified test
function [31:0] get_num_words;
   input [8*20:1] i_file_name;
   input integer line_num;
   input integer test_num;
   reg [8*20:1] cur_line;
   integer cur_num;
   integer fd;
begin
   cur_num = 0;
   fd = $fopen(i_file_name, "r");
   if (!fd) begin
      $display("ERROR: Could not open '%s'", i_file_name);
      $finish;
   end
   else begin
      // Iterate until specified test is found
      while (cur_num < test_num && $fscanf(fd, "%s", cur_line)) begin
         if (cur_line == "-")
            cur_num = cur_num + 1;
      end
      
      if (cur_line == ".") begin
         $display("ERROR: Incorrect test number specified: %d", test_num);
         $fclose(fd);
         $finish;
      end
      
      // Skip the key and IV in case we are reading from input reference
      if (i_file_name == "trivium_ref_in.txt") begin
         $fscanf(fd, "%s", cur_line);
         $fscanf(fd, "%s", cur_line);
      end
      
      // Counter number of words in current test
      cur_num = 0;
      cur_line = "";
      $fscanf(fd, "%s", cur_line);
      while (cur_line != "-") begin
         cur_num = cur_num + 1;
         $fscanf(fd, "%s", cur_line);
      end
      
      $fclose(fd);
      get_num_words = cur_num;
   end
end 
endfunction

// Return 32-bit word from specified file
function [31:0] get_word;
   input [8*20:1] i_file_name;
   input integer line_num;
   input integer test_num;
   reg [8*20:1] cur_line;
   reg [79:0] cur_word;
   integer cur_num;
   integer fd;
begin
   cur_num = 0;
   fd = $fopen(i_file_name, "r");
   if (!fd) begin
      $display("ERROR: Could not open '%s'", i_file_name);
      $finish;
   end
   else begin
      // Iterate until specified test is found
      while (cur_num < test_num && $fscanf(fd, "%s", cur_line)) begin
         if (cur_line == "-")
            cur_num = cur_num + 1;
      end
      
      if (cur_line == ".") begin
         $display("ERROR: Incorrect test number specified: %d", test_num);
         $fclose(fd);
         $finish;
      end
      
      // Skip the key and IV in case we are reading from input reference
      if (i_file_name == "trivium_ref_in.txt") begin
         $fscanf(fd, "%h", cur_word);
         $fscanf(fd, "%h", cur_word);
      end
      
      // Skip to specified word
      cur_num = 0;
      $fscanf(fd, "%h", cur_word);
      while (cur_num < line_num && $fscanf(fd, "%h", cur_word))
         cur_num = cur_num + 1;
      
      $fclose(fd);
      get_word = cur_word[31:0];
   end
end 
endfunction

////////////////////////////////////////////////////////////////////////////////
// Signal definitions
////////////////////////////////////////////////////////////////////////////////

// Inputs
reg bus2ip_clk_i;
reg bus2ip_rst_i;
reg [3:0] bus2ip_addr_i;
reg bus2ip_rnw_i;
reg [31:0] bus2ip_dat_i;
reg [3:0] bus2ip_be_i;
reg [8:0] bus2ip_rdce_i;
reg [8:0] bus2ip_wrce_i;

// Outputs
wire [31:0] ip2bus_dat_o;
wire ip2bus_rdack_o;
wire ip2bus_wrack_o;
wire ip2bus_err_o;

// Other signals
reg start_tests_s;      // Flag indicating the start of the tests
reg [79:0] key_r;       // Key used for encryption
reg [79:0] iv_r;        // IV used for encryption
integer instr_v;        // Current stimulus instruction index
integer dat_cntr_v;     // Data counter variable
integer cur_test_v;     // Index of current test

////////////////////////////////////////////////////////////////////////////////
// UUT Instantiation
////////////////////////////////////////////////////////////////////////////////
trivium_top uut(
   .bus2ip_clk_i(bus2ip_clk_i), 
   .bus2ip_rst_i(bus2ip_rst_i), 
   .bus2ip_addr_i(bus2ip_addr_i), 
   .bus2ip_rnw_i(bus2ip_rnw_i), 
   .bus2ip_dat_i(bus2ip_dat_i), 
   .bus2ip_be_i(bus2ip_be_i), 
   .bus2ip_rdce_i(bus2ip_rdce_i), 
   .bus2ip_wrce_i(bus2ip_wrce_i), 
   .ip2bus_dat_o(ip2bus_dat_o), 
   .ip2bus_rdack_o(ip2bus_rdack_o), 
   .ip2bus_wrack_o(ip2bus_wrack_o), 
   .ip2bus_err_o(ip2bus_err_o)
);

////////////////////////////////////////////////////////////////////////////////
// UUT Initialization
////////////////////////////////////////////////////////////////////////////////
initial begin
   // Initialize Inputs
   bus2ip_clk_i = 0;
   bus2ip_rst_i = 1'b1;
   bus2ip_addr_i = 0;
   bus2ip_rnw_i = 0;
   bus2ip_dat_i = 0;
   bus2ip_be_i = 0;
   bus2ip_rdce_i = 0;
   bus2ip_wrce_i = 0;
   
   // Initialize other signals/variables
   start_tests_s = 0;
   instr_v = 0;
   dat_cntr_v = 0;
   cur_test_v = 0;

   // Wait 100 ns for global reset to finish
   #100;
   bus2ip_rst_i = 0;
   start_tests_s = 1'b1;
end

////////////////////////////////////////////////////////////////////////////////
// Clock generation
////////////////////////////////////////////////////////////////////////////////
always begin
   #10 bus2ip_clk_i = ~bus2ip_clk_i;
end

////////////////////////////////////////////////////////////////////////////////
// Stimulus process
////////////////////////////////////////////////////////////////////////////////
always @(posedge bus2ip_clk_i or posedge bus2ip_rst_i) begin
   if (bus2ip_rst_i) begin
      // Reset registers driven here
      bus2ip_rnw_i <= 1'b0;
      bus2ip_addr_i <= 0;
      bus2ip_rdce_i <= 0;
      bus2ip_wrce_i <= 0;
      bus2ip_dat_i <= 0;
      bus2ip_be_i <= 0;
      instr_v = 0;
      dat_cntr_v = 0;
   end
   else if (start_tests_s) begin
      case (instr_v)
         0: begin // Instruction 0: Check if core is ready
            bus2ip_rnw_i <= 1'b1;
            if (!bus2ip_rdce_i[CTRL_REG_ADDR_c]) begin
               bus2ip_addr_i <= CTRL_REG_ADDR_c;
               bus2ip_rdce_i[CTRL_REG_ADDR_c] <= 1'b1;
            end
            else if(ip2bus_rdack_o) begin
               // Core should be ready
               if (!ip2bus_dat_o[9]) begin
                  $display("ERROR: Test (Core ready) failed!");
                  $finish;
               end

               // Get the current key and IV
               key_r = get_key_iv("trivium_ref_in.txt", "key", cur_test_v);
               iv_r = get_key_iv("trivium_ref_in.txt", "iv", cur_test_v);

               bus2ip_rdce_i[CTRL_REG_ADDR_c] <= 1'b0;
               instr_v = instr_v + 1;
            end
         end
         
         1: begin // Instruction 1: Write key to core
            bus2ip_rnw_i <= 1'b0;
            
            if (dat_cntr_v < 3) begin
               if (!bus2ip_wrce_i[KEY_REG_0_ADDR_c + dat_cntr_v]) begin
                  bus2ip_addr_i <= KEY_REG_0_ADDR_c + dat_cntr_v;
                  bus2ip_wrce_i[KEY_REG_0_ADDR_c + dat_cntr_v] <= 1'b1;

                  bus2ip_dat_i <= key_r[(dat_cntr_v*32)+:32];
               end
               else if(ip2bus_wrack_o) begin
                  bus2ip_wrce_i[KEY_REG_0_ADDR_c + dat_cntr_v] <= 1'b0;
                  dat_cntr_v = dat_cntr_v + 1;
               end
            end
            else begin
               dat_cntr_v = 0;
               instr_v = instr_v + 1;
            end
         end
         
         2: begin // Instruction 2: Write IV to core
            bus2ip_rnw_i <= 1'b0;
            
            if (dat_cntr_v < 3) begin
               if (!bus2ip_wrce_i[IV_REG_0_ADDR_c + dat_cntr_v]) begin
                  bus2ip_addr_i <= IV_REG_0_ADDR_c + dat_cntr_v;
                  bus2ip_wrce_i[IV_REG_0_ADDR_c + dat_cntr_v] <= 1'b1;
                  
                  bus2ip_dat_i <= iv_r[(dat_cntr_v*32)+:32];
               end
               else if(ip2bus_wrack_o) begin
                  bus2ip_wrce_i[IV_REG_0_ADDR_c + dat_cntr_v] <= 1'b0;
                  dat_cntr_v = dat_cntr_v + 1;
               end
            end
            else begin
               dat_cntr_v = 0;
               instr_v = instr_v + 1;
            end
         end
         
         3: begin // Instruction 3: Initialize the cipher
            if (!bus2ip_wrce_i[CTRL_REG_ADDR_c]) begin
               bus2ip_addr_i <= CTRL_REG_ADDR_c;
               bus2ip_wrce_i[CTRL_REG_ADDR_c] <= 1'b1;
               bus2ip_be_i[0] <= 1'b1;
               
               bus2ip_dat_i <= 32'h00000001;
            end
            else if(ip2bus_wrack_o) begin
               bus2ip_wrce_i[CTRL_REG_ADDR_c] <= 1'b0;
               bus2ip_be_i[0] <= 1'b0;
               instr_v = instr_v + 1;
            end
         end
         
         4: begin // Instruction 4: Present a 32-bit value to encrypt
            bus2ip_rnw_i <= 1'b0;
            if (!bus2ip_wrce_i[IN_REG_ADDR_c]) begin
               bus2ip_addr_i <= IN_REG_ADDR_c;
               bus2ip_wrce_i[IN_REG_ADDR_c] <= 1'b1;
               
               bus2ip_dat_i <= get_word("trivium_ref_in.txt", dat_cntr_v, cur_test_v);
            end
            else if(ip2bus_wrack_o) begin
               bus2ip_wrce_i[IN_REG_ADDR_c] <= 1'b0;
               instr_v = instr_v + 1;
            end
         end
         
         5: begin // Instruction 5: Poll device until data available
            bus2ip_rnw_i <= 1'b1;
            if (!bus2ip_rdce_i[CTRL_REG_ADDR_c]) begin
               bus2ip_addr_i <= CTRL_REG_ADDR_c;
               bus2ip_rdce_i[CTRL_REG_ADDR_c] <= 1'b1;
            end
            else if(ip2bus_rdack_o) begin
               // Check if data available
               if (ip2bus_dat_o[8])
                  instr_v = instr_v + 1;

               bus2ip_rdce_i[CTRL_REG_ADDR_c] <= 1'b0;
            end
         end
         
         6: begin // Instruction 6: Get ciphertext from device
            bus2ip_rnw_i <= 1'b1;
            if (!bus2ip_rdce_i[OUT_REG_ADDR_c]) begin
               bus2ip_addr_i <= OUT_REG_ADDR_c;
               bus2ip_rdce_i[OUT_REG_ADDR_c] <= 1'b1;
            end
            else if(ip2bus_rdack_o) begin
               // Compare received ciphertext to reference
               if (ip2bus_dat_o != get_word("trivium_ref_out.txt", dat_cntr_v, cur_test_v)) begin
                  $display("ERROR: Incorrect output in test %d, word %d!", cur_test_v, dat_cntr_v);
                  $display("%04x != %04x, input = %04x", ip2bus_dat_o, get_word("trivium_ref_out.txt", dat_cntr_v, cur_test_v), get_word("trivium_ref_in.txt", dat_cntr_v, cur_test_v));
                  $finish;
               end
               
               // Check if there is more data to encrypt in current test
               if (dat_cntr_v < get_num_words("trivium_ref_in.txt", dat_cntr_v, cur_test_v) - 1) begin
                  dat_cntr_v = dat_cntr_v + 1;
                  instr_v = 4;
               end
               else begin
                  dat_cntr_v = 0;
                  instr_v = instr_v + 1;
               end
               bus2ip_rdce_i[OUT_REG_ADDR_c] <= 1'b0;
            end
         end
         
         7: begin // Instruction 7: Reset the core
            bus2ip_rnw_i <= 1'b0;
            if (!bus2ip_wrce_i[CTRL_REG_ADDR_c]) begin
               bus2ip_addr_i <= CTRL_REG_ADDR_c;
               bus2ip_wrce_i[CTRL_REG_ADDR_c] <= 1'b1;
               bus2ip_be_i[0] <= 1'b1;

               bus2ip_dat_i <= 0;
               bus2ip_dat_i[STOP_BIT_POS_c] <= 1'b1;
            end
            else if(ip2bus_wrack_o) begin
               bus2ip_wrce_i[CTRL_REG_ADDR_c] <= 1'b0;
               bus2ip_be_i[0] <= 1'b0;
               instr_v = instr_v + 1;
            end

         end
         
         8: begin // Instruction 8: Check if all tests completed and decide what to do
            if (cur_test_v < get_num_tests("trivium_ref_in.txt") - 1) begin
               cur_test_v = cur_test_v + 1;
               instr_v = 0;
            end
            else begin
               cur_test_v = 0;
               instr_v = instr_v + 1;
            end
         end
         
         default: begin
            $display("Tests successfully completed!");
            $finish;
         end
      endcase
   end
end
      
endmodule
