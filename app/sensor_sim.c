#include "sensor_sim.h"
#include <zephyr/kernel.h>
#include "../diagnostics/dtc_manager.h"

static uint16_t rpm = 0;
static float temperature = 25.0f;
static float voltage = 12.0f;

void sensor_sim_init(void)
{
    rpm = 0;
    temperature = 25.0f;
    voltage = 12.0f;
}

void sensor_sim_update(void)
{
    rpm = (rpm + 50) % 8000;
    temperature += 0.1f;
    if (temperature > 120.0f) temperature = 25.0f;

    voltage = 12.0f + ((float)(k_uptime_get_32() % 100) / 100.0f);

    // Example: raise a DTC if temp exceeds threshold
    if (temperature > 100.0f) {
        dtc_set_fault(0x01, true);
    } else {
        dtc_set_fault(0x01, false);
    }
}

uint16_t sensor_get_rpm(void) { return rpm; }
float sensor_get_temp(void) { return temperature; }
float sensor_get_voltage(void) { return voltage; }
