# Tailscale Utilities
Here you can find decriptions and instructions for each provided utility

## tailscale-setup.sh
### Description
Quickly set up and run Tailscale client and/or DERP server

Actual installation scirpt for Tailscale [provided by Tailscale](https://tailscale.com/kb/1031/install-linux/)

### How to run
Run following command(s) and follow the instructions
```sh
curl -fsSL https://raw.githubusercontent.com/mindbox-cloud/tailscale-utils/main/tailscale-setup.sh | sudo bash
```
or
```sh
curl -fsSL https://raw.githubusercontent.com/mindbox-cloud/tailscale-utils/main/tailscale-setup.sh > tailscale-setup.sh
chmod +x tailscale-setup.sh
sudo ./tailscale-setup.sh
```
### Additional configuration
You can use environment variables to automate installation process:
- `INSTALL_MODE` - Components to install
    - 1 = Tailscale only
    - 2 = DERP only
    - 3 = Tailscale + DERP
- `USE_DEFAULT_VALS` - Set to `1` to skip prompts for optional variables and use default values
- `TS_AUTH_TOKEN` - Authentication token a.k.a. Preauth key
- `TS_HOSTNAME` - Hostname to use in Tailscale network
- `TS_LOGIN_SERVER` - Login server for Tailscale (e.g. `https://controlplane.tailscale.com`)
- `TS_ACCEPT_ROUTES` - Set to `1` to accept routes from peers when connection to Tailscale (optional, default: `1`)
- `TS_ACCEPT_DNS` - Set to `1` to accept DNS from Tailscale (optional, default: `1`)
- `TS_UP_ARGS` - Additional arguments when connecting to Tailscale (optional, e.g. `--advertise-tags=tag:derp`)
- `TS_UP_SKIP` - Set to `1` if you want to join Tailnet manually
- `TS_ADVERTISE_ROUTES` - Comma-separated list of CIDRs to advertise as routes (optional, e.g. `192.168.0.0/24,192.168.1.0/24`)
- `TS_PKGS_DOMAIN` - Domain name of mirror where Tailscale's packages hosted (optional, e.g. `ts-pkg.example.com`)
- `TS_TAGS` - Comma-separated list of advertised tags (optional, e.g. `vpn,mgmt`)
- `DERP_DOMAIN` - Hostname that DERP will run on and obtain its certificate
- `DERP_VERIFY_CLIENTS` - Whether to verify clients connecting to node. Works only if Tailscale is installed (optional, default: `1`)
- `DERP_HTTP_PORT` - HTTP port for DERP to use (optional, default: `80`)
- `DERP_HTTPS_PORT` - HTTP port for DERP to use (optional, default: `443`)
- `DERP_STUN_PORT` - STUN port (optional, default: `3878`)
- `DERP_ENV_FILE` - Location of DERP service's variables (optional, default: `/etc/default/derper`)
- `DERP_ARGS` - Additional arguments for DERP (optional, e.g. `--stun=false`)

Usage example:
```sh
INSTALL_MODE=3 \
USE_DEFAULT_VALS=1 \
TS_AUTH_TOKEN=abcdef1234 \
TS_HOSTNAME=derp-node-a1 \
TS_LOGIN_SERVER=https://ts.example.com \
DERP_DOMAIN=derp-a1.example.com \
sudo -E ./tailscale-setup.sh
```
This will install Tailscale and DERP

## tailscale-setup.ps1
### Description
Windows counterpart for tailscale-setup.sh.

**Please note that this script doen't support interactive mode and DERP setup!**

### How to run

Command below will download and launch script
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/mindbox-cloud/tailscale-utils/main/tailscale-setup.ps1" -OutFile "tailscale-setup.ps1";
.\tailscale-setup.ps1 `
-TsLoginServer "https://ts.example.com" `
-TsAuthKey "abcdef1234" `
-TsAcceptDns 0 `
-TsAcceptRoutes 0
```

### Additional configuration
You can use arguments to configure how script will work.

You may use `Get-Help` to get help on how to use arguments (e.g. `Get-Help .\tailscale-setup.ps1 -Detailed`)