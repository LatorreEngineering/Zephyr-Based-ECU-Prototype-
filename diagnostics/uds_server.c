#include "uds_server.h"
#include "uds_session.h"
#include "dtc_manager.h"
#include "../network/can/can_transport.h"
#include "transport/isotp_can.h"
#include <zephyr/kernel.h>
#include <string.h>

#define UDS_MAX_LEN 4096

typedef void (*uds_service_handler_t)(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
static uds_service_handler_t service_table[0x100];

// Forward declarations of UDS service handlers
void uds_10_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_11_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_14_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_19_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_22_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_23_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_27_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_28_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_2e_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_31_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_34_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_36_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);
void uds_37_handle(uint8_t *req, uint16_t len, uint8_t *rsp, uint16_t *rsp_len);

void uds_register_builtin_services(void **srv_table)
{
    uds_service_handler_t *table = (uds_service_handler_t *)srv_table;
    
    // Initialize table to NULL
    memset(table, 0, sizeof(uds_service_handler_t) * 0x100);
    
    // Register UDS service handlers
    table[0x10] = uds_10_handle;
    table[0x11] = uds_11_handle;
    table[0x14] = uds_14_handle;
    table[0x19] = uds_19_handle;
    table[0x22] = uds_22_handle;
    table[0x23] = uds_23_handle;
    table[0x27] = uds_27_handle;
    table[0x28] = uds_28_handle;
    table[0x2E] = uds_2e_handle;
    table[0x31] = uds_31_handle;
    table[0x34] = uds_34_handle;
    table[0x36] = uds_36_handle;
    table[0x37] = uds_37_handle;
    
    printk("UDS services registered\n");
}

void uds_init(void)
{
    isotp_init();
    uds_session_init();
    dtc_manager_init();

    uds_register_builtin_services((void **)service_table);
    printk("UDS server initialized\n");
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
        if (rsp_len > 0) {
            isotp_send(rsp_buf, rsp_len);
        }
    } else {
        // Service not supported - send negative response
        rsp_buf[0] = 0x7F;
        rsp_buf[1] = sid;
        rsp_buf[2] = 0x11; // serviceNotSupported
        rsp_len = 3;
        isotp_send(rsp_buf, rsp_len);
    }
}

void uds_handle_request(uint8_t *req, int len, void *context)
{
    // This is called by comm_manager
    // We handle it in uds_process instead
    (void)req;
    (void)len;
    (void)context;
}
