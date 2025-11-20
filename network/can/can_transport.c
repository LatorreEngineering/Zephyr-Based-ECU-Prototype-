#include "can_transport.h"
#include <zephyr/drivers/can.h>

static const struct device *can_dev = DEVICE_DT_GET(DT_NODELABEL(can0));

void can_init(void)
{
    if (!device_is_ready(can_dev)) {
        printk("CAN device not ready\n");
        return;
    }
}

int can_send(uint8_t *data, uint8_t len)
{
    struct zcan_frame frame;
    frame.id_type = CAN_STANDARD_IDENTIFIER;
    frame.rtr = CAN_DATAFRAME;
    frame.id = 0x7E0;
    frame.dlc = len;
    memcpy(frame.data, data, len);
    return can_send(can_dev, &frame, K_MSEC(10), NULL, NULL);
}

int can_receive(uint8_t *buf, uint8_t max_len)
{
    struct zcan_frame frame;
    int ret = can_read(can_dev, &frame, K_MSEC(10), NULL);
    if (ret < 0) return ret;
    int len = (frame.dlc > max_len) ? max_len : frame.dlc;
    memcpy(buf, frame.data, len);
    return len;
}
