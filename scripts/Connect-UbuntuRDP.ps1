#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

############################################################
# KONFIGURACJA
############################################################

# Tailscale
$TAILSCALE_AUTHKEY = ""                # opcjonalnie; jeśli puste, logowanie będzie interaktywne
$TAILSCALE_DOWNLOAD_URL = "https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi"
$TAILSCALE_MSI_PATH = "$env:TEMP\tailscale-setup-latest-amd64.msi"

# Host Ubuntu
$HOST_TAILSCALE_IP = "100.78.85.118"   # zpk-darwina-ai
$HOST_TAILSCALE_DNS = "zpk-darwina-ai" # MagicDNS (opcjonalnie)
$RDP_PORT = 3389

# Połączenie RDP
$RDP_USERNAME = ""                     # np. jan
$PROMPT_FOR_PASSWORD = $true           # mstsc i tak zwykle pyta / zapisuje po swojemu
$RDP_WIDTH = 1920
$RDP_HEIGHT = 1080
$RDP_USE_MULTIMON = $false
$RDP_FULL_SCREEN = $false
$RDP_ADMIN_SESSION = $false            # dla Windows hostów byłoby /admin, tutaj zwykle false

# Lokalny plik RDP
$RDP_FILE_PATH = "$env:TEMP\ubuntu-remote-auto.rdp"

############################################################
# KONIEC KONFIGURACJI
############################################################

