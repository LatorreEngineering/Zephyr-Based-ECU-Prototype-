#include "uds_14_clear_dtc.h"
#include "../dtc_manager.h"
#include <zephyr/kernel.h>
#include <string.h>

void uds_14_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    (void)req;
    (void)len;
    
    // Clear all DTCs
    for (int i = 0; i < 256; i++) {
        dtc_set_fault(i, false);
    }
    
    rsp[0] = 0x54; // Positive response for 0x14
    *rsp_len = 1;
}
