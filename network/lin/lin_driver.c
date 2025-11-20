#include "lin_driver.h"
#include <zephyr/drivers/uart.h>

#define LIN_BAUD 19200

static const struct device *uart = DEVICE_DT_GET(DT_NODELABEL(uart3));

int lin_send_break(void)
{
    uart_line_ctrl_set(uart, UART_LINE_CTRL_BREAK, 1);
    k_sleep(K_USEC(800));   // break field
    uart_line_ctrl_set(uart, UART_LINE_CTRL_BREAK, 0);
    return 0;
}

int lin_send_header(uint8_t pid)
{
    lin_send_break();
    uart_poll_out(uart, 0x55);  // sync
    uart_poll_out(uart, pid);   // PID
    return 0;
}