function Write-Info($msg)  { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg)  { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Test-Admin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Assert-Admin {
    if (-not (Test-Admin)) {
        throw "Uruchom PowerShell jako Administrator."
    }
}

function Get-TailscaleExe {
    $possible = @(
        "$env:ProgramFiles\Tailscale\tailscale.exe",
        "$env:ProgramFiles(x86)\Tailscale\tailscale.exe"
    )
    foreach ($p in $possible) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Install-Tailscale {
    $tsExe = Get-TailscaleExe
    if ($tsExe) {
        Write-Info "Tailscale jest już zainstalowany: $tsExe"
        return
    }

    Write-Info "Pobieram Tailscale MSI..."
    Invoke-WebRequest -Uri $TAILSCALE_DOWNLOAD_URL -OutFile $TAILSCALE_MSI_PATH

    if (-not (Test-Path $TAILSCALE_MSI_PATH)) {
        throw "Nie udało się pobrać instalatora Tailscale."
    }

    Write-Info "Instaluję Tailscale..."
    $arguments = "/i `"$TAILSCALE_MSI_PATH`" /qn /norestart TS_NOLAUNCH=1"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        throw "Instalacja Tailscale nie powiodła się. Kod wyjścia: $($process.ExitCode)"
    }

    Start-Sleep -Seconds 3

    $tsExe = Get-TailscaleExe
    if (-not $tsExe) {
        throw "Tailscale niby się zainstalował, ale nie widzę tailscale.exe"
    }

    Write-Info "Tailscale zainstalowany poprawnie."
}

function Start-TailscaleServiceIfNeeded {
    $svc = Get-Service -Name "Tailscale" -ErrorAction SilentlyContinue
    if (-not $svc) {
        throw "Usługa Tailscale nie istnieje po instalacji."
    }

    if ($svc.Status -ne "Running") {
        Write-Info "Uruchamiam usługę Tailscale..."
        Start-Service -Name "Tailscale"
        Start-Sleep -Seconds 2
    }

    $svc.Refresh()
    if ($svc.Status -ne "Running") {
        throw "Usługa Tailscale nie działa."
    }
}

function Connect-Tailscale {
    $tsExe = Get-TailscaleExe
    if (-not $tsExe) {
        throw "Brak tailscale.exe"
    }

    Write-Info "Sprawdzam status Tailscale..."
    $statusOutput = & $tsExe status 2>&1 | Out-String

    if ($statusOutput -match "Logged out" -or $statusOutput -match "Needs login" -or $statusOutput -match "No state") {
        if ([string]::IsNullOrWhiteSpace($TAILSCALE_AUTHKEY)) {
            Write-Warn "Brak TAILSCALE_AUTHKEY - uruchamiam logowanie interaktywne."
            & $tsExe up
        } else {
            Write-Info "Łączę klienta do tailnetu przy użyciu auth key..."
            & $tsExe up --auth-key=$TAILSCALE_AUTHKEY
        }
    } else {
        Write-Info "Tailscale wygląda na już zalogowany."
    }

    Start-Sleep -Seconds 3
}

function Resolve-HostAddress {
    if (-not [string]::IsNullOrWhiteSpace($HOST_TAILSCALE_IP)) {
        return $HOST_TAILSCALE_IP
    }

    if (-not [string]::IsNullOrWhiteSpace($HOST_TAILSCALE_DNS)) {
        try {
            $resolved = Resolve-DnsName -Name $HOST_TAILSCALE_DNS -ErrorAction Stop |
                Where-Object { $_.Type -eq "A" } |
                Select-Object -First 1 -ExpandProperty IPAddress
            if ($resolved) {
                return $resolved
            }
        } catch {
            Write-Warn "Nie udało się rozwiązać DNS hosta: $HOST_TAILSCALE_DNS"
        }
    }

    throw "Nie podałeś HOST_TAILSCALE_IP ani działającego HOST_TAILSCALE_DNS."
}

function Test-HostReachability {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address
    )

    Write-Info "Testuję łączność z hostem $Address ..."
    $ping = Test-NetConnection -ComputerName $Address -Port $RDP_PORT -InformationLevel Detailed

    if (-not $ping.TcpTestSucceeded) {
        throw "Host nie odpowiada na porcie RDP $RDP_PORT przez Tailscale."
    }

    Write-Info "Port RDP odpowiada."
}

function New-RdpFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address
    )

    $fullAddress = "$Address`:$RDP_PORT"
    $screenModeId = if ($RDP_FULL_SCREEN) { 2 } else { 1 }
    $useMultimon = if ($RDP_USE_MULTIMON) { 1 } else { 0 }
    $adminSession = if ($RDP_ADMIN_SESSION) { 1 } else { 0 }

    $rdpLines = @(
        "screen mode id:i:$screenModeId"
        "use multimon:i:$useMultimon"
        "desktopwidth:i:$RDP_WIDTH"
        "desktopheight:i:$RDP_HEIGHT"
        "session bpp:i:32"
        "full address:s:$fullAddress"
        "prompt for credentials:i:1"
        "administrative session:i:$adminSession"
        "autoreconnection enabled:i:1"
        "redirectclipboard:i:1"
        "redirectprinters:i:0"
        "redirectcomports:i:0"
        "redirectsmartcards:i:0"
        "redirectwebauthn:i:0"
        "redirectposdevices:i:0"
        "redirectdirectx:i:1"
        "drivestoredirect:s:"
        "audiocapturemode:i:0"
        "audiomode:i:0"
        "authentication level:i:2"
        "enablecredsspsupport:i:1"
        "negotiate security layer:i:1"
    )

    if (-not [string]::IsNullOrWhiteSpace($RDP_USERNAME)) {
        $rdpLines += "username:s:$RDP_USERNAME"
    }

    Set-Content -Path $RDP_FILE_PATH -Value $rdpLines -Encoding ASCII
    Write-Info "Wygenerowano plik RDP: $RDP_FILE_PATH"
}

function Start-Rdp {
    if (-not (Test-Path $RDP_FILE_PATH)) {
        throw "Brakuje pliku RDP: $RDP_FILE_PATH"
    }

    Write-Info "Uruchamiam mstsc.exe..."
    Start-Process -FilePath "$env:SystemRoot\System32\mstsc.exe" -ArgumentList "`"$RDP_FILE_PATH`""
}

function Main {
    Assert-Admin
    Install-Tailscale
    Start-TailscaleServiceIfNeeded
    Connect-Tailscale

    $address = Resolve-HostAddress
    Test-HostReachability -Address $address
    New-RdpFile -Address $address
    Start-Rdp

    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host " GOTOWE - uruchomiono połączenie RDP" -ForegroundColor Green
    Write-Host " Host: $address`:$RDP_PORT" -ForegroundColor Green
    Write-Host "===============================================" -ForegroundColor Green
}

Main