#include "nvs_dtc_storage.h"
#include <zephyr/storage/flash_map.h>
#include <zephyr/fs/nvs.h>
#include <zephyr/device.h>
#include <zephyr/kernel.h>
#include <zephyr/drivers/flash.h>
#include <string.h>

static struct nvs_fs fs;
static bool nvs_available = false;

void nvs_init(void)
{
    int rc;
    struct flash_pages_info info;

#if DT_NODE_EXISTS(DT_NODELABEL(storage_partition))
    /* Try to use storage_partition if it exists */
    printk("Using storage_partition from device tree\n");
    
    fs.flash_device = FIXED_PARTITION_DEVICE(storage_partition);
    
    if (!device_is_ready(fs.flash_device)) {
        printk("Flash device not ready\n");
        return;
    }

    fs.offset = FIXED_PARTITION_OFFSET(storage_partition);
#else
    /* Fallback: Use last 64KB of flash manually */
    printk("No storage_partition found, using manual flash configuration\n");
    
    /* Get the flash controller device */
    const struct device *flash_dev = DEVICE_DT_GET(DT_CHOSEN(zephyr_flash));
    
    if (!device_is_ready(flash_dev)) {
        printk("Flash device not ready\n");
        return;
    }
    
    fs.flash_device = flash_dev;
    
    /* FRDM-K64F has 1MB (0x100000) flash, use last 64KB for storage */
    fs.offset = 0x000F0000;  /* Start at 960KB offset */
#endif
    
    /* Get flash page info */
    rc = flash_get_page_info_by_offs(fs.flash_device, fs.offset, &info);
    if (rc) {
        printk("Unable to get flash page info: %d\n", rc);
        /* Try with default sector size */
        fs.sector_size = 4096;
        printk("Using default sector size: %u\n", fs.sector_size);
    } else {
        fs.sector_size = info.size;
    }
    
    fs.sector_count = 4U;  /* Use 4 sectors */

    /* Mount NVS */
    rc = nvs_mount(&fs);
    if (rc) {
        printk("NVS mount failed: %d\n", rc);
        printk("Note: This is normal on first boot - NVS will be initialized\n");
        /* Try to initialize */
        rc = nvs_clear(&fs);
        if (rc) {
            printk("NVS clear failed: %d\n", rc);
            return;
        }
        rc = nvs_mount(&fs);
        if (rc) {
            printk("NVS mount still failed after clear: %d\n", rc);
            return;
        }
    }
    
    nvs_available = true;
    printk("NVS initialized successfully\n");
    printk("  Flash device: %s\n", fs.flash_device->name);
    printk("  Offset: 0x%lx\n", (unsigned long)fs.offset);
    printk("  Sector size: %u bytes\n", fs.sector_size);
    printk("  Sector count: %u\n", fs.sector_count);
    printk("  Total size: %u bytes\n", fs.sector_size * fs.sector_count);
}

void nvs_save_dtc(bool *dtc_table, size_t len)
{
    if (!nvs_available) {
        printk("NVS not available, skipping save\n");
        return;
    }
    
    /* Save entire DTC table in one write */
    int rc = nvs_write(&fs, 1, dtc_table, len);
    if (rc < 0) {
        printk("NVS write failed: %d\n", rc);
    } else {
        printk("NVS: Saved %zu bytes of DTC data\n", len);
    }
}

void nvs_load_dtc(bool *dtc_table, size_t len)
{
    if (!nvs_available) {
        printk("NVS not available, initializing DTC table to zeros\n");
        memset(dtc_table, 0, len);
        return;
    }
    
    int rc = nvs_read(&fs, 1, dtc_table, len);
    if (rc < 0) {
        /* Initialize to false if read fails (first boot or empty) */
        printk("NVS read failed: %d (first boot or empty storage)\n", rc);
        memset(dtc_table, 0, len);
    } else {
        printk("NVS: Loaded %d bytes of DTC data\n", rc);
    }
}
