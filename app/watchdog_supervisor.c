#include "watchdog_supervisor.h"
#include <zephyr/kernel.h>

static int counter = 0;

void watchdog_init(void)
{
    counter = 0;
}

void watchdog_kick(void)
{
    counter = 0; // reset counter every tick
}

// Simulate periodic check
bool watchdog_expired(void)
{
    counter++;
    if (counter > 1000) {
        return true;
    }
    return false;
}
