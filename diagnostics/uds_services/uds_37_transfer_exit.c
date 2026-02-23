#include "uds_37_transfer_exit.h"
#include <zephyr/kernel.h>

void uds_37_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    (void)req;
    (void)len;
    
    rsp[0] = 0x77; // Positive response for 0x37
    *rsp_len = 1;
}
