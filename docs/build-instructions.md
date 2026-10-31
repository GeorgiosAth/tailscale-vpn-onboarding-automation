\# Build Instructions — PowerShell to Windows EXE



\## 1. Overview



This document explains how to package the Tailscale VPN onboarding PowerShell script into a Windows executable using PS2EXE.



The resulting executable provides a convenient way to launch the onboarding utility on Windows workstations without manually opening the PowerShell source file.



PS2EXE packages the PowerShell script into an executable wrapper. It does not provide strong code obfuscation, encryption, or protection for embedded credentials.



\## 2. Prerequisites



Before building the executable, ensure that the workstation has:



\- Windows PowerShell 5.1 or a compatible PowerShell environment.

\- Access to the project source code.

\- The PS2EXE PowerShell module.

\- Appropriate permissions to install modules and run the build commands.



The target workstation must have the Tailscale client installed for the onboarding workflow to operate.



\## 3. Project Directory



Run the following commands from the repository root:



```text

tailscale-vpn-onboarding-automation/

├── README.md

├── .gitignore

├── src/

│   └── Enroll-to-Tailscale.ps1

├── docs/

│   ├── implementation.md

│   └── build-instructions.md

└── dist/

&#x20;   └── Enroll-to-Tailscale.exe

```



The `dist` folder contains generated output and should not be committed to the repository.



\## 4. Prepare the PowerShell Session



If the current session blocks the required scripts, the following command can temporarily permit execution within that PowerShell process:



```powershell

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

```



This setting applies only to the current PowerShell process and does not permanently change the system-wide execution policy.



Use it only in an appropriately authorized environment. Organizational policies may still restrict script execution.



\## 5. Install PS2EXE



Install the PS2EXE module for the current user:



```powershell

Install-Module -Name ps2exe -Scope CurrentUser

```



This installation normally needs to be performed only once for the applicable PowerShell environment.



Review module trust and publisher information before installation.



\## 6. Create the Output Directory



From the repository root, create the build output directory:



```powershell

New-Item -ItemType Directory -Path .\\dist -Force

```



The `-Force` parameter allows the command to work when the folder already exists.



\## 7. Build the Executable



Execute:



```powershell

Invoke-ps2exe `

&#x20;   -inputFile ".\\src\\Enroll-to-Tailscale.ps1" `

&#x20;   -outputFile ".\\dist\\Enroll-to-Tailscale.exe" `

&#x20;   -requireAdmin `

&#x20;   -noConsole `

&#x20;   -title "VPN Device Onboarding" `

&#x20;   -product "VPN Device Onboarding"

```



\### Build Parameters



| Parameter | Purpose |

|---|---|

| `-inputFile` | Specifies the PowerShell source file. |

| `-outputFile` | Specifies the resulting executable location. |

| `-requireAdmin` | Requests administrator elevation when the executable starts. |

| `-noConsole` | Builds the application without the usual visible PowerShell console. |

| `-title` | Sets the executable's descriptive title. |

| `-product` | Sets its product metadata. |



\## 8. Verify the Build Output



After compilation, check that the executable exists:



```powershell

Test-Path .\\dist\\Enroll-to-Tailscale.exe

```



An output of `True` confirms that a file exists at the expected location. It does not prove that the application's functionality has been tested.



\## 9. Testing Requirements



Before using a newly built version in production:



1\. Validate the PowerShell syntax.

2\. Verify that the authentication dialog displays correctly.

3\. Confirm that empty or invalid authentication inputs are handled appropriately.

4\. Test the executable in a controlled Windows environment.

5\. Verify the expected Tailscale enrollment behavior.

6\. Confirm device authorization and connectivity in the Tailscale administration console.

7\. Check temporary credential cleanup and relevant filesystem permissions.



The updated runtime authentication-input version has passed initial dialog tests but has not yet completed the full end-to-end enrollment validation.



\## 10. Security Considerations



\- Never place a real Tailscale Auth Key directly in the public source code.

\- Never include production keys in documentation or screenshots.

\- Never assume that PS2EXE protects embedded secrets.

\- Restrict access to any generated executable distributed internally.

\- Use authentication keys that follow the organization's validity, scope, and approval policies.

\- Remove deployment artifacts from target machines when they are no longer required.

\- Keep build outputs out of version control.



The current source handles authentication material temporarily during enrollment, including the use of a temporary local file. Additional hardening of this mechanism is recommended before production deployment.



\## 11. Version Control



The repository's `.gitignore` excludes generated `.exe` files, so the compiled executable is not intended to be tracked by Git.



Before committing changes, inspect the staged files and confirm that no credentials or confidential configuration values are included.



\## 12. Conclusion



This workflow provides a repeatable way to package a PowerShell-based Tailscale onboarding utility into a Windows executable, while keeping source code, documentation, and generated binaries separated.