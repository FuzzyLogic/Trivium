#include <linux/kernel.h>           /* Basic kernel related functionality */
#include <linux/module.h>           /* KLM related functions for setup and management */
#include <linux/proc_fs.h>          /* Managing /proc entry */
#include <linux/platform_device.h>  /* Platform_device struct and related functions */
#include <linux/errno.h>            /* Linux error codes */
#include <linux/slab.h>             /* kzfree() */
#include <asm/io.h>                 /* ioremap and co. */
#include <asm/uaccess.h>            /* copy_from_user() and copy_to_user() */
#include "axi_trivium.h"            /* Type declarations and variable definitions */

/*******************************************************************************
 * Platform driver specific function
 ******************************************************************************/
/*
 * axi_trivium_probe - Map device and create /proc entry
 *
 * @p_dev: Platform device structure derived from device tree
 *
 * Returns 0 on success, error code otherwise
 *
 * Additional info: Note that this driver does not manage a hot-pluggable device
 * or multiple instances of a device. It is therefore possible to implement all
 * global related setup tasks (e.g. initializing a mutex) in the probe function
 * as it will only be called once.
 */
static int axi_trivium_probe(struct platform_device *p_dev) {
    struct proc_dir_entry *p_proc_entry;
    int ret_val = 0;

    /* Initialize mutex */
    mutex_init(&ip_mtx);

    /* Get resource information for device */
    ip_info.p_res = platform_get_resource(p_dev, IORESOURCE_MEM, 0);
    if (!ip_info.p_res) {
        dev_err(&p_dev->dev, "No memory resource information available\n");
        return -ENODEV;
    }

    /* Get memory size for ioremap and request memory region for mapping */
    ip_info.remap_sz = ip_info.p_res->end - ip_info.p_res->start + 1; 
    if (!request_mem_region(ip_info.p_res->start, ip_info.remap_sz, p_dev->name)) {
        dev_err(&p_dev->dev, "Could not setup memory region for remap\n");
        return -ENXIO;
    }

    /* Map the physical MMIO space of the core to virtual kernel space memory */
    ip_info.p_base_addr = ioremap(ip_info.p_res->start, ip_info.remap_sz);
    if (ip_info.p_base_addr == NULL) {
        dev_err(&p_dev->dev, "Could not ioremap MMIO at 0x%08lx\n", (unsigned long)ip_info.p_res->start);
        ret_val = -ENOMEM;
        goto err_ioremap;
    }

    /* Create entry in /proc for device */
    p_proc_entry = proc_create(DRIVER_NAME, 0, NULL, &proc_fops);
    if (p_proc_entry == NULL) {
        dev_err(&p_dev->dev, "Could not create /proc entry\n");
        ret_val = -ENOMEM;
        goto err_proc_entry;   
    }

    return 0;

/* Error cases */
err_proc_entry:
    iounmap(ip_info.p_base_addr);
err_ioremap:
    release_mem_region(ip_info.p_res->start, ip_info.remap_sz);

    return ret_val;
}

/*
 * axi_trivium_remove - Called when the device is removed
 *
 * @p_dev: Platform device structure derived from device tree
 *
 * Returns 0 on success, error code otherwise
 */
static int axi_trivium_remove(struct platform_device *p_dev) {
    iounmap(ip_info.p_base_addr);
    release_mem_region(ip_info.p_res->start, ip_info.remap_sz);
    return 0;
}

/*
 * axi_trivium_shutdown - Function to shut down the device (simply reset it)
 *
 * @p_dev: Platform device structure derived from device tree
 */
static void axi_trivium_shutdown(struct platform_device *p_dev) {
    reg_set(&ip_info, REG_CONFIG, REG_CONFIG_BIT_STOP);
}

/*******************************************************************************
 * File operation handlers
 ******************************************************************************/

/*
 * proc_axi_trivium_open - Handler for open operation on /proc entry
 *
 * @p_node - File inode (unused here)
 * @p_file - File pointer
 *
 * Return 0 if successful, error code otherwise
 */
static int proc_axi_trivium_open(struct inode *p_node, struct file *p_file) {
    /* Create a new software instance */
    struct axi_trivium_inst *p_inst = (struct axi_trivium_inst *)kzalloc(sizeof(struct axi_trivium_inst), GFP_KERNEL);
    if (!p_inst)
        return -ENOMEM;

    /* Store instance */
    p_file->private_data = p_inst;

    return 0;
}

/*
 * proc_axi_trivium_close - Handler for close operation on /proc entry
 *
 * @p_node - File inode (unused here)
 * @p_file - File pointer
 *
 * Return 0 if successful, error code otherwise
 */
