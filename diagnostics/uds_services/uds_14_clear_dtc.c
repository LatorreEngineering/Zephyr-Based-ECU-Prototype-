#include "uds_14_clear_dtc.h"
#include "../dtc_manager.h"

void uds_14_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    for (uint8_t i=0; i<256; i++) {
        dtc_set_fault(i, false);
    }
    rsp[0] = 0x54; // Positive response
    *rsp_len = 1;
}
