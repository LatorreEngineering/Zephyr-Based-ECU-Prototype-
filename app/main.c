#include <zephyr/kernel.h>
#include "ecu_state_machine.h"
#include "sensor_sim.h"
#include "fault_injection.h"
#include "watchdog_supervisor.h"
#include "../diagnostics/uds_server.h"

int main(void)
{
    printk("Starting Zephyr ECU Prototype\n");

    ecu_init_state_machine();
    sensor_sim_init();
    fault_injection_init();
    watchdog_init();
    uds_init();

    while (1) {
        ecu_state_update();
        sensor_sim_update();
        fault_injection_process();
        uds_process();
        watchdog_kick();
        k_sleep(K_MSEC(10));
    }

    return 0;
}
