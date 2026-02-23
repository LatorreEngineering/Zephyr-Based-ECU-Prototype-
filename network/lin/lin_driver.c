#include "lin_driver.h"
#include <zephyr/drivers/uart.h>
#include <zephyr/kernel.h>
#include <zephyr/device.h>

static const struct device *uart_dev;

int lin_init(void)
{
    uart_dev = DEVICE_DT_GET(DT_NODELABEL(uart3));
    
    if (!device_is_ready(uart_dev)) {
        printk("UART device not ready for LIN\n");
        return -1;
    }
    
    // Configure UART for LIN: 19200 baud, 8N1
    struct uart_config cfg = {
        .baudrate = 19200,
        .parity = UART_CFG_PARITY_NONE,
        .stop_bits = UART_CFG_STOP_BITS_1,
        .data_bits = UART_CFG_DATA_BITS_8,
        .flow_ctrl = UART_CFG_FLOW_CTRL_NONE
    };
    
    int ret = uart_configure(uart_dev, &cfg);
    if (ret != 0) {
        printk("Failed to configure UART for LIN: %d\n", ret);
        return ret;
    }
    
    printk("LIN driver initialized\n");
    return 0;
}

int lin_send_break(void)
{
    if (!uart_dev) {
        return -1;
    }
    
    // Send break signal (13-bit dominant)
    uart_line_ctrl_set(uart_dev, UART_LINE_CTRL_BAUD_RATE, 9600);
    uart_poll_out(uart_dev, 0x00);
    k_usleep(800);
    uart_line_ctrl_set(uart_dev, UART_LINE_CTRL_BAUD_RATE, 19200);
    
    return 0;
}

int lin_send_header(uint8_t pid)
{
    if (!uart_dev) {
        return -1;
    }
    
    lin_send_break();
    uart_poll_out(uart_dev, 0x55); // Sync byte
    k_usleep(100);
    uart_poll_out(uart_dev, pid);  // Protected ID
    
    return 0;
}
