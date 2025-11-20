#include "ecu_state_machine.h"
#include <zephyr/kernel.h>

static ecu_state_t current_state;

void ecu_init_state_machine(void)
{
    current_state = ECU_OFF;
}

void ecu_state_update(void)
{
    switch (current_state) {
    case ECU_OFF:
        if (ignition_on()) {
            current_state = ECU_ON;
        }
        break;
    case ECU_ON:
        // Check for errors
        if (fault_detected()) {
            current_state = ECU_ERROR;
        }
        break;
    case ECU_ERROR:
        // Wait for reset
        if (reset_triggered()) {
            current_state = ECU_OFF;
        }
        break;
    default:
        current_state = ECU_OFF;
        break;
    }
}

ecu_state_t ecu_get_state(void)
{
    return current_state;
}
