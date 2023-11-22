$downloadUrl =
if ($env:TS_DL_URL) { 
    $env:VAR1 
}
else { 
    "https://pkgs.tailscale.com/stable/tailscale-setup-1.54.0-amd64.msi" 
}
$tempFolder = [System.IO.Path]::GetTempPath()
$fileName = "ts_setup.msi"
$destinationPath = Join-Path $tempFolder $fileName

echo "Downloading Tailscale setup package"
Invoke-WebRequest -Uri $downloadUrl -OutFile $destinationPath

$args = "/i `"$destinationPath`" /qn"
$args += " TS_UNATTENDEDMODE=always"
$args += " TS_ALLOWINCOMINGCONNECTIONS=always"

echo "Installing Tailscale"
Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait

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

echo "Joining Tailnet"
tailscale.exe $args

$args = "set"
$args += " --auto-update=true"

echo "Enabling auto updates"
tailscale.exe $args