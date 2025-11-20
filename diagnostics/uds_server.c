#include "uds_server.h"
#include "uds_session.h"
#include "dtc_manager.h"
#include "../network/can/can_transport.h"
#include "transport/isotp_can.h"

/* Dispatch table for all UDS services */
static uds_service_handler_t service_table[0x100];

void uds_init(void)
{
    isotp_init();
    uds_session_init();
    dtc_manager_init();

    uds_register_builtin_services(service_table);
}

void uds_process(void)
{
    uint8_t req_buf[UDS_MAX_LEN];
    uint8_t rsp_buf[UDS_MAX_LEN];

    int len = isotp_receive(req_buf, sizeof(req_buf));
    if (len <= 0) return;

    uds_handle_request(req_buf, len, rsp_buf);
    isotp_send(rsp_buf, rsp_buf[1] + 2);
}
