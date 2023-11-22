$currentScript = $MyInvocation.MyCommand.Definition

# Create a new PowerShell process with administrator rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$currentScript`"" -Verb RunAs
    exit
}

$downloadUrl =
if ($env:TS_DL_URL) { 
    $env:TS_DL_URL 
}
else { 
    "https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi" 
}
$tempFolder = [System.IO.Path]::GetTempPath()
$fileName = "ts_setup.msi"
$destinationPath = Join-Path $tempFolder $fileName

echo "Downloading Tailscale setup package to `"$destinationPath`""
Invoke-WebRequest -Uri $downloadUrl -OutFile $destinationPath

$args = "/i `"$destinationPath`" /qn"
$args += " TS_UNATTENDEDMODE=always"
$args += " TS_ALLOWINCOMINGCONNECTIONS=always"

echo "Installing Tailscale"
Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait

Remove-Item -Path "$destinationPath" -Confirm

# We shall reload PATH to set up tailscale further
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$args = "up"
$args += " --login-server $env:TS_LOGIN_SERVER"
$args += " --auth-key $env:TS_AUTH_TOKEN"
$args += " --hostname $env:TS_HOSTNAME" 
$args += " --advertise-tags $env:TS_TAGS"
$args += " --unattended=true"
$args += " --accept-dns=false"
$args += " --accept-routes=false"

echo "Let me sleep for 10 seconds before continuing to ensure"
echo "that Tailscale service has started"
Start-Sleep -s 10

echo "Joining Tailnet"
Start-Process -FilePath "tailscale.exe" -ArgumentList $args -Wait

$args = "set"
$args += " --auto-update=true"

echo "Enabling auto updates"
Start-Process -FilePath "tailscale.exe" -ArgumentList $args -Wait