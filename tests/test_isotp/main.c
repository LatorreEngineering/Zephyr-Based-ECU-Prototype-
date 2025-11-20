#include <zephyr/ztest.h>
#include "diagnostics/transport/isotp_can.h"
#include <string.h>

ZTEST_SUITE(isotp_suite, NULL, NULL, NULL, NULL, NULL);

ZTEST(isotp_suite, test_send_receive)
{
    isotp_init();

    uint8_t tx[16];
    for (int i=0;i<16;i++) tx[i]=i;

    int sent = isotp_send(tx, sizeof(tx));
    zassert_equal(sent, sizeof(tx), "All bytes should be sent");

    uint8_t rx[16];
    int received = isotp_receive(rx, sizeof(rx));
    zassert_true(received >=0, "Receive should not fail");
}
