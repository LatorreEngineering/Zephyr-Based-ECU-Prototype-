#include "uds_session.h"
#include <zephyr/kernel.h>

static uint8_t current_session;

void uds_session_init(void)
{
    current_session = 0x01; // Default session (DefaultSession)
}

uint8_t uds_get_session(void)
{
    return current_session;
}

void uds_set_session(uint8_t session)
{
    current_session = session;
}
