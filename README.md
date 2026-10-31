\# Tailscale VPN Device Onboarding Automation with PowerShell



\## Overview



This project presents a PowerShell-based automation tool designed to simplify the onboarding of Windows devices to a corporate Tailscale VPN.



The tool was developed to address a recurring IT administration challenge: enrolling company laptops into the VPN required an interactive authentication process that depended on access to a specific authentication device.



This occasionally caused significant delays during workstation setup.



The solution streamlines the enrollment process through a Windows-based utility while retaining administrative control over device approval.



\## Technologies



\- PowerShell 5.1+

\- Tailscale VPN \& CLI

\- Windows Forms

\- Windows Services

\- JSON-based status inspection

\- PS2EXE

\- Git \& GitHub



\## Problem



The previous onboarding process depended on manual authentication and access to a one-time verification method.



When the authentication device was unavailable, VPN enrollment could be delayed, sometimes by up to 30 minutes.



The objective was to develop a lightweight utility that would:



\- Reduce repetitive manual authentication steps.

\- Simplify Windows device onboarding.

\- Support unattended Tailscale operation.

\- Preserve administrator-controlled device approval.

\- Provide clear feedback during enrollment.



\## Solution



The PowerShell utility automates the main enrollment workflow.



It performs the following operations:



1\. Verifies administrator privileges.

2\. Locates the installed Tailscale executable.

3\. Checks and starts the Tailscale Windows service when necessary.

4\. Detects an existing active Tailscale connection.

5\. Accepts a Tailscale Auth Key through a Windows Forms dialog.

6\. Initiates device enrollment using the Tailscale CLI.

7\. Enables unattended operation.

8\. Monitors the connection state while awaiting administrator approval.

9\. Displays connection information or diagnostic messages.



The application uses the Windows computer name as the default Tailscale device hostname.



\## Authentication Key Handling



The initial implementation used an embedded Tailscale Auth Key.



The updated version introduces runtime key input through a masked Windows Forms field.



This separates the authentication credential from the distributed source code and avoids recompiling the executable solely to change the key.



The Auth Key is handled temporarily during enrollment and is not stored as a constant in the updated source code.



\*\*Security note:\*\* Runtime entry reduces exposure from embedded credentials, but does not eliminate all credential-handling risks. Authentication keys must be protected, and device approval should remain enabled where required by organizational policy.



\## Validation



The updated version has undergone the following checks:



| Test | Result |

|---|---|

| PowerShell syntax parsing | Passed |

| Windows Forms dialog initialization | Passed |

| Empty input handling | Passed |

| Nonempty test input handling | Passed |

| Git source review for embedded credentials | Passed |

| Full end-to-end enrollment with updated version | Not yet tested |



The tool's original production workflow was used operationally, while the updated runtime-authentication version still requires end-to-end validation before production deployment.



\## Project Structure



```text

tailscale-vpn-onboarding-automation/

├── README.md

├── .gitignore

├── src/

│   └── Enroll-to-Tailscale.ps1

└── docs/

&#x20;   ├── implementation.md

&#x20;   └── build-instructions.md

```



\## Source Code



The PowerShell implementation is available at:



\[Enroll-to-Tailscale.ps1](src/Enroll-to-Tailscale.ps1)



The script is provided as a technical example and requires a valid Tailscale environment, appropriate administrative permissions, and organization-specific configuration.



\## Documentation



\- \[Implementation Guide](docs/implementation.md)

\- \[Executable Build Instructions](docs/build-instructions.md)



\## Security \& Confidentiality



This repository does not intentionally include production authentication keys, credentials, private infrastructure identifiers, or production executables.



The published source is a sanitized portfolio version intended to demonstrate PowerShell automation, Windows administration, error handling, and VPN onboarding workflow design.



\## Future Improvements



\- Validate the complete enrollment workflow in a controlled test environment.

\- Improve authentication-key handling and temporary file permissions.

\- Add more precise tailnet and approval-state verification.

\- Expand error handling for failed or expired authentication credentials.

\- Introduce automated PowerShell tests.



\## Key Takeaway



This project demonstrates how a relatively small PowerShell utility can reduce operational friction in IT administration while maintaining administrator-controlled VPN device onboarding.

