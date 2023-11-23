$currentScript = $MyInvocation.MyCommand.Definition

# Create a new PowerShell process with administrator rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$currentScript`"" -Verb RunAs
    exit
}

param(
    [string]$TsLoginServer = "https://controlplane.tailscale.com",
    [string]$TsAuthKey,
    [string]$TsHostname = [System.Net.Dns]::GetHostName(),
    [string]$TsPkgsDomain = "pkgs.tailscale.com",
    [string]$TsUpArgs,

    [string[]]$TsAdvertiseRoutes,
    [string[]]$TsTags,

    [bool]$TsUnattended = $true,
    [bool]$TsAcceptDns = $true,
    [bool]$TsAcceptRoutes = $true,
    [bool]$TsAutoUpdate = $true,
    [bool]$TsUpSkip = $false
)

$TsDlUrl = "https://$TsPkgsDomain/stable/tailscale-setup-latest-amd64.msi"

$tempFolder = [System.IO.Path]::GetTempPath()
$fileName = "ts_setup.msi"
$destinationPath = Join-Path $tempFolder $fileName

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

echo "Downloading Tailscale setup package to `"$destinationPath`""
Invoke-WebRequest -Uri $TsDlUrl -OutFile $destinationPath

# Probably should be allowed to configure via args
$args = "/i `"$destinationPath`" /qn"
$args += " TS_UNATTENDEDMODE=always"
$args += " TS_ALLOWINCOMINGCONNECTIONS=always"

echo "Installing Tailscale"
Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait
Remove-Item -Path "$destinationPath" -Confirm:$false -Force

# We shall reload PATH to set up tailscale further
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$args = "up $TsUpArgs"
$args += " --login-server $TsLoginServer"
$args += " --hostname $TsHostname" 
$args += " --unattended=$TsUnattended"
$args += " --accept-dns=$TsAcceptDns"
$args += " --accept-routes=$TsAcceptRoutes"

if (![string]::IsNullOrWhiteSpace($TsAuthKey)) {
    $args += " --auth-key $TsAuthKey"
}

if ($TsTags.Length -gt 0) {
    $tagsArr = $TsTags | ForEach-Object { "tag:$_" }
    $tags = $tagsArr -join ','

    $args += " --advertise-tags $tags"
}

if($TsAdvertiseRoutes.Length -gt 0) {
    $advRoutes = $TsAdvertiseRoutes -join ','

    $args += " --advertise-routes $advRoutes"
}

echo "Let me sleep for 10 seconds before continuing to ensure that Tailscale service has started"
Start-Sleep -s 10

echo "Joining Tailnet"
Start-Process -FilePath "tailscale.exe" -ArgumentList $args -Wait

$args = "set"
$args += " --auto-update=$TsAutoUpdate"
Start-Process -FilePath "tailscale.exe" -ArgumentList $args -Wait