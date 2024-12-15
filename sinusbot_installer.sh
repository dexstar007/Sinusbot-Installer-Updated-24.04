#!/bin/bash
# SinusBot installer for Ubuntu Server 24.04+ by Cristian Perdomo (Modified for modern systems)

# Variables
MACHINE=$(uname -m)
INST_VERSION="1.7"
USE_SYSTEMD=true

# Functions
function greenMessage() {
  echo -e "\033[32;1m${*}\033[0m"
}

function redMessage() {
  echo -e "\033[31;1m${*}\033[0m"
}

function yellowMessage() {
  echo -e "\033[33;1m${*}\033[0m"
}

function blueWhiteTitle() {
  local title="SinusBot Installer"
  while true; do
    for color in "\033[34;1m" "\033[37;1m"; do
      echo -ne "\r${color}${title}\033[0m"
      sleep 0.3
    done
  done
}

function errorExit() {
  redMessage "${@}"
  exit 1
}

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
  errorExit "This script must be run as root. Use sudo."
fi

# Stop the moving title when exiting
trap "exit 0" SIGINT SIGTERM

# Start the moving title in the background
blueWhiteTitle &
TITLE_PID=$!

# Update system and install prerequisites
greenMessage "\nUpdating system and installing prerequisites..."
apt update && apt upgrade -y
apt install -y wget tar xvfb libglib2.0-0 python3 iproute2 dbus libnss3 libegl1-mesa libasound2 libxss1 libxcomposite-dev

# Stop the title animation
kill $TITLE_PID

# Check if systemd is available
if ! command -v systemctl &> /dev/null; then
  USE_SYSTEMD=false
fi

# Prompt user for action
greenMessage "SinusBot Installer v$INST_VERSION"
OPTIONS=("Install" "Update" "Remove" "PW Reset" "Quit")
echo "What would you like to do?"
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
    1) ACTION="install"; break ;;
    2) ACTION="update"; break ;;
    3) ACTION="remove"; break ;;
    4) ACTION="pw_reset"; break ;;
    5) exit 0 ;;
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

elif [ "$ACTION" == "pw_reset" ]; then
  # Password reset functionality
  if [ ! -d "$INSTALL_DIR" ]; then
    errorExit "SinusBot is not installed in $INSTALL_DIR."
  fi

  TEMP_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
  greenMessage "Resetting admin password to: $TEMP_PASSWORD"

  sudo -u $(whoami) $INSTALL_DIR/sinusbot --override-password=$TEMP_PASSWORD

  greenMessage "Password reset successfully. Please login with admin/$TEMP_PASSWORD and change your password."
fi

exit 0
