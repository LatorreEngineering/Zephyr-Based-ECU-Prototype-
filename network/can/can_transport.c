#include "can_transport.h"
#include <zephyr/drivers/can.h>
#include <zephyr/kernel.h>
#include <string.h>

static const struct device *can_dev;

void can_init(void)
{
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
}

int can_send(uint8_t *data, uint8_t len)
{
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
    
    return can_send(can_dev, &frame, K_MSEC(100), NULL, NULL);
}

int can_receive(uint8_t *buf, uint8_t max_len)
{
    if (!can_dev || !device_is_ready(can_dev)) {
        return -ENODEV;
    }
    
    struct can_frame frame;
    int ret = can_read(can_dev, &frame, K_NO_WAIT, NULL);
    if (ret != 0) {
        return ret;
    }
    
    int len = (frame.dlc > max_len) ? max_len : frame.dlc;
    memcpy(buf, frame.data, len);
    
    return len;
}
