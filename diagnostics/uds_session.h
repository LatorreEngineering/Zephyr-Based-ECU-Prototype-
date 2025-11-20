#pragma once
#include <stdint.h>

void uds_session_init(void);
uint8_t uds_get_session(void);
void uds_set_session(uint8_t session);
