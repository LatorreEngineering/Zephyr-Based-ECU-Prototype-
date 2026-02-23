#include "uds_28_communication_control.h"
#include <zephyr/kernel.h>

void uds_28_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    (void)req;
    (void)len;
    
    rsp[0] = 0x68; // Positive response for 0x28
    *rsp_len = 1;
}
