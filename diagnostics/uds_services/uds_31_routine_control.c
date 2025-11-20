#include "uds_31_routine_control.h"

void uds_31_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    rsp[0] = 0x71;
    *rsp_len = 1;
}
