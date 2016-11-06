#ifndef __AXI_TRIVIUM_H
#define __AXI_TRIVIUM_H

#include <linux/mutex.h>    /* Mutex declaratino */
#include <asm/io.h>         /* ioreadX() and iowriteX() functions */ 

/*******************************************************************************
 * Type declarations
 ******************************************************************************/

/* Represents a user instance of the AXI4-Lite Trivium core */
struct axi_trivium_inst {
    unsigned char   *p_key;     /* Key used in this instance */
    unsigned char   *p_iv;      /* IV used in this instance */
    unsigned char   *p_pt;      /* Plaintext buffer */
    unsigned char   *p_ct;      /* Ciphertext buffer */
    unsigned int    buf_sz;     /* PT/CT buffer size */ 
    unsigned int    ct_idx;     /* Index into CT buffer */
};

/* Information about the IP core */
struct core_info {
    unsigned long       *p_base_addr;   /* Base address of the IP core */
    struct resource     *p_res;         /* Device resource structure */
    unsigned long       remap_sz;       /* Device memory size */  
};

/*******************************************************************************
 * Function declarations
 ******************************************************************************/
static int      axi_trivium_probe(struct platform_device *);
static int      axi_trivium_remove(struct platform_device *);
static void     axi_trivium_shutdown(struct platform_device *);
static int      proc_axi_trivium_open(struct inode *, struct file *);
static int      proc_axi_trivium_close(struct inode *, struct file *);
static ssize_t  proc_axi_trivium_write(struct file *, const char __user *, size_t, loff_t *);
static ssize_t  proc_axi_trivium_read(struct file *, char __user *, size_t, loff_t *);
static int      context_swap(struct core_info *, struct axi_trivium_inst *);
static int      encrypt(struct core_info *, struct axi_trivium_inst *);

/*******************************************************************************
 * Global variables and definitions
 ******************************************************************************/
/* IP core registers */
#define REG_CONFIG  0   /* Configuration register */
#define REG_KEY_LO  1   /* Register for lowest 32 bits of key */
#define REG_KEY_MID 2   /* Register for middle 32 bits of key */
#define REG_KEY_HI  3   /* Register for highest 16 bits of key */
#define REG_IV_LO   4   /* Register for lowest 32 bits of IV */
#define REG_IV_MID  5   /* Register for middle 32 bits of IV */
#define REG_IV_HI   6   /* Register for highest 16 bits of key */
#define REG_DAT_I   7   /* Input data register */
#define REG_DAT_O   8   /* Cipher output data register */

/* Config register bits */
#define REG_CONFIG_BIT_INIT     0   /* Initialize the core after specifying key and IV */
#define REG_CONFIG_BIT_STOP     1   /* Stop the core and reset the instance */
#define REG_CONFIG_BIT_PROC     2   /* Start processing input data */
#define REG_CONFIG_BIT_BUSY     8   /* Read-only bit indicating wheter core is currently busy */
#define REG_CONFIG_BIT_IDONE    9   /* Read-only bit indicating whether initialization phase has completed */
#define REG_CONFIG_BIT_OVAL     10  /* Read-only bit indicateing whether output computation has completed */

/* Inline helper functions to read and write registers */
static inline void reg_wr(struct core_info *p_ip_info, unsigned long reg, unsigned int dat) {
    if (p_ip_info)
        iowrite32(dat, p_ip_info->p_base_addr + reg);
}

static inline unsigned int reg_rd(struct core_info *p_ip_info, unsigned long reg) {
    if (p_ip_info)
        return ioread32(p_ip_info->p_base_addr + reg);

    return 0;
}

static inline void reg_set(struct core_info *p_ip_info, unsigned long reg, unsigned char bit_pos) {
    if (p_ip_info)
        iowrite32(ioread32(p_ip_info->p_base_addr + reg) | (1 << bit_pos), p_ip_info->p_base_addr + reg);
}

static inline void reg_unset(struct core_info *p_ip_info, unsigned long reg, unsigned char bit_pos) {
    if (p_ip_info)
        iowrite32(ioread32(p_ip_info->p_base_addr + reg) & ~(1 << bit_pos), p_ip_info->p_base_addr + reg);
}

static inline unsigned char reg_get(struct core_info *p_ip_info, unsigned long reg, unsigned char bit_pos) {
    if (p_ip_info)
        return (unsigned char)((ioread32(p_ip_info->p_base_addr + reg) & (1 << bit_pos)) >> bit_pos);

    return 0;
}

/* Driver related */
#define DRIVER_NAME     "axi_trivium"   /* Driver name appearing in procfs */
#define KEY_LEN         10              /* Number of key bytes */
#define IV_LEN          10              /* Number of IV bytes */
#define DAT_LEN_MUL     4               /* Data on write must be multiple of this number of bytes */

struct core_info        ip_info;        /* Global IP core info struct */
struct mutex            ip_mtx;         /* Global core mutex */

static const struct file_operations proc_fops = {
    .open = proc_axi_trivium_open,
    .release = proc_axi_trivium_close,
    .write = proc_axi_trivium_write,
    .read = proc_axi_trivium_read
};

#endif