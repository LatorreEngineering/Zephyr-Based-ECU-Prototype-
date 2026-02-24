#pragma once
#include <stdint.h>

void can_init(void);
int ecu_can_send(uint8_t *data, uint8_t len);
int ecu_can_receive(uint8_t *buf, uint8_t max_len);
