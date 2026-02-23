#include "uds_23_write_data.h"
#include <zephyr/kernel.h>

void uds_23_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    (void)req;
    (void)len;
    
    // Stub implementation
    rsp[0] = 0x63; // Positive response for 0x23
    *rsp_len = 1;
}
