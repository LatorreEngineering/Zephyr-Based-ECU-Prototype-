#include "nvs_dtc_storage.h"
#include <zephyr/storage/flash_map.h>
#include <zephyr/fs/nvs.h>

static struct nvs_fs fs;

void nvs_init(void)
{
    fs.offset = FLASH_AREA_OFFSET(storage);
    fs.sector_size = 4096;
    fs.sector_count = 4;
    fs.flash_device = DEVICE_DT_GET(DT_CHOSEN(zephyr_flash_controller));
    nvs_init(&fs, NULL);
}

void nvs_save_dtc(bool *dtc_table, size_t len)
{
    for (size_t i=0; i<len; i++) {
        nvs_write(&fs, i, &dtc_table[i], sizeof(bool));
    }
}

void nvs_load_dtc(bool *dtc_table, size_t len)
{
    for (size_t i=0; i<len; i++) {
        nvs_read(&fs, i, &dtc_table[i], sizeof(bool));
    }
}
