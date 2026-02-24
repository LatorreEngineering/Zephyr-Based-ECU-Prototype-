#pragma once
#include <stdbool.h>
#include <stdint.h>

void watchdog_init(void);
void watchdog_kick(void);
bool watchdog_expired(void);
