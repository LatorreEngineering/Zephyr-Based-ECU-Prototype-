#include "fault_injection.h"
#include <zephyr/kernel.h>

static bool inject_can_error = false;

void fault_injection_init(void)
{
    inject_can_error = false;
}

void fault_injection_process(void)
{
    // Example: toggle CAN error every 10s
    if ((k_uptime_get() / 10000) % 2) {
        inject_can_error = true;
    } else {
        inject_can_error = false;
    }
}

bool fault_injection_can(void)
{
    return inject_can_error;
}
