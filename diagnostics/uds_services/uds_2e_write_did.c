#include "uds_2e_write_did.h"

void uds_2e_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    // Minimal: acknowledge DID
    if (len<2) { *rsp_len=0; return; }
    rsp[0] = 0x6E;
    rsp[1] = req[1];
    *rsp_len = 2;
}
