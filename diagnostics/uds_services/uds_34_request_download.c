#include "uds_34_request_download.h"

void uds_34_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    rsp[0] = 0x74; // Positive response
    *rsp_len = 1;
}
