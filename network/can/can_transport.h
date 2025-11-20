#pragma once
#include <stdint.h>

void can_init(void);
int can_send(uint8_t *data, uint8_t len);
int can_receive(uint8_t *buf, uint8_t max_len);