static int proc_axi_trivium_close(struct inode *p_node, struct file *p_file) {
    /* Remove current software instance */
    struct axi_trivium_inst *p_inst = (struct axi_trivium_inst *)p_file->private_data;
    if (p_inst) {
        /* Free any allocated buffers */
        if (p_inst->p_key)
            kzfree(p_inst->p_key);

        if (p_inst->p_iv)
            kzfree(p_inst->p_iv);

        if (p_inst->p_pt)
            kzfree(p_inst->p_pt);

        if (p_inst->p_ct)
            kzfree(p_inst->p_ct);

        kzfree(p_inst);
    }

    p_file->private_data = NULL;
    return 0;
}

/*
 * proc_axi_trivium_write - Handler for write operation on /proc entry
 *
 * @p_file - File pointer
 * @p_buf - Input buffer from user-space
 * @sz - Number of bytes to write
 * @p_off - Pointer to an offset value into the file (not used here)
 *
 * Return 0 if successful, error code otherwise
 *
 * Additional information:
 *  - First set of writes are for key and IV
 *  - Any subsequent writes for an instance are regarded as encryption requests
 *  - The encryption result can be read using the read operation on the /proc file
 */
static ssize_t proc_axi_trivium_write(struct file *p_file, const char __user *p_buf, size_t sz, loff_t *p_off) {
    struct axi_trivium_inst *p_inst = (struct axi_trivium_inst *)p_file->private_data;
    int ret_val = 0;

    if (!p_inst->p_key) {
        /* Key data expected, check format */
        if (sz != KEY_LEN)
            return -ENOEXEC;

        /* Make sure a multiple of 32 bit is allocated for writing to registers */
        p_inst->p_key = (unsigned char *)kzalloc((sz/3)*sizeof(unsigned int), GFP_KERNEL);
        if (!p_inst->p_key)
            return -ENOMEM;

        /* Copy key data from user buffer to instance */
        if (copy_from_user(p_inst->p_key, p_buf, sz))
            return -EFAULT;
    } else if (!p_inst->p_iv) {
        /* IV data expected, check format */
        if (sz != IV_LEN)
            return -ENOEXEC;

        /* Make sure a multiple of 32 bit is allocated for writing to registers */
        p_inst->p_iv = (unsigned char *)kzalloc((sz/3)*sizeof(unsigned int), GFP_KERNEL);
        if (!p_inst->p_iv)
            return -ENOMEM;

        /* Copy IV from user buffer to instance */
        if (copy_from_user(p_inst->p_iv, p_buf, sz))
            return -EFAULT;
    } else {
        /* Plaintext data is expected to be multiple of input register size */
        if (sz%DAT_LEN_MUL)
            return -ENOEXEC;

        /* Allocate buffers, note that unread CT data will be lost */
        p_inst->p_pt = (unsigned char *)kzalloc(sz*sizeof(unsigned char), GFP_KERNEL);

        if (p_inst->p_ct) {
            kzfree(p_inst->p_ct);
            p_inst->p_ct = NULL;
            p_inst->ct_idx = 0;
        }

        p_inst->p_ct = (unsigned char *)kzalloc(sz*sizeof(unsigned char), GFP_KERNEL);
        p_inst->buf_sz = sz;

        if (copy_from_user(p_inst->p_pt, p_buf, sz))
            return -EFAULT;

        /* This case denotes the actual encryption request, obtain access to IP */
        mutex_lock(&ip_mtx);
        ret_val = context_swap(&ip_info, p_inst);
        if (ret_val)
            return ret_val;

        ret_val = encrypt(&ip_info, p_inst);
        if (ret_val)
            return ret_val;

        /* Free the IP for other processes */
        mutex_unlock(&ip_mtx);
        kzfree(p_inst->p_pt);
        p_inst->p_pt = NULL;
    }

    return sz;
}

/*
 * proc_axi_trivium_read - Handler for read operation on /proc entry
 *
 * @p_file - File pointer
 * @p_buf - Output buffer to user-space
 * @sz - Number of bytes to read
 * @p_off - Pointer to an offset value into the file (not used here)
 *
 * Return 0 if successful, error code otherwise
 *
 * Additional information:
 *  - Keep track of number of bytes read from CT buffer
 *  - Free the buffer once everything has been read
 */
static ssize_t proc_axi_trivium_read(struct file *p_file, char __user *p_buf, size_t sz, loff_t *p_off) {
    struct axi_trivium_inst *p_inst = (struct axi_trivium_inst *)p_file->private_data;

    /* Check if requested read is possible */
    if (sz > p_inst->buf_sz - p_inst->ct_idx || !p_inst->p_ct)
        return -ENOEXEC;

    /* Copy requested number of bytes*/
    if (copy_to_user(p_buf, p_inst->p_ct + p_inst->ct_idx, sz))
        return -EFAULT;

    /* Update index and clear buffer if everything has been read */
    p_inst->ct_idx += sz;
    if (p_inst->ct_idx == p_inst->buf_sz) {
        kzfree(p_inst->p_ct);
        p_inst->p_ct = NULL;
        p_inst->ct_idx = 0;
    }

    return sz;
}

