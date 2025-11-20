#pragma once
#include <stdint.h>

void isotp_init(void);
int isotp_send(uint8_t *data, uint16_t len);
int isotp_receive(uint8_t *buf, uint16_t buf_len);
