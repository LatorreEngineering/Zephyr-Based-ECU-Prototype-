#include "uds_11_ecu_reset.h"
#include "../../app/ecu_state_machine.h"
#include <zephyr/kernel.h>
#include <zephyr/sys/reboot.h>

void uds_11_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    if (len < 2) {
        rsp[0] = 0x7F;
        rsp[1] = 0x11;
        rsp[2] = 0x13; // incorrectMessageLengthOrInvalidFormat
        *rsp_len = 3;
        return;
    }
    
    uint8_t reset_type = req[1];
    
    rsp[0] = 0x51; // Positive response for 0x11
    rsp[1] = reset_type;
    *rsp_len = 2;
    
    // Trigger reset after sending response
    k_sleep(K_MSEC(100));
    
    switch (reset_type) {
    case 0x01: // hardReset
        sys_reboot(SYS_REBOOT_COLD);
        break;
    case 0x02: // keyOffOnReset
    case 0x03: // softReset
        ecu_trigger_reset();
        break;
    default:
        break;
    }
}
