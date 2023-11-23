param(
    [Parameter(HelpMessage="Tailscale Login Server")]
    [string]$TsLoginServer = "https://controlplane.tailscale.com",

    [Parameter(HelpMessage="Authentication key (a.k.a Preauth key)")]
    [string]$TsAuthToken,

    [Parameter(HelpMessage="Hostname to use in Tailscale network")]
    [string]$TsHostname = [System.Net.Dns]::GetHostName(),

    [Parameter(HelpMessage="Domain name of mirror where Tailscale's packages hosted (e.g. `ts-pkg.example.com`)")]
    [string]$TsPkgsDomain = "pkgs.tailscale.com",

    [Parameter(HelpMessage="Additional arguments when connecting to Tailscale")]
    [string]$TsUpArgs,

    [Parameter(HelpMessage="List of CIDRs to advertise as routes")]
    [string[]]$TsAdvertiseRoutes,

    [Parameter(HelpMessage="List of advertised tags")]
    [string[]]$TsTags,

    [Parameter(HelpMessage="Run in unattended mode where Tailscale keeps running even after the current user logs out")]
    [bool]$TsUnattended = $true,

    [Parameter(HelpMessage="Wheter to accept DNS from Tailscale")]
    [bool]$TsAcceptDns = $true,

    [Parameter(HelpMessage="Whether to accept routes from Tailscale")]
    [bool]$TsAcceptRoutes = $true,

    [Parameter(HelpMessage="Enable automatic updates")]
    [bool]$TsAutoUpdate = $true,

    [Parameter(HelpMessage="Wheter to skip automatic joining to Tailnet")]
    [bool]$TsUpSkip = $false
)

$currentScript = $MyInvocation.MyCommand.Definition

# Create a new PowerShell process with administrator rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$currentScript`"" -Verb RunAs
    exit
}

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

if ($TsUpSkip) {
    echo "TsUpSkip set to `"true`". You should join Tailnet manually"
    exit
}

$args = "up $TsUpArgs"
$args += " --login-server $TsLoginServer"
$args += " --hostname $TsHostname" 
$args += " --unattended=$TsUnattended"
$args += " --accept-dns=$TsAcceptDns"
$args += " --accept-routes=$TsAcceptRoutes"

if (![string]::IsNullOrWhiteSpace($TsAuthToken)) {
    $args += " --auth-key $TsAuthToken"
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