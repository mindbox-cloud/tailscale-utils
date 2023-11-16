#!/bin/bash

TS_AUTH_TOKEN=${TS_AUTH_TOKEN}
TS_HOSTNAME=${TS_HOSTNAME}
TS_LOGIN_SERVER=${TS_LOGIN_SERVER}
TS_UP_ARGS=${TS_UP_ARGS}

DERP_DOMAIN=${DERP_DOMAIN}
DERP_ENV_FILE=${DERP_ENV_FILE:-/etc/default/derper}

INSTALL_MODE=${INSTALL_MODE}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root!"
    exit 1
fi

echo "======================================"
echo "This script was tested on Ubuntu 22.04"
echo "Maintainer: kulev@mindbox.cloud"
echo "======================================"

function read_input {
    while [[ -z "${!1}" ]]; do
        read -rp "${2}: " ${1} < /dev/tty
    done
}

function prepare_system {
    echo "Updating the system first..."

    apt -y update
    apt dist-upgrade -y

    apt install -y software-properties-common curl sudo
}

function def_install_components {
    echo ""
    echo "Choose installation mode: "
    echo "1. Tailscale only"
    echo "2. DERP only"
    echo "3. Tailscale + DERP"
    echo ""

    read_input INSTALL_MODE "Enter an option"
}

function install_tailscale {
    echo "Installing Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh
}

function setup_tailscale {
    systemctl enable --now tailscaled
    sleep 2;

    read_input TS_LOGIN_SERVER "Enter Tailscale login server"
    read_input TS_AUTH_TOKEN "Enter Tailscale auth token"
    read_input TS_HOSTNAME "Enter Tailscale hostname (device name)"

    tailscale up --login-server ${TS_LOGIN_SERVER} --auth-key ${TS_AUTH_TOKEN} --hostname ${TS_HOSTNAME} ${TS_UP_ARGS}
}

function install_go {
    echo "Installing golang from repository"

    add-apt-repository -y ppa:longsleep/golang-backports
    apt update -y
    apt install -y golang-go
}

function install_derp {
    echo "Setting up DERP"

    echo "Creating user"
    useradd --system --create-home --home-dir /opt/derp --shell /bin/bash derp

    echo "Installing derper"
    sudo -u derp -i go install tailscale.com/cmd/derper@main

    setcap 'cap_net_bind_service=+ep' /opt/derp/go/bin/derper

    # This code considered ugly in most countries
    echo "Creating systemd service"
    cat <<EOF > /etc/systemd/system/derper.service
[Unit]
Description=DERP Server
After=network.target

[Service]
User=derp
Group=derp
WorkingDirectory=/opt/derp
EnvironmentFile=$DERP_ENV_FILE
ExecStart=/bin/bash -c "./go/bin/derper -c derp.conf --hostname \${DERP_DOMAIN} \${DERP_ARGS}"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    echo "Creating environment file"
    cat <<EOF > $DERP_ENV_FILE
DERP_DOMAIN=
DERP_ARGS=--stun=true --verify-clients
EOF

    systemctl daemon-reload
}

function setup_derp {
    read_input DERP_DOMAIN "Enter DERP domain name (hostname)"

    # Set DERP_DOMAIN to env file
    if grep -q "^DERP_DOMAIN=" "${DERP_ENV_FILE}"; then
        sed -i -e "s/^DERP_DOMAIN=.*/DERP_DOMAIN=${DERP_DOMAIN}/" "${DERP_ENV_FILE}"
    else
        # DERP_DOMAIN does not exist, append it
        echo "DERP_DOMAIN=${DERP_DOMAIN}" >> "${DERP_ENV_FILE}"
    fi

    systemctl enable derper
    systemctl restart derper
}

while [[ ! "$INSTALL_MODE" =~ ^[0-9]+$ ]] || (( INSTALL_MODE < 1 || INSTALL_MODE > 3 )); do
    unset INSTALL_MODE
    def_install_components
done

prepare_system

case $INSTALL_MODE in
  1)
    echo "Installing only Tailscale"

    install_tailscale
    setup_tailscale
    ;;
  2)
    echo "Installing only DERP"

    install_go
    install_derp
    setup_derp
    ;;
  3)
    echo "Installing Tailscale and DERP"

    install_tailscale
    install_go
    install_derp

    setup_tailscale
    setup_derp
    ;;
esac