#include "uds_37_transfer_exit.h"

void uds_37_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    rsp[0] = 0x77;
    *rsp_len = 1;
}
