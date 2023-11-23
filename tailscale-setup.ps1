$currentScript = $MyInvocation.MyCommand.Definition

# Create a new PowerShell process with administrator rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$currentScript`"" -Verb RunAs
    exit
}

function Get-VarOrDefault {
    param(
        $VarName,
        $DefVal
    )

    $envVarValue = [System.Environment]::GetEnvironmentVariable($VarName)

    if ([string]::IsNullOrWhiteSpace($envVarValue)) {
        [System.Environment]::SetEnvironmentVariable($VarName, $DefVal)
        return $DefVal
    } else {
        return $envVarValue
    }
}

$env:TS_DL_URL = Get-VarOrDefault "TS_DL_URL" "https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi"
$env:TS_UNATTENDED = Get-VarOrDefault "TS_UNATTENDED" "true"
$env:TS_ACCEPT_DNS = Get-VarOrDefault "TS_ACCEPT_DNS" "true"
$env:TS_ACCEPT_ROUTES = Get-VarOrDefault "TS_ACCEPT_ROUTES" "true"

$tempFolder = [System.IO.Path]::GetTempPath()
$fileName = "ts_setup.msi"
$destinationPath = Join-Path $tempFolder $fileName

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

echo "Downloading Tailscale setup package to `"$destinationPath`""
Invoke-WebRequest -Uri $env:TS_DL_URL -OutFile $destinationPath

$args = "/i `"$destinationPath`" /qn"
$args += " TS_UNATTENDEDMODE=always"
$args += " TS_ALLOWINCOMINGCONNECTIONS=always"

echo "Installing Tailscale"
Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait

Remove-Item -Path "$destinationPath" -Confirm:$false -Force

# We shall reload PATH to set up tailscale further
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$args = "up"
$args += " --login-server $env:TS_LOGIN_SERVER"
$args += " --auth-key $env:TS_AUTH_TOKEN"
$args += " --hostname $env:TS_HOSTNAME" 
$args += " --unattended=$env:TS_UNATTENDED"
$args += " --accept-dns=$env:TS_ACCEPT_DNS"
$args += " --accept-routes=$env:TS_ACCEPT_ROUTES"

if (![string]::IsNullOrWhiteSpace($env:TS_TAGS)) {
    $args += " --advertise-tags $env:TS_TAGS"
}

echo "Let me sleep for 10 seconds before continuing to ensure that Tailscale service has started"
Start-Sleep -s 10

echo "Joining Tailnet"
Start-Process -FilePath "tailscale.exe" -ArgumentList $args -Wait

$args = "set"
$args += " --auto-update=true"

echo "Enabling auto updates"
Start-Process -FilePath "tailscale.exe" -ArgumentList $args -Wait