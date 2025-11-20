#pragma once

typedef enum {
    ECU_OFF,
    ECU_ON,
    ECU_ERROR
} ecu_state_t;

void ecu_init_state_machine(void);
void ecu_state_update(void);
ecu_state_t ecu_get_state(void);

int ignition_on(void);
int fault_detected(void);
int reset_triggered(void);
