cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(zephyr_ecu_prototype)

target_sources(app PRIVATE
    app/main.c
    app/ecu_state_machine.c
    app/sensor_sim.c
    app/fault_injection.c
    app/watchdog_supervisor.c

    diagnostics/uds_server.c
    diagnostics/uds_session.c
    diagnostics/dtc_manager.c

    diagnostics/transport/isotp_can.c

    network/can/can_transport.c
    network/lin/lin_driver.c
    network/lin/lin_scheduler.c
    network/comm_manager.c

    storage/nvs_dtc_storage.c
)
