#include "uds_11_ecu_reset.h"
#include <zephyr/kernel.h>

void uds_11_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    rsp[0] = 0x51; // Positive response
    *rsp_len = 1;

    // Simulate ECU reset after response
    k_sleep(K_MSEC(100));
    sys_reboot(SYS_REBOOT_COLD);
}
