#pragma once
#include <stdbool.h>

void watchdog_init(void);
void watchdog_kick(void);
bool watchdog_expired(void);
