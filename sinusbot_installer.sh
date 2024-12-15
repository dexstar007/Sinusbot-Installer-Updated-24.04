#!/bin/bash
# SinusBot installer for Ubuntu Server 24.04+ by Cristian Perdomo (Modified for modern systems)

# Variables
MACHINE=$(uname -m)
INST_VERSION="1.6"
USE_SYSTEMD=true

# Functions
function greenMessage() {
  echo -e "\033[32;1m${*}\033[0m"
}

function redMessage() {
  echo -e "\033[31;1m${*}\033[0m"
}

function errorExit() {
  redMessage "${@}"
  exit 1
}

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
  errorExit "This script must be run as root. Use sudo."
fi

# Update system and install prerequisites
greenMessage "Updating system and installing prerequisites..."
apt update && apt upgrade -y
apt install -y wget tar xvfb libglib2.0-0 python3 iproute2 dbus libnss3 libegl1-mesa libasound2 libxss1 libxcomposite-dev

# Check if systemd is available
if ! command -v systemctl &> /dev/null; then
  USE_SYSTEMD=false
fi

# Prompt user for action
greenMessage "SinusBot Installer v$INST_VERSION"
OPTIONS=("Install" "Update" "Remove" "Quit")
echo "What would you like to do?"
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
    1) ACTION="install"; break ;;
    2) ACTION="update"; break ;;
    3) ACTION="remove"; break ;;
    4) exit 0 ;;
    *) echo "Invalid option, please try again." ;;
  esac
done

# Set installation directory
INSTALL_DIR="/opt/sinusbot"
echo "Installation directory is set to $INSTALL_DIR."

if [ "$ACTION" == "install" ]; then
  # Download and install SinusBot
  greenMessage "Downloading SinusBot..."
  wget -O sinusbot.tar.bz2 "https://www.sinusbot.com/dl/sinusbot.current.tar.bz2"
  if [ ! -f sinusbot.tar.bz2 ]; then
    errorExit "Failed to download SinusBot."
  fi

  greenMessage "Installing SinusBot..."
  mkdir -p "$INSTALL_DIR"
  tar -xjf sinusbot.tar.bz2 -C "$INSTALL_DIR"
  rm sinusbot.tar.bz2

  # Set permissions
  chmod -R 755 "$INSTALL_DIR"
  chown -R $(whoami):$(whoami) "$INSTALL_DIR"

  # Configure systemd service if applicable
  if [ "$USE_SYSTEMD" == true ]; then
    greenMessage "Configuring systemd service..."
    cat <<EOF > /etc/systemd/system/sinusbot.service
[Unit]
Description=SinusBot Service
After=network.target

[Service]
User=$(whoami)
ExecStart=$INSTALL_DIR/sinusbot
WorkingDirectory=$INSTALL_DIR
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable sinusbot.service
    systemctl start sinusbot.service
    greenMessage "SinusBot installed and started successfully."
  else
    redMessage "Systemd not available. Please start SinusBot manually from $INSTALL_DIR."
  fi

elif [ "$ACTION" == "update" ]; then
  # Update SinusBot
  if [ ! -d "$INSTALL_DIR" ]; then
    errorExit "SinusBot is not installed in $INSTALL_DIR."
  fi

  greenMessage "Stopping SinusBot service..."
  systemctl stop sinusbot.service

  greenMessage "Downloading and updating SinusBot..."
  wget -O sinusbot.tar.bz2 "https://www.sinusbot.com/dl/sinusbot.current.tar.bz2"
  tar -xjf sinusbot.tar.bz2 -C "$INSTALL_DIR"
  rm sinusbot.tar.bz2

  systemctl start sinusbot.service
  greenMessage "SinusBot updated and restarted successfully."

elif [ "$ACTION" == "remove" ]; then
  # Remove SinusBot
  if [ ! -d "$INSTALL_DIR" ]; then
    errorExit "SinusBot is not installed in $INSTALL_DIR."
  fi

  greenMessage "Stopping and disabling SinusBot service..."
  systemctl stop sinusbot.service
  systemctl disable sinusbot.service
  rm /etc/systemd/system/sinusbot.service
  systemctl daemon-reload

  greenMessage "Removing SinusBot files..."
  rm -rf "$INSTALL_DIR"

  greenMessage "SinusBot has been removed successfully."
fi

exit 0
