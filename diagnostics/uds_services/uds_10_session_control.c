#include "uds_10_session_control.h"
#include "../uds_session.h"

void uds_10_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len)
{
    if (len < 2) return;
    uint8_t session = req[1];
    uds_set_session(session);

    rsp[0] = 0x50; // Positive response for 0x10
    rsp[1] = session;
    *rsp_len = 2;
}
