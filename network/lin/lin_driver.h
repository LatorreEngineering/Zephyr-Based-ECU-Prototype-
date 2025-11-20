#pragma once
#include <stdint.h>

int lin_init(void);
int lin_send_break(void);
int lin_send_header(uint8_t pid);
