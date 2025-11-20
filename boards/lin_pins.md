# LIN Master Pin Configuration

## Hardware

- **Board:** NXP FRDM-K64F
- **MCU:** Kinetis K64
- **LIN Transceiver:** External, connected to UART3 TX/RX

## Pin Mapping

| Function        | MCU Pin | LIN Signal |
|-----------------|---------|------------|
| LIN_TX          | PTB17   | LIN Bus TX |
| LIN_RX          | PTB16   | LIN Bus RX |
| LIN_GND         | GND     | LIN Ground |
| LIN_VBAT        | 5V      | LIN Vcc    |

## Notes

- UART3 configured at **19200 baud** (typical LIN speed)
- Use external 5V LIN transceiver like **TJA1020**
- Timer-based schedule controls frame timing (k_timer)
- Ensure proper termination resistor (120Ω) at LIN bus ends
