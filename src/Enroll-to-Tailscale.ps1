#requires -Version 5.1

<#
Enroll-to-Tailscale.ps1

Purpose:
- Registers a Windows laptop in a Tailscale tailnet with an embedded reusable auth key.
- Keeps Tailscale running in unattended mode.
- Waits for manual device approval when device approval is enabled.

Before compiling:
1. Replace the AUTH KEY value below.
2. Keep ForceReauthentication = $false unless you intentionally want to replace
   an existing Tailscale login on the laptop.
3. Compile the script as an administrator-required EXE.

Important:
The auth key is embedded in the script/EXE and can be extracted by someone who
obtains the file. Use a restricted, tagged auth key where possible, keep the EXE
under your control, and revoke the key if the EXE or USB drive is lost.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =========================
# CONFIGURATION
# =========================

# The administrator provides the auth key at runtime.
# No auth key is embedded in the source code or compiled executable.
$AuthKey = $null

# Keep false for normal provisioning.
# Set true only when the laptop is already signed into another tailnet and you
# intentionally want to replace that existing Tailscale authentication.
$ForceReauthentication = $false

# How long the program should wait for you to approve the device.
$ApprovalWaitMinutes = 15

# Use the Windows computer name as the device name shown in Tailscale.
$DeviceHostname = $env:COMPUTERNAME

# =========================
# USER INTERFACE
# =========================

Add-Type -AssemblyName System.Windows.Forms


function Read-TailscaleAuthKey {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Tailscale VPN Enrollment"
    $form.Size = New-Object System.Drawing.Size(420, 170)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Enter the Tailscale Auth Key:"
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.AutoSize = $true
    $form.Controls.Add($label)

    $inputBox = New-Object System.Windows.Forms.TextBox
    $inputBox.Location = New-Object System.Drawing.Point(20, 50)
    $inputBox.Width = 365
    $inputBox.UseSystemPasswordChar = $true
    $form.Controls.Add($inputBox)

    $button = New-Object System.Windows.Forms.Button
    $button.Text = "Connect"
    $button.Location = New-Object System.Drawing.Point(155, 85)
    $button.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($button)
    $form.AcceptButton = $button

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $inputBox.Text.Trim()
    }

    return $null
}




function Show-Dialog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Title = "Tailscale Company VPN",

        [System.Windows.Forms.MessageBoxIcon]$Icon =
            [System.Windows.Forms.MessageBoxIcon]::Information
    )

    [void][System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $Icon
    )
}

# =========================
# HELPERS
# =========================

function Test-IsAdministrator {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [System.Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Find-TailscaleExecutable {
    $command = Get-Command "tailscale.exe" -ErrorAction SilentlyContinue

    if ($null -ne $command -and $command.Source) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles "Tailscale\tailscale.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Tailscale\tailscale.exe")
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }

    return $null
}

function Get-TailscaleStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TailscaleExecutable
    )

    try {
        $json = (
            & $TailscaleExecutable status --json 2>$null |
                Out-String
        ).Trim()

        if ([string]::IsNullOrWhiteSpace($json)) {
            return $null
        }

        return $json | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-BackendState {
    param($Status)

    if ($null -eq $Status) {
        return $null
    }

    $property = $Status.PSObject.Properties["BackendState"]

    if ($null -eq $property) {
        return $null
    }

    return [string]$property.Value
}

function Get-TailnetName {
    param($Status)

    if ($null -eq $Status) {
        return $null
    }

    $tailnetProperty = $Status.PSObject.Properties["CurrentTailnet"]

    if ($null -eq $tailnetProperty -or $null -eq $tailnetProperty.Value) {
        return $null
    }

    $nameProperty = $tailnetProperty.Value.PSObject.Properties["Name"]

    if ($null -eq $nameProperty) {
        return $null
    }

    return [string]$nameProperty.Value
}

function Show-Connected {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TailscaleExecutable,

        [Parameter(Mandatory = $true)]
        [string]$Hostname
    )

    $status = Get-TailscaleStatus -TailscaleExecutable $TailscaleExecutable
    $tailnetName = Get-TailnetName -Status $status

    $tailscaleIp = $null

    try {
        $tailscaleIp = (
            & $TailscaleExecutable ip -4 2>$null |
                Select-Object -First 1
        )
    }
    catch {
        $tailscaleIp = $null
    }

    $message = "The laptop is connected to Tailscale successfully.`n`n" +
               "Device name: $Hostname"

    if (-not [string]::IsNullOrWhiteSpace($tailnetName)) {
        $message += "`nTailnet: $tailnetName"
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$tailscaleIp)) {
        $message += "`nTailscale IP: $tailscaleIp"
    }

    Show-Dialog -Message $message `
                -Icon ([System.Windows.Forms.MessageBoxIcon]::Information)
}

# =========================
# MAIN
# =========================

try {
    if (-not (Test-IsAdministrator)) {
        Show-Dialog `
            -Message (
                "Administrator permission is required.`n`n" +
                "Right-click the script and choose 'Run as administrator', " +
                "or compile the EXE with the require-admin option."
            ) `
            -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)

        exit 1
    }

    $AuthKey = Read-TailscaleAuthKey

    if (
        [string]::IsNullOrWhiteSpace($AuthKey) -or
        $AuthKey -notmatch "^tskey-auth-"
    ) {
        Show-Dialog `
            -Message (
                "Invalid or missing Tailscale Auth Key.`n`n" +
                "They key must start with 'tskey-auth-'."
            ) `
            -Icon ([System.Windows.Forms.MessageBoxIcon]::Error)

        exit 2
    }

    $tailscaleExe = Find-TailscaleExecutable

    if ([string]::IsNullOrWhiteSpace($tailscaleExe)) {
        Show-Dialog `
            -Message (
                "Tailscale is not installed on this laptop, or tailscale.exe " +
                "could not be found.`n`nInstall Tailscale first, then run this " +
                "program again."
            ) `
            -Icon ([System.Windows.Forms.MessageBoxIcon]::Error)

        exit 3
    }

    $service = Get-Service -Name "Tailscale" -ErrorAction SilentlyContinue

    if ($null -ne $service -and $service.Status -ne "Running") {
        Start-Service -Name "Tailscale"
        Start-Sleep -Seconds 2
    }

    $initialStatus = Get-TailscaleStatus -TailscaleExecutable $tailscaleExe
    $initialState = Get-BackendState -Status $initialStatus

    if ($initialState -eq "Running" -and -not $ForceReauthentication) {
        $currentTailnet = Get-TailnetName -Status $initialStatus

        $message = (
            "This laptop is already connected to Tailscale.`n`n" +
            "The program did not replace the existing login."
        )

        if (-not [string]::IsNullOrWhiteSpace($currentTailnet)) {
            $message += "`nCurrent tailnet: $currentTailnet"
        }

        $message += (
            "`n`nTo intentionally replace an existing login, set " +
            "ForceReauthentication to `$true before compiling."
        )

        Show-Dialog `
            -Message $message `
            -Icon ([System.Windows.Forms.MessageBoxIcon]::Information)

        exit 0
    }

    # The temporary file keeps the auth key out of the tailscale.exe command line.
    # The key is deleted immediately after the registration command returns.
    $temporaryKeyFile = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        ("tailscale-auth-" + [Guid]::NewGuid().ToString("N") + ".txt")

    $commandOutput = ""
    $commandExitCode = -1

    try {
        [System.IO.File]::WriteAllText(
            $temporaryKeyFile,
            $AuthKey,
            [System.Text.Encoding]::ASCII
        )

        $arguments = @(
            "up",
            "--auth-key=file:$temporaryKeyFile",
            "--unattended=true",
            "--hostname=$DeviceHostname",
            "--timeout=15s"
        )

        if ($ForceReauthentication) {
            $arguments += "--force-reauth"
        }

        $commandOutput = (
            & $tailscaleExe @arguments 2>&1 |
                Out-String
        ).Trim()

        $commandExitCode = $LASTEXITCODE
    }
    finally {
        if (Test-Path -LiteralPath $temporaryKeyFile) {
            Remove-Item -LiteralPath $temporaryKeyFile -Force `
                -ErrorAction SilentlyContinue
        }
    }

    # Never display the embedded key if it somehow appears in command output.
    $safeOutput = $commandOutput.Replace($AuthKey, "[REDACTED]")

    $status = Get-TailscaleStatus -TailscaleExecutable $tailscaleExe
    $state = Get-BackendState -Status $status

    if ($state -eq "Running") {
        Show-Connected `
            -TailscaleExecutable $tailscaleExe `
            -Hostname $DeviceHostname

        exit 0
    }

    if (
        $safeOutput -match
        "(?i)invalid key|key.*expired|key.*revoked|not valid|already used"
    ) {
        Show-Dialog `
            -Message (
                "Tailscale rejected the auth key.`n`n" +
                "Confirm that the key is reusable, has not expired, and has " +
                "not been revoked.`n`nTailscale response:`n$safeOutput"
            ) `
            -Icon ([System.Windows.Forms.MessageBoxIcon]::Error)

        exit 4
    }

    Show-Dialog `
        -Message (
            "The laptop has been submitted to your tailnet.`n`n" +
            "Device name to approve: $DeviceHostname`n`n" +
            "On your main/admin laptop, open the Tailscale admin console, " +
            "go to Machines, and approve this device.`n`n" +
            "After closing this message, the program will automatically " +
            "wait for approval for up to $ApprovalWaitMinutes minutes."
        ) `
        -Icon ([System.Windows.Forms.MessageBoxIcon]::Information)

    $deadline = (Get-Date).AddMinutes($ApprovalWaitMinutes)

    do {
        Start-Sleep -Seconds 3

        $status = Get-TailscaleStatus -TailscaleExecutable $tailscaleExe
        $state = Get-BackendState -Status $status

        if ($state -eq "Running") {
            Show-Connected `
                -TailscaleExecutable $tailscaleExe `
                -Hostname $DeviceHostname

            exit 0
        }
    }
    while ((Get-Date) -lt $deadline)

    $details = ""

    if (-not [string]::IsNullOrWhiteSpace($safeOutput)) {
        $details = "`n`nInitial Tailscale response:`n$safeOutput"
    }

    Show-Dialog `
        -Message (
            "The laptop was not connected within $ApprovalWaitMinutes " +
            "minutes.`n`nVerify that:`n" +
            "- The device '$DeviceHostname' was approved.`n" +
            "- The auth key is reusable and still valid.`n" +
            "- The laptop has internet access.`n" +
            "- The Tailscale service is running." +
            $details
        ) `
        -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)

    exit 5
}
catch {
    $errorMessage = $_.Exception.Message

    if (-not [string]::IsNullOrWhiteSpace($AuthKey)) {
        $errorMessage = $errorMessage.Replace($AuthKey, "[REDACTED]")
    }

    Show-Dialog `
        -Message ("Unexpected error:`n`n" + $errorMessage) `
        -Icon ([System.Windows.Forms.MessageBoxIcon]::Error)

    exit 99
}