/* Include Files */
#include "xparameters.h"
#include "xil_printf.h"
#include "xbasic_types.h"
#include "test_data.h"
#include "trivium_helpers.h"

/* Main function */
int main(void) {
    int i, j;
    Xuint32 ct;

    for (i = 0; i < NUM_TESTS; i++) {
        xil_printf("Starting test %d\r\n", i);

        xil_printf("Creating new Trivium instance\r\n");
        if (new_instance(keys[i], ivs[i])) {
            xil_printf("Error creating Trivium instance %d\r\n", i);
            return XST_FAILURE;
        }

        for (j = 0; j < block_sizes[i]; j++) {
            /* Encrypt block and compare to reference CT */
            if (encrypt_word(pt_blocks[i] + j, &ct)) {
                xil_printf("Error encrypting word %d in test %d\r\n", j, i);
                return XST_FAILURE;
            }

            if (ct != ct_blocks[i][j]) {
                xil_printf("Error encrypting word %d in test %d\r\n", j, i);
                return XST_FAILURE;
            }
        }

        xil_printf("Removing Trivium instance\r\n");
        if (delete_instance()) {
            xil_printf("Error deleting Trivium instance %d\r\n", i);
            return XST_FAILURE;
        }
    }

    xil_printf("Tests successfully completed\r\n");
    return XST_SUCCESS;
}

