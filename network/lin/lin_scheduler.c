#include "lin_scheduler.h"
#include "lin_driver.h"
#include <zephyr/kernel.h>

static struct k_timer lin_timer;

static void lin_timer_handler(struct k_timer *timer)
{
    static uint8_t pid = 0x10;
    lin_send_header(pid);
    pid++;
}

void lin_scheduler_start(void)
{
    lin_init();
    k_timer_init(&lin_timer, lin_timer_handler, NULL);
    k_timer_start(&lin_timer, K_MSEC(20), K_MSEC(20)); // 50Hz
}
