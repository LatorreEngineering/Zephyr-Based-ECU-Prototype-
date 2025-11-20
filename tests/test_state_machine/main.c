#include <zephyr/ztest.h>
#include "app/ecu_state_machine.h"

static int ignition_flag = 0;
static int fault_flag = 0;
static int reset_flag = 0;

/* Override functions for testing */
int ignition_on(void) { return ignition_flag; }
int fault_detected(void) { return fault_flag; }
int reset_triggered(void) { return reset_flag; }

ZTEST_SUITE(state_machine_suite, NULL, NULL, NULL, NULL, NULL);

ZTEST(state_machine_suite, test_state_transitions)
{
    ecu_init_state_machine();
    zassert_equal(ecu_get_state(), ECU_OFF, "ECU should start OFF");

    ignition_flag = 1;
    fault_flag = 0;
    reset_flag = 0;
    ecu_state_update();
    zassert_equal(ecu_get_state(), ECU_ON, "ECU should transition to ON");

    fault_flag = 1;
    ecu_state_update();
    zassert_equal(ecu_get_state(), ECU_ERROR, "ECU should transition to ERROR");

    reset_flag = 1;
    ecu_state_update();
    zassert_equal(ecu_get_state(), ECU_OFF, "ECU should reset to OFF");
}
