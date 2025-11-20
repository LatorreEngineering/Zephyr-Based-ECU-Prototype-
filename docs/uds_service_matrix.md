# UDS Service Matrix

| SID  | Service Name                     | Description                              | Positive Response |
|------|---------------------------------|------------------------------------------|-----------------|
| 0x10 | Diagnostic Session Control       | Switch ECU diagnostic session             | 0x50            |
| 0x11 | ECU Reset                        | Reset ECU                                 | 0x51            |
| 0x14 | Clear DTC                        | Clear all diagnostic trouble codes        | 0x54            |
| 0x19 | Read DTC                         | Read active DTCs                           | 0x59            |
| 0x22 | Read Data By Identifier (DID)    | Read sensor or ECU parameters             | 0x62            |
| 0x23 | Write Data By Identifier (DID)   | Write ECU parameters                       | 0x63            |
| 0x27 | Security Access                  | Seed/key authentication                   | 0x67            |
| 0x28 | Communication Control            | Control communication session             | 0x68            |
| 0x2E | Write Data By Identifier          | Another DID write                         | 0x6E            |
| 0x31 | Routine Control                  | Start/stop routines                        | 0x71            |
| 0x34 | Request Download                  | Prepare ECU for flashing                  | 0x74            |
| 0x36 | Transfer Data                     | Send firmware blocks                       | 0x76            |
| 0x37 | Transfer Exit                     | End firmware transfer                       | 0x77            |
