#pragma once

void sensor_sim_init(void);
void sensor_sim_update(void);

uint16_t sensor_get_rpm(void);
float sensor_get_temp(void);
float sensor_get_voltage(void);
