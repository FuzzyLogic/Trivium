#include "trivium_helpers.h"

/* Create a new Trivium instance based on the specified key and IV */
int new_instance(Xuint32 *p_key, Xuint32 *p_iv) {
    if (0 == p_key || 0 == p_iv)
        return XST_FAILURE;

    /* Make sure the core is ready */
    if (1 == REG_GET(REG_CONFIG, BIT_BUSY))
        return XST_FAILURE;

    /* Write key to core */
    REG_WR(REG_KEY_LO, *p_key);
    REG_WR(REG_KEY_MID, *(p_key + 1));
    REG_WR(REG_KEY_HI, *(p_key + 2));

    /* Write IV to core */
    REG_WR(REG_IV_LO, *p_iv);
    REG_WR(REG_IV_MID, *(p_iv + 1));
    REG_WR(REG_IV_HI, *(p_iv + 2));

    /* Initialize the cipher */
    REG_SET(REG_CONFIG, BIT_INIT);

    /* Wait until initialization complete */
    while (0 == REG_GET(REG_CONFIG, BIT_IDONE));

    return XST_SUCCESS;
}

/* Delete the current instance */
int delete_instance() {
    REG_SET(REG_CONFIG, BIT_STOP);
    return XST_SUCCESS;
}

/* Encrypt word and store in specified plaintext buffer */
int encrypt_word(Xuint32 *p_pt, Xuint32 *p_ct) {
    if (0 == p_pt || 0 == p_ct)
        return XST_FAILURE;

    /* Make sure the core is ready */
    if (1 == REG_GET(REG_CONFIG, BIT_BUSY))
        return XST_FAILURE;

    /* Write plaintext to core */
    REG_WR(REG_DAT_I, *p_pt);

    /* Start computation and wait until output valid */
    REG_SET(REG_CONFIG, BIT_PROC);
    while (0 == REG_GET(REG_CONFIG, BIT_OVAL));

    /* Read result into output buffer */
    *p_ct = REG_RD(REG_DAT_O);

    return XST_SUCCESS;
}

