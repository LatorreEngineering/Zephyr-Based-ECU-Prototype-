#include "uds_server.h"
#include "uds_session.h"
#include "dtc_manager.h"
#include "../network/can/can_transport.h"
#include "transport/isotp_can.h"
#include <zephyr/kernel.h>

#define UDS_MAX_LEN 4096

typedef void (*uds_service_handler_t)(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
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
    uint16_t rsp_len = 0;

    int len = isotp_receive(req_buf, sizeof(req_buf));
    if (len <= 0) return;

    uint8_t sid = req_buf[0];
    if (service_table[sid]) {
        service_table[sid](req_buf, len, rsp_buf, &rsp_len);
        isotp_send(rsp_buf, rsp_len);
    }
}
