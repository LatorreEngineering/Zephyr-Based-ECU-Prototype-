#include "uds_23_write_data.h"

void uds_23_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    // Minimal: echo back DID
    if (len < 2) {
        *rsp_len = 0;
        return;
    }
    rsp[0] = 0x63; // Positive response for 0x23
    rsp[1] = req[1]; // DID
    *rsp_len = 2;
}
