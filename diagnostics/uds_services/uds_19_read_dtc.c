#include "uds_19_read_dtc.h"
#include "../dtc_manager.h"
#include <zephyr/kernel.h>

void uds_19_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    if (len < 2) {
        rsp[0] = 0x7F;
        rsp[1] = 0x19;
        rsp[2] = 0x13;
        *rsp_len = 3;
        return;
    }
    
    uint8_t sub_function = req[1];
    
    rsp[0] = 0x59; // Positive response for 0x19
    rsp[1] = sub_function;
    *rsp_len = 2;
    
    // Report number of DTCs
    if (sub_function == 0x01) { // reportNumberOfDTCByStatusMask
        uint8_t count = 0;
        for (int i = 0; i < 256; i++) {
            if (dtc_get_status(i)) {
                count++;
            }
        }
        rsp[2] = count;
        *rsp_len = 3;
    }
}
