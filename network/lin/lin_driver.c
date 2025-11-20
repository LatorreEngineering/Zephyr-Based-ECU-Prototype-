#include "lin_driver.h"
#include <zephyr/drivers/uart.h>

static const struct device *uart = DEVICE_DT_GET(DT_NODELABEL(uart3));

int lin_init(void)
{
    if (!device_is_ready(uart)) return -1;
    uart_configure(uart, 19200, UART_CFG_PARITY_NONE, UART_CFG_STOP_BITS_1);
    return 0;
}

int lin_send_break(void)
{
    uart_line_ctrl_set(uart, UART_LINE_CTRL_BREAK, 1);
    k_sleep(K_USEC(800));
    uart_line_ctrl_set(uart, UART_LINE_CTRL_BREAK, 0);
    return 0;
}

int lin_send_header(uint8_t pid)
{
    lin_send_break();
    uart_poll_out(uart, 0x55); // Sync
    uart_poll_out(uart, pid);
    return 0;
}
