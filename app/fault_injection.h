#pragma once
#include <stdbool.h>
#include <stdint.h>

void fault_injection_init(void);
void fault_injection_process(void);
bool fault_injection_can(void);
