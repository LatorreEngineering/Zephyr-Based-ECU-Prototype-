#include "dtc_manager.h"
#include "../storage/nvs_dtc_storage.h"
#include <zephyr/kernel.h>

static bool dtc_status[256]; // 256 DTCs

void dtc_manager_init(void)
{
    nvs_init();
    nvs_load_dtc(dtc_status, sizeof(dtc_status));
}

void dtc_set_fault(uint8_t dtc_id, bool active)
{
    dtc_status[dtc_id] = active;
    nvs_save_dtc(dtc_status, sizeof(dtc_status));
}

bool dtc_get_status(uint8_t dtc_id)
{
    return dtc_status[dtc_id];
}
