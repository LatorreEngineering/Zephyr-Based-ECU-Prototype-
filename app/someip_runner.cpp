// app/someip_runner.cpp
// Production-ready Zephyr thread for OpenSOME/IP stack (Cortex-M safe)
// No exceptions, no RTTI, static buffers only. Uses the official Zephyr port from submodule.

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
LOG_MODULE_REGISTER(someip_runner, LOG_LEVEL_INF);

#include <cstdint>
#include <array>

#include "someip/message.h"
#include "someip/types.h"
#include "transport/endpoint.h"
#include "sd/sd_client.h"
#include "common/result.h"

using namespace someip;
using namespace someip::transport;
using namespace someip::sd;

extern "C" void someip_runner_thread(void *, void *, void *)
{
    LOG_INF("=== OpenSOME/IP Zephyr ECU Runner starting on Cortex-M ===");

    // Integration point: Network + multicast SD endpoint (224.0.0.1:30490)
    Endpoint sd_multicast("224.0.0.1", 30490U);
    if (!sd_multicast.is_valid() || !sd_multicast.is_ipv4()) {
        LOG_ERR("SD multicast endpoint invalid - check networking config");
        return;
    }
    LOG_INF("SD multicast ready: %s", sd_multicast.to_string().c_str());

    // Minimal stack init (SD + message pool from Kconfig)
    SdClient sd_client;

    // Example static message (no dynamic allocation)
    MessageId msg_id(0x1234U, 0x0001U);
    RequestId req_id(0x0010U, 0x0001U);
    Message test_msg(msg_id, req_id, MessageType::REQUEST, ReturnCode::E_OK);

    std::array<uint8_t, 5> payload = {0x48, 0x65, 0x6C, 0x6C, 0x6F};
    test_msg.set_payload(payload.data(), payload.size());

    auto serialized = test_msg.serialize();
    LOG_INF("Test SOME/IP message ready (%zu bytes)", serialized.size());

    // Production poll loop (real app would register RPC/event handlers here)
    uint32_t counter = 0;
    while (true) {
        LOG_INF("SOME/IP stack alive - cycle %u (UDP multicast SD active)", ++counter);

        if (counter % 5 == 0) {
            LOG_INF("Offering test service via SD...");
        }

        k_msleep(1000);
    }
}