/*******************************************************************************
 * Trivium specific functions
 ******************************************************************************/

/*
 * context_swap - Swap the current instance in hardware with a specified one
 *
 * @p_ip_info: IP core information
 * @p_new_inst: Data for new Trivium instance
 *
 * Return 0 on success, error code otherwise
 *
 * Additional information: This function should only be called if the mutex
 * for the IP core has been acquired.
 */
static int context_swap(struct core_info *p_ip_info, struct axi_trivium_inst *p_new_inst) {
    /* Make sure everything required is present */
    if (!p_ip_info || !p_new_inst)
        return -EINVAL;
    else {
        if (!p_new_inst->p_key || !p_new_inst->p_iv)
            return -EINVAL;
    }

    /* Stop the core */
    reg_set(p_ip_info, REG_CONFIG, REG_CONFIG_BIT_STOP);

    /* Check if core is ready */
    if (1 == reg_get(p_ip_info, REG_CONFIG, REG_CONFIG_BIT_BUSY))
        return -EIO;

    /* Set key and IV */
    reg_wr(p_ip_info, REG_KEY_LO, *((unsigned int *)(p_new_inst->p_key)));
    reg_wr(p_ip_info, REG_KEY_MID, *((unsigned int *)(p_new_inst->p_key) + 1));
    reg_wr(p_ip_info, REG_KEY_HI, *((unsigned int *)(p_new_inst->p_key) + 2));

    reg_wr(p_ip_info, REG_IV_LO, *((unsigned int *)(p_new_inst->p_iv)));
    reg_wr(p_ip_info, REG_IV_MID, *((unsigned int *)(p_new_inst->p_iv) + 1));
    reg_wr(p_ip_info, REG_IV_HI, *((unsigned int *)(p_new_inst->p_iv) + 2));

    /* Initialize and wait for completion */
    reg_set(p_ip_info, REG_CONFIG, REG_CONFIG_BIT_INIT);
    while (0 == reg_get(p_ip_info, REG_CONFIG, REG_CONFIG_BIT_IDONE));

    return 0;
}

/*
 * encrypt - Encrypt current plaintext buffer
 *
 * @p_ip_info: IP core information
 * @p_inst: Data for Trivium instance, include plaintext buffer
 *
 * Return 0 on success, error code otherwise
 *
 * Additional information: This function should only be called if the mutex
 * for the IP core has been acquired and the context has been switched.
 */
static int encrypt(struct core_info *p_ip_info, struct axi_trivium_inst *p_inst) {
    int i;

    /* Make sure everything required is present */
    if (!p_ip_info || !p_inst)
        return -EINVAL;
    else {
        if (!p_inst->p_pt || !p_inst->p_ct)
            return -EINVAL;
    }

    /* Encrypt word for word */
    for (i = 0; i < (p_inst->buf_sz)/DAT_LEN_MUL; i++) {
        /* Make sure the core is ready */
        if (1 == reg_get(p_ip_info, REG_CONFIG, REG_CONFIG_BIT_BUSY))
            return -EIO;

        /* Write plaintext to core */
        reg_wr(p_ip_info, REG_DAT_I, *(((unsigned int *)p_inst->p_pt) + i));

        /* Start computation and wait until output valid */
        reg_set(p_ip_info, REG_CONFIG, REG_CONFIG_BIT_PROC);
        while (0 == reg_get(p_ip_info, REG_CONFIG, REG_CONFIG_BIT_OVAL));

        /* Read result into output buffer */
        *(((unsigned int *)p_inst->p_ct) + i) = reg_rd(p_ip_info, REG_DAT_O);
    }

    return 0;
}

/*******************************************************************************
 * Driver registration and information
 ******************************************************************************/
/* Table used to match this driver with an entry in the device tree */
static const struct of_device_id axi_trivium_of_match[] = {
    {.compatible = "fuzzylogic,axi_trivium_1.0"},
    {}
};

MODULE_DEVICE_TABLE(of, axi_trivium_of_match);

/* Platform driver structure for the AXI4-Lite Trivium core */
static struct platform_driver axi_trivium_driver = {
    .driver = {
        .name = DRIVER_NAME,
        .owner = THIS_MODULE,
        .of_match_table = axi_trivium_of_match
    },
    .probe = axi_trivium_probe,
    .remove = axi_trivium_remove,
    .shutdown = axi_trivium_shutdown
};

/* Register the platform driver with the kernel */
module_platform_driver(axi_trivium_driver);

/* Module information */
MODULE_AUTHOR("Christian P. Feist (aka FuzzyLogic)");
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION(DRIVER_NAME ": AXI4-Lite Trivium IP core driver");
MODULE_ALIAS(DRIVER_NAME);