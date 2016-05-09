//////////////////////////////////////////////////////////////////////////////////
// Engineer:         Christian P. Feist
// 
// Create Date:      17:51:20 05/06/2016 
// Design Name:      /
// Module Name:      trivium_globals 
// Project Name:     Trivium
// Target Devices:   Spartan-6
// Tool versions:    ISE 14.7
// Description:      Global parameters describing the addresses of the module's registers
//                   as well as parameters describing important bit indices in certain
//                   registers.
//
// Dependencies:     /
//
// Revision: 
// Revision 0.01 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

parameter   CTRL_REG_ADDR_c = 0,       // Control register address
            KEY_REG_0_ADDR_c = 1,      // Key register part 0 address
            KEY_REG_1_ADDR_c = 2,      // Key register part 1 address
            KEY_REG_2_ADDR_c = 3,      // Key register part 2 address
            IV_REG_0_ADDR_c = 4,       // IV register part 0 address
            IV_REG_1_ADDR_c = 5,       // IV register part 1 address
            IV_REG_2_ADDR_c = 6,       // IV register part 2 address
            IN_REG_ADDR_c = 7,         // Input data register address
            OUT_REG_ADDR_c = 8;        // Output data register address
            
parameter   INIT_BIT_POS_c = 0,        // Position of the INIT bit in the CTRL register
            STOP_BIT_POS_c = 1,        // Position of the STOP bit in the CTRL register
            AVAIL_BIT_POS_c = 8,       // Position of the AVAIL bit in the CTRL register
            READY_BIT_POS_c = 9;       // Position of the READY bit in the CTRL register