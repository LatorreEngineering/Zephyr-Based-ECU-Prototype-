#include "ecu_state_machine.h"
#include "sensor_sim.h"
#include "fault_injection.h"
#include "watchdog_supervisor.h"
#include "../diagnostics/uds_server.h"

#include <zephyr/kernel.h>

/* OpenSOME/IP runner thread (C++ function, declared extern "C" for C linkage) */
extern void someip_runner_thread(void *arg1, void *arg2, void *arg3);

int main(void)
{
    printk("Starting Zephyr ECU Prototype\n");

    ecu_init_state_machine();
    sensor_sim_init();
    fault_injection_init();
    watchdog_init();
    uds_init();

    /* ===================================================================== */
    /* INTEGRATION POINT: Launch OpenSOME/IP stack in dedicated Zephyr thread */
    /* ===================================================================== */
    printk("Launching OpenSOME/IP stack thread...\n");

    K_THREAD_STACK_DEFINE(someip_thread_stack, 4096);
    struct k_thread someip_thread;

    k_tid_t someip_tid = k_thread_create(&someip_thread,
                                         someip_thread_stack,
                                         K_THREAD_STACK_SIZEOF(someip_thread_stack),
                                         someip_runner_thread,
                                         NULL, NULL, NULL,
                                         5, 0, K_NO_WAIT);

    k_thread_name_set(someip_tid, "someip_runner");
    printk("OpenSOME/IP thread started (priority 5, stack 4096 bytes)\n");

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
