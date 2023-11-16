# Tailscale Utilities
Here you can find decriptions and instructions for each provided utility
## setup-tailscale.sh
### Description
Quickly set up and run Tailscale client and/or DERP server

### How to run
Run following command(s) and follow the instructions
```
curl -fsSL https://raw.githubusercontent.com/mindbox-cloud/main/tailscale-setup.sh | sudo bash
```
or
```
curl -fsSL https://raw.githubusercontent.com/mindbox-cloud/main/tailscale-setup.sh > tailscale-setup.sh
chmod +x tailscale-setup.sh
sudo ./tailscale-setup.sh
```
### Additional configuration
You can use environment variables to automate installation process:
- `INSTALL_MODE` - Components to install
    - 1 = Tailscale only
    - 2 = DERP only
    - 3 = Tailscale + DERP
- `TS_AUTH_TOKEN` - Authentication token a.k.a. Preauth key
- `TS_HOSTNAME` - Hostname to use in Tailscale network
- `TS_LOGIN_SERVER` - Login server for Tailscale (e.g. `https://controlplane.tailscale.com`)
- `DERP_DOMAIN` - Hostname that DERP will run on and obtain its certificate
- `DERP_ENV_FILE` - (optional) location of DERP service's variables
    - Default value: `/etc/default/derper`

Usage example:
```
INSTALL_MODE=3 \
TS_AUTH_TOKEN=abcdef1234 \
TS_HOSTNAME=derp-node-a1 \
TS_LOGIN_SERVER=https://ts.example.com \
DERP_DOMAIN=derp-a1.example.com \
sudo ./tailscale-setup.sh
```
This will install Tailscale and DERP
