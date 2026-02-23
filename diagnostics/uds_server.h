#pragma once
#include <stdint.h>

void uds_init(void);
void uds_process(void);
void uds_register_builtin_services(void **service_table);
void uds_handle_request(uint8_t *req, int len, void *context);
