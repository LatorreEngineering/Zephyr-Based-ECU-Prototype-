#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

void nvs_init(void);
void nvs_save_dtc(bool *dtc_table, size_t len);
void nvs_load_dtc(bool *dtc_table, size_t len);
