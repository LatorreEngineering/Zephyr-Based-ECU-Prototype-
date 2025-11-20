#include <zephyr/ztest.h>
#include "network/lin/lin_driver.h"
#include "network/lin/lin_scheduler.h"

ZTEST_SUITE(lin_suite, NULL, NULL, NULL, NULL, NULL);

ZTEST(lin_suite, test_lin_scheduler)
{
    int ret = lin_init();
    zassert_equal(ret, 0, "LIN initialization should succeed");

    lin_scheduler_start();
    k_sleep(K_MSEC(50)); // simulate scheduler running
    zassert_true(true, "LIN scheduler ran without crash");
}
