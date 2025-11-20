#include <zephyr/ztest.h>
#include "diagnostics/dtc_manager.h"

ZTEST_SUITE(dtc_suite, NULL, NULL, NULL, NULL, NULL);

ZTEST(dtc_suite, test_dtc_set_clear)
{
    dtc_manager_init();

    dtc_set_fault(0x01, true);
    zassert_true(dtc_get_status(0x01), "DTC 0x01 should be active");

    dtc_set_fault(0x01, false);
    zassert_false(dtc_get_status(0x01), "DTC 0x01 should be cleared");
}
