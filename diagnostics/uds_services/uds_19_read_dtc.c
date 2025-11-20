#include "uds_19_read_dtc.h"
#include "../dtc_manager.h"

void uds_19_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    uint8_t idx = 0;
    for (uint8_t i=0; i<256; i++) {
        if (dtc_get_status(i)) {
            rsp[idx++] = i;
            if (idx >= *rsp_len) break;
        }
    }
    *rsp_len = idx;
}
