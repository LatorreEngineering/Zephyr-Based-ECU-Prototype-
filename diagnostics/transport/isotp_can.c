#include "isotp_can.h"
#include "../../network/can/can_transport.h"
#include <zephyr/kernel.h>

#define ISOTP_MAX_FRAME 8

void isotp_init(void)
{
    can_init();
}

int isotp_send(uint8_t *data, uint16_t len)
{
    // Naive segmentation
    uint16_t sent = 0;
    while (sent < len) {
        uint8_t frame[ISOTP_MAX_FRAME];
        int frame_len = (len - sent > ISOTP_MAX_FRAME) ? ISOTP_MAX_FRAME : len - sent;
        memcpy(frame, data + sent, frame_len);
        can_send(frame, frame_len);
        sent += frame_len;
        k_sleep(K_MSEC(1));
    }
    return sent;
}

int isotp_receive(uint8_t *buf, uint16_t buf_len)
{
    int len = can_receive(buf, buf_len);
    return len;
}
