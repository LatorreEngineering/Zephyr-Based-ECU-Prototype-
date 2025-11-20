#include "uds_27_security_access.h"

void uds_27_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    // Minimal: always return positive response
    rsp[0] = 0x67;
    if (len>1) rsp[1] = req[1];
    *rsp_len = 2;
}
