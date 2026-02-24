#include "lin_scheduler.h"
#include "lin_driver.h"
#include <zephyr/kernel.h>

static struct k_timer lin_timer;
static bool scheduler_running = false;

static void lin_timer_handler(struct k_timer *timer)
{
    (void)timer;
    static uint8_t pid = 0x10;
    
    if (scheduler_running) {
        int ret = lin_send_header(pid);
        if (ret == 0) {
            pid++;
            if (pid > 0x3F) {
                pid = 0x10;
            }
        }
    }
}

void lin_scheduler_start(void)
{
    if (!scheduler_running) {
        int ret = lin_init();
        if (ret != 0) {
            printk("LIN scheduler: init failed, scheduler disabled\n");
            return;
        }
        
        k_timer_init(&lin_timer, lin_timer_handler, NULL);
        k_timer_start(&lin_timer, K_MSEC(20), K_MSEC(20)); // 50Hz
        scheduler_running = true;
        printk("LIN scheduler started\n");
    }
}
