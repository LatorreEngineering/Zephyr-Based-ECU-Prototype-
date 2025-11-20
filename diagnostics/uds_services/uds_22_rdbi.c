#include "uds_22_rdbi.h"
#include "../app/sensor_sim.h"

void uds_22_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    if (len < 2) return;
    uint8_t did = req[1];

    switch(did) {
        case 0x01: { // RPM
            uint16_t rpm = sensor_get_rpm();
            rsp[0] = (rpm >> 8) & 0xFF;
            rsp[1] = rpm & 0xFF;
            *rsp_len = 2;
            break;
        }
        case 0x02: { // Temperature
            float temp = sensor_get_temp();
            rsp[0] = (uint8_t)temp;
            *rsp_len = 1;
            break;
        }
        case 0x03: { // Voltage
            float volt = sensor_get_voltage();
            rsp[0] = (uint8_t)(volt*10);
            *rsp_len = 1;
            break;
        }
        default:
            *rsp_len = 0;
            break;
    }
}
