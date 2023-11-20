#!/bin/bash

TS_AUTH_TOKEN=${TS_AUTH_TOKEN}
TS_HOSTNAME=${TS_HOSTNAME}
TS_LOGIN_SERVER=${TS_LOGIN_SERVER}
TS_UP_ARGS=${TS_UP_ARGS}
TS_ACCEPT_ROUTES=${TS_ACCEPT_ROUTES}
TS_ACCEPT_DNS=${TS_ACCEPT_DNS}
TS_UP_SKIP=${TS_UP_SKIP}
TS_ADVERTISE_ROUTES=${TS_ADVERTISE_ROUTES}
TS_TAGS=${TS_TAGS}

DERP_DOMAIN=${DERP_DOMAIN}
DERP_ENV_FILE=${DERP_ENV_FILE:-/etc/default/derper}
DERP_VERIFY_CLIENTS=${DERP_VERIFY_CLIENTS}
DERP_ARGS=${DERP_ARGS}
DERP_HTTP_PORT=${DERP_HTTP_PORT}
DERP_HTTPS_PORT=${DERP_HTTPS_PORT}
DERP_STUN_PORT=${DERP_STUN_PORT}

INSTALL_MODE=${INSTALL_MODE}
USE_DEFAULT_VALS=${USE_DEFAULT_VALS}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root!"
    exit 1
fi

echo "======================================"
echo "This script was tested on Ubuntu 22.04"
echo "Maintainer: kulev@mindbox.cloud"
echo "======================================"

# arg1: variable name
# arg2: prompt
# arg3: default value
# arg4: is optional?
# arg5: echo message
function read_input {
    if [[ "$4" == "1" && ! -z "$3" ]]; then
        declare -g ${1}=$3
        return
    fi

    local R_PROMPT="${2}"

    if [[ ! -z "$3" ]]; then
        R_PROMPT="$R_PROMPT [$3]"
    fi

    R_PROMPT="$R_PROMPT: "

    if [[ ! -z "$5" ]]; then
        echo -e "$5"
    fi

    while [[ -z "${!1}" ]]; do
        read -rp "$R_PROMPT" ${1} < /dev/tty

        if [[ -z "${!1}" && ! -z "$3" ]]; then
            declare -g ${1}=$3
            break
        fi
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

    read_input INSTALL_MODE "Enter an option" "3"
}

function install_tailscale {
    echo "Installing Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh
}

function setup_tailscale {
    systemctl enable --now tailscaled
    sleep 2;

    if [[ "$TS_UP_SKIP" == "1" ]]; then
        echo "Variable TS_UP_SKIP is set to 1."
        echo "You will have to join Tailnet manually."
        return
    fi

    read_input TS_LOGIN_SERVER "Enter Tailscale login server" "https://controlplane.tailscale.com"
    read_input TS_AUTH_TOKEN "Enter Tailscale auth token"
    read_input TS_HOSTNAME "Enter Tailscale hostname (device name)" "$(hostname)"
    read_input TS_ACCEPT_ROUTES "Accept routes (1 = yes)" "1" "$USE_DEFAULT_VALS"
    read_input TS_ACCEPT_DNS "Accept DNS (1 = yes)" "1" "$USE_DEFAULT_VALS"

    if [[ "$TS_ACCEPT_ROUTES" == "1" ]]; then
        TS_UP_ARGS="--accept-routes $TS_UP_ARGS"
    fi

    if [[ "$TS_ACCEPT_DNS" == "1" ]]; then
        TS_UP_ARGS="--accept-dns $TS_UP_ARGS"
    fi

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
ExecStart=/bin/bash -c "./go/bin/derper -c derp.conf \
    --hostname \${DERP_DOMAIN} \
    -a \${DERP_HTTPS_URL} \
    --http-port \${DERP_HTTP_PORT} \
    --stun-port \${DERP_STUN_PORT} \
    \${DERP_ARGS}" 
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

function setup_derp {
    read_input DERP_DOMAIN "Enter DERP domain name (hostname)"
    read_input DERP_VERIFY_CLIENTS "Verify DERP clients (1 = yes)" "1" "$USE_DEFAULT_VALS"
    read_input DERP_HTTP_PORT "Set DERP HTTP port" "80" "$USE_DEFAULT_VALS"
    read_input DERP_HTTPS_PORT "Set DERP HTTPS port" "443" "$USE_DEFAULT_VALS"
    read_input DERP_STUN_PORT "Set DERP STUN port" "3478" "$USE_DEFAULT_VALS"

    if [[ "$DERP_VERIFY_CLIENTS" == "1" ]]; then
        DERP_ARGS="--verify-clients $DERP_ARGS"
    fi

    echo "Creating environment file"
    cat <<EOF > $DERP_ENV_FILE
DERP_DOMAIN=$DERP_DOMAIN
DERP_HTTP_PORT=$DERP_HTTP_PORT
DERP_HTTPS_URL=:$DERP_HTTPS_PORT
DERP_STUN_PORT=$DERP_STUN_PORT
DERP_ARGS=$DERP_ARGS
EOF

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