#ifndef SRC_TRIVIUM_HELPERS_H_
#define SRC_TRIVIUM_HELPERS_H_

#include "xbasic_types.h"
#include "xstatus.h"
#include "xbasic_types.h"

/* Trivium related definitions */
#define REG_CONFIG  0
#define REG_KEY_LO  1
#define REG_KEY_MID 2
#define REG_KEY_HI  3
#define REG_IV_LO   4
#define REG_IV_MID  5
#define REG_IV_HI   6
#define REG_DAT_I   7
#define REG_DAT_O   8

#define BASE_ADDR   ((Xuint32*)0x43C00000)

#define BIT_INIT    0
#define BIT_STOP    1
#define BIT_PROC    2
#define BIT_OVAL    8
#define BIT_READY   9

/* Helper macros */
#define REG_WR(IDX, DAT)    (*(BASE_ADDR + IDX) = DAT)
#define REG_RD(IDX)         (*(BASE_ADDR + IDX))
#define REG_SET(IDX, BIT)   (*(BASE_ADDR + IDX) |= 1 << BIT)
#define REG_USET(IDX_BIT)   (*(BASE_ADDR + IDX) &= ~(1 << BIT))
#define REG_GET(IDX, BIT)   ((*(BASE_ADDR + IDX) & (1 << BIT)) >> BIT)

/* Trivium related helper function declarations */
int new_instance(Xuint32 *p_key, Xuint32 *p_iv);
int delete_instance();
int encrypt_word(Xuint32 *p_pt, Xuint32 *p_ct);

#endif /* SRC_TRIVIUM_HELPERS_H_ */
