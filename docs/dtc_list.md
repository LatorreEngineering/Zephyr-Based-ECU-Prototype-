# Diagnostic Trouble Codes (DTC) List

| DTC ID | Name                   | Description                  | Active Condition            |
|--------|------------------------|------------------------------|----------------------------|
| 0x01   | Over-Temperature       | Engine temp exceeds limit     | Temp > 100°C               |
| 0x02   | Low Voltage            | Supply voltage out of range   | Voltage < 11V              |
| 0x03   | High Voltage           | Supply voltage too high       | Voltage > 15V              |
| 0x04   | Sensor Failure         | Invalid sensor readings       | RPM, Temp, or Voltage sensor invalid |
| 0x05   | CAN Bus Error          | CAN transmission fault        | CAN send failure detected  |
| 0x06   | LIN Bus Error          | LIN transmission fault        | LIN slot not acknowledged  |
| 0x07   | ECU Reset Requested    | ECU requested reset           | Triggered via UDS 0x11     |
| 0x08   | Security Access Failed | Wrong seed/key attempt        | UDS 0x27 failed attempt     |
