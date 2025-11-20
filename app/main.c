#include <zephyr/kernel.h>
#include "ecu_state_machine.h"
#include "watchdog_supervisor.h"
#include "sensor_sim.h"
#include "fault_injection.h"
#include "../diagnostics/uds_server.h"

void main(void)
{
    ecu_init_state_machine();
    sensor_sim_init();
    watchdog_init();
    uds_init();

    while (1) {
        ecu_state_update();
        sensor_sim_update();
        uds_process();
        watchdog_kick();
        k_sleep(K_MSEC(10));
    }
}
