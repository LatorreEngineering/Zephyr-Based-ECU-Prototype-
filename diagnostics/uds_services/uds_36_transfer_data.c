#include "uds_36_transfer_data.h"
#include <zephyr/kernel.h>

void uds_36_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    (void)req;
    (void)len;
    
    rsp[0] = 0x76; // Positive response for 0x36
    *rsp_len = 1;
}
