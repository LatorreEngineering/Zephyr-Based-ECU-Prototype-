#include "nvs_dtc_storage.h"
#include <zephyr/storage/flash_map.h>
#include <zephyr/fs/nvs.h>
#include <zephyr/device.h>
#include <zephyr/kernel.h>
#include <string.h>

static struct nvs_fs fs;

#define NVS_PARTITION_ID FIXED_PARTITION_ID(storage_partition)
#define NVS_PARTITION_DEVICE FIXED_PARTITION_DEVICE(storage_partition)

void nvs_init(void)
{
    struct flash_pages_info info;
    int rc;

    fs.flash_device = NVS_PARTITION_DEVICE;
    if (!device_is_ready(fs.flash_device)) {
        printk("Flash device not ready\n");
        return;
    }

    fs.offset = FIXED_PARTITION_OFFSET(storage_partition);
    
    rc = flash_get_page_info_by_offs(fs.flash_device, fs.offset, &info);
    if (rc) {
        printk("Unable to get page info: %d\n", rc);
        return;
    }
    
    fs.sector_size = info.size;
    fs.sector_count = 4U;

    rc = nvs_mount(&fs);
    if (rc) {
        printk("Flash Init failed: %d\n", rc);
    } else {
        printk("NVS initialized successfully\n");
    }
}

void nvs_save_dtc(bool *dtc_table, size_t len)
{
    // Save in chunks to avoid too many writes
    nvs_write(&fs, 1, dtc_table, len);
}

void nvs_load_dtc(bool *dtc_table, size_t len)
{
    int rc = nvs_read(&fs, 1, dtc_table, len);
    if (rc < 0) {
        // Initialize to false if read fails
        memset(dtc_table, 0, len);
    }
}
