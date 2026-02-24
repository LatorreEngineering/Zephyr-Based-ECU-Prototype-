#include "can_transport.h"
#include <zephyr/drivers/can.h>
#include <zephyr/kernel.h>
#include <string.h>

static const struct device *can_dev;
static int rx_filter_id = -1;

void can_init(void)
{
#if DT_NODE_EXISTS(DT_NODELABEL(flexcan0))
    // Use flexcan0 node label (Zephyr v3.7+)
    can_dev = DEVICE_DT_GET(DT_NODELABEL(flexcan0));
    
    if (!device_is_ready(can_dev)) {
        printk("CAN device not ready\n");
        return;
    }
    
    // Start the CAN controller
    int ret = can_start(can_dev);
    if (ret != 0) {
        printk("Failed to start CAN controller: %d\n", ret);
    } else {
        printk("CAN initialized successfully\n");
    }
#else
    printk("CAN: flexcan0 not available on this board\n");
    can_dev = NULL;
#endif
}

int ecu_can_send(uint8_t *data, uint8_t len)
{
#if DT_NODE_EXISTS(DT_NODELABEL(flexcan0))
    if (!can_dev || !device_is_ready(can_dev)) {
        return -ENODEV;
    }
    
    struct can_frame frame = {
        .flags = 0,
        .id = 0x7E0,  // UDS request ID
        .dlc = len
    };
    
    if (len > sizeof(frame.data)) {
        len = sizeof(frame.data);
    }
    
    memcpy(frame.data, data, len);
    
    // Use Zephyr's can_send API
    return can_send(can_dev, &frame, K_MSEC(100), NULL, NULL);
#else
    (void)data;
    (void)len;
    return -ENOTSUP;
#endif
}

static void can_rx_callback(const struct device *dev, struct can_frame *frame,
                            void *user_data)
{
    // This callback is called when a CAN frame is received
    // For now, we'll just use polling in ecu_can_receive
    ARG_UNUSED(dev);
    ARG_UNUSED(frame);
    ARG_UNUSED(user_data);
}

int ecu_can_receive(uint8_t *buf, uint8_t max_len)
{
#if DT_NODE_EXISTS(DT_NODELABEL(flexcan0))
    if (!can_dev || !device_is_ready(can_dev)) {
        return -ENODEV;
    }
    
    struct can_frame frame;
    
    // Add RX filter if not already added
    if (rx_filter_id < 0) {
        struct can_filter filter = {
            .flags = 0,
            .id = 0x7E8,  // UDS response ID
            .mask = CAN_STD_ID_MASK
        };
        
        // Correct API: can_add_rx_filter(dev, callback, user_data, filter)
        rx_filter_id = can_add_rx_filter(can_dev, can_rx_callback, NULL, &filter);
        if (rx_filter_id < 0) {
            return rx_filter_id;
        }
    }
    
    // Use msgq to receive (correct Zephyr v3.7 API)
    // For now, return 0 (no data) as we'd need a message queue setup
    // This is a simplified implementation
    return 0;
#else
    (void)buf;
    (void)max_len;
    return -ENOTSUP;
#endif
}
