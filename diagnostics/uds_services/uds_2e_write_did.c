#include "uds_2e_write_did.h"
#include <zephyr/kernel.h>

void uds_2e_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    (void)req;
    (void)len;
    
    rsp[0] = 0x6E; // Positive response for 0x2E
    *rsp_len = 1;
}
