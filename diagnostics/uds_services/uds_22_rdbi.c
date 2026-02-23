#include "uds_22_rdbi.h"
#include "../../app/sensor_sim.h"
#include <zephyr/kernel.h>

void uds_22_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    if (len < 3) {
        rsp[0] = 0x7F;
        rsp[1] = 0x22;
        rsp[2] = 0x13; // incorrectMessageLengthOrInvalidFormat
        *rsp_len = 3;
        return;
    }
    
    uint16_t did = ((uint16_t)req[1] << 8) | req[2];

    rsp[0] = 0x62; // Positive response for 0x22
    rsp[1] = req[1]; // Echo DID high byte
    rsp[2] = req[2]; // Echo DID low byte
    
    switch(did) {
        case 0x0001: { // RPM
            uint16_t rpm = sensor_get_rpm();
            rsp[3] = (rpm >> 8) & 0xFF;
            rsp[4] = rpm & 0xFF;
            *rsp_len = 5;
            break;
        }
        case 0x0002: { // Temperature
            float temp = sensor_get_temp();
            rsp[3] = (uint8_t)temp;
            *rsp_len = 4;
            break;
        }
        case 0x0003: { // Voltage
            float volt = sensor_get_voltage();
            rsp[3] = (uint8_t)(volt * 10);
            *rsp_len = 4;
            break;
        }
        default:
            // Data identifier not supported
            rsp[0] = 0x7F;
            rsp[1] = 0x22;
            rsp[2] = 0x31; // requestOutOfRange
            *rsp_len = 3;
            break;
    }
}
