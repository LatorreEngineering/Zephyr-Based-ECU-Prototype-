#pragma once
#include <stdbool.h>
#include <stdint.h>

void dtc_manager_init(void);
void dtc_set_fault(uint8_t dtc_id, bool active);
bool dtc_get_status(uint8_t dtc_id);
