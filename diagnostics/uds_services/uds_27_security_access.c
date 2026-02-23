#include "uds_27_security_access.h"
#include <zephyr/kernel.h>

static uint32_t seed = 0x12345678;
static bool unlocked = false;

void uds_27_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    if (len < 2) {
        rsp[0] = 0x7F;
        rsp[1] = 0x27;
        rsp[2] = 0x13;
        *rsp_len = 3;
        return;
    }
    
    uint8_t sub_function = req[1];
    
    if (sub_function == 0x01) { // requestSeed
        rsp[0] = 0x67;
        rsp[1] = 0x01;
        rsp[2] = (seed >> 24) & 0xFF;
        rsp[3] = (seed >> 16) & 0xFF;
        rsp[4] = (seed >> 8) & 0xFF;
        rsp[5] = seed & 0xFF;
        *rsp_len = 6;
    } else if (sub_function == 0x02) { // sendKey
        // Simple key check: key = seed XOR 0xAAAAAAAA
        if (len < 6) {
            rsp[0] = 0x7F;
            rsp[1] = 0x27;
            rsp[2] = 0x13;
            *rsp_len = 3;
            return;
        }
        
        uint32_t key = ((uint32_t)req[2] << 24) | ((uint32_t)req[3] << 16) |
                       ((uint32_t)req[4] << 8) | req[5];
        uint32_t expected_key = seed ^ 0xAAAAAAAA;
        
        if (key == expected_key) {
            unlocked = true;
            rsp[0] = 0x67;
            rsp[1] = 0x02;
            *rsp_len = 2;
        } else {
            rsp[0] = 0x7F;
            rsp[1] = 0x27;
            rsp[2] = 0x35; // invalidKey
            *rsp_len = 3;
        }
    }
}
