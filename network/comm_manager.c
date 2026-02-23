#include "comm_manager.h"
#include "can/can_transport.h"
#include "lin/lin_scheduler.h"
#include "../diagnostics/uds_server.h"
#include "../app/fault_injection.h"
#include <zephyr/kernel.h>

#define CM_CAN_TX_INTERVAL_MS 10
#define CM_LIN_CHECK_INTERVAL_MS 20

static struct k_timer cm_can_timer;
static struct k_timer cm_lin_timer;

/* CAN TX task */
static void cm_can_tx_handler(struct k_timer *timer)
{
    (void)timer;
    uint8_t msg[8] = {0};

    // Example: send periodic heartbeat or status
    msg[0] = 0xAA; // dummy status byte
    if (fault_injection_can()) {
        msg[0] = 0xFF; // simulate CAN fault
    }

    can_send(msg, sizeof(msg));
}

/* LIN task */
static void cm_lin_handler(struct k_timer *timer)
{
    (void)timer;
    // Trigger LIN scheduler (sends scheduled headers)
    lin_scheduler_start();
}

/* Initialization */
void comm_manager_init(void)
{
    can_init();
    lin_scheduler_start(); // init scheduler

    k_timer_init(&cm_can_timer, cm_can_tx_handler, NULL);
    k_timer_start(&cm_can_timer, K_MSEC(CM_CAN_TX_INTERVAL_MS),
                  K_MSEC(CM_CAN_TX_INTERVAL_MS));

    k_timer_init(&cm_lin_timer, cm_lin_handler, NULL);
    k_timer_start(&cm_lin_timer, K_MSEC(CM_LIN_CHECK_INTERVAL_MS),
                  K_MSEC(CM_LIN_CHECK_INTERVAL_MS));
    
    printk("Communication manager initialized\n");
}

/* Process incoming CAN messages for UDS */
void comm_manager_process(void)
{
    uint8_t rx_buf[64];
    int len = can_receive(rx_buf, sizeof(rx_buf));
    if (len > 0) {
        // Forward to UDS processing
        uds_handle_request(rx_buf, len, NULL); // rsp handled internally
    }

    // LIN messages handled by scheduler automatically
}
