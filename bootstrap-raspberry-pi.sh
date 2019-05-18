#!/bin/bash

# Stop on any failure
set -e

# Setup colors
# check if stdout is a terminal...
if test -t 1; then

	# see if it supports colors...
	ncolors=$(tput colors)

	if test -n "$ncolors" && test $ncolors -ge 8; then

		COLOR_DEFAULT="\e[39m"
		COLOR_RED="\e[31m"
		COLOR_YELLOW="\e[33m"
		COLOR_YELLOW_LIGHT="\e[93m"
		COLOR_MAGENTA="\e[35m"
		COLOR_MAGENTA_LIGHT="\e[95m"
		COLOR_BLUE_LIGHT="\e[94m"

	fi
fi

# Fully restarts the network
function restart_network() {
	echo ""
	echo "==== Restarting the Network ===="
	echo ""
	sudo systemctl daemon-reload
	sudo systemctl stop dhcpcd
	for NET_DEV in /sys/class/net/*; do
		sudo ip addr flush dev "$NET_DEV"
	done
	sudo systemctl start dhcpcd
	sudo systemctl restart networking.service
}

# Verifies that the caller has another arg.
# 
# $1: The count of args of the caller. Pass in "$#".
# $2: The name of the arg to describe on error.
function verify_has_arg() {
	local argCount="$1"
	shift
	local argName="$1"
	shift
	
	if [[ "$argName" < "1" ]]; then
		echo "" 1>&2
		echo "ERROR: Missing required arg: $argName" 1>&2
		echo "" 1>&2
		exit 1
	fi
}

# Tests whether the pattern exists in a file.
# On true, echos "true". On false, echos "false".
# Always exits 0 if no error.
# 
# $1: The pattern to grep.
# $2: The file to grep in.
function grep_exists() {
	verify_has_arg "$#" "pattern"
	local grepPattern="$1"
	shift
	verify_has_arg "$#" "file"
	local grepFile="$1"
	shift

	set +e
	grep "$grepPattern" "$grepFile"
	local exitCode="$?"
	set -e

	if [[ "$exitCode" == "0" ]]; then
		echo "true"
	else
		echo "false"
	fi
}

SCRIPT_FILENAME=`basename "$0"`
SCRIPT_DIR=$(dirname `readlink -f "$0"`)

source "${SCRIPT_DIR}/config.sh"

# Initialize data dir
INSTALL_DATA_DIR="/opt/raspberry-pi-boostrap"
sudo mkdir -p "$INSTALL_DATA_DIR"

# Setup keyboard layout (and reboot)
if [[ "$(grep_exists '^XKBLAYOUT="us"$' /etc/default/keyboard)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Setting Keyboard Layout to US ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Setting Keyboard Layout to US ]]${COLOR_DEFAULT}"
	sudo sed -i 's|^XKBLAYOUT=.*$|XKBLAYOUT="us"|g' /etc/default/keyboard

	echo -e "${COLOR_BLUE_LIGHT}[[ Rebooting ]]${COLOR_DEFAULT}"
	read -p "Press enter to continue"
	sudo reboot
fi

# Create admin user
if [[ ! sudo test -f "${INSTALL_DATA_DIR}/ADMIN_USER_CREATED" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Creating Admin User ]]${COLOR_DEFAULT}"
else
	echo ""
	read -p "Admin Password: " INSTALL_ADMIN_PASS

	echo -e "${COLOR_BLUE_LIGHT}[[ Creating Admin User ]]${COLOR_DEFAULT}"
	sudo adduser --disabled-password --gecos "" "$INSTALL_ADMIN_USER"
	echo "$INSTALL_ADMIN_PASS" | sudo passwd "$INSTALL_ADMIN_USER" --stdin
	sudo -c "touch \"${INSTALL_DATA_DIR}/ADMIN_USER_CREATED\""
fi

# Create SSH key
if [[ sudo test -f "/home/${INSTALL_ADMIN_USER}/.ssh/id_rsa" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Generating SSH Key ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Generating SSH Key ]]${COLOR_DEFAULT}"
	sudo ssh-keygen -b 2048 -t rsa -f "/home/${INSTALL_ADMIN_USER}/.ssh/id_rsa" -q -N ""
	sudo install -o "${INSTALL_ADMIN_USER}" -g "${INSTALL_ADMIN_USER}" -m "0600" "/home/${INSTALL_ADMIN_USER}/.ssh"/id_rsa*
fi

# Add admin to sudoers
if [[ sudo test -f "/etc/sudoers.d/99_admin_user" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Granting Admin User Permissions ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Granting Admin User Permissions ]]${COLOR_DEFAULT}"
	sudo bash -c "echo \"$INSTALL_ADMIN_USER ALL=(ALL) ALL\" >> \"${INSTALL_DATA_DIR}/99_admin_user\""
	# NOTE: This will fail in production if it has a "." or "~" in the filename
	sudo visudo -cf "${INSTALL_DATA_DIR}/99_admin_user"
	sudo install -o root -g root -m "0440" "${INSTALL_DATA_DIR}/99_admin_user" /etc/sudoers.d/
fi

# Configure wifi
if [[ "$INSTALL_WIFI_SSID" != "" && "$INSTALL_WIFI_SSID" != "" ]]; then
	if [[ "$(grep_exists '^ssid="$INSTALL_WIFI_SSID"$' /etc/wpa_supplicant/wpa_supplicant.conf)" == "true" ]]; then
		echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Configuring Wifi ]]${COLOR_DEFAULT}"
	else
		echo -e "${COLOR_BLUE_LIGHT}[[ Configuring Wifi ]]${COLOR_DEFAULT}"
		sudo cat >> /etc/wpa_supplicant/wpa_supplicant.conf << EOL

network={
ssid="$INSTALL_WIFI_SSID"
psk="$INSTALL_WIFI_PASS"
}
EOL

		echo -e "${COLOR_BLUE_LIGHT}[[ Restarting Network ]]${COLOR_DEFAULT}"
		restart_network
	fi
fi

# Enable firewall
echo -e "${COLOR_BLUE_LIGHT}[[ Ensuring Firewall Enabled ]]${COLOR_DEFAULT}"
sudo apt-get install -y ufw
sudo ufw enable

if [[ "$(grep_exists '^static ip_address=.*$' /etc/dhcpcd.conf)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Configuring Static IP ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Configuring Static IP ]]${COLOR_DEFAULT}"
	sudo cat >> /etc/dhcpcd.conf << EOL

static ip_address=${INSTALL_IP_ADDR}
static routers=${INSTALL_GATEWAY}
static domain_name_servers=${INSALL_DNS_SERVERS}
EOL

	echo -e "${COLOR_BLUE_LIGHT}[[ Restarting Network ]]${COLOR_DEFAULT}"
	restart_network
fi

# Configure hostname
if [[ "$(grep_exists "^${INSTALL_HOSTNAME}\\.${INSTALL_HOSTNAME}\$" /etc/hostname)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Updating Hostname ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Updating Hostname ]]${COLOR_DEFAULT}"
	sudo sed -i "s|^127\\.0\\.1\\.1\s\+.\+|127.0.1.1\t${INSTALL_IP_ADDR} ${INSTALL_HOSTNAME} ${INSTALL_HOSTNAME}.${INSTALL_DOMAIN}|g" /etc/hosts
	hostname "${INSTALL_HOSTNAME}.${INSTALL_DOMAIN}"
fi

# Disable ssh password-based auth
if [[ "$(grep_exists '^PasswordAuthentication no$' /etc/ssh/sshd_config)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Disabling Password Auth to SSH Server ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Disabling Password Auth to SSH Server ]]${COLOR_DEFAULT}"
	sudo bash -c 'echo "" >> /etc/ssh/sshd_config'
	sudo bash -c 'echo "PasswordAuthentication no" >> /etc/ssh/sshd_config'
fi

# Enable ssh server
echo -e "${COLOR_BLUE_LIGHT}[[ Ensuring SSH Server Enabled ]]${COLOR_DEFAULT}"
sudo systemctl start ssh.service
sudo systemctl enable ssh.service

# Allow ssh firewall port
echo -e "${COLOR_BLUE_LIGHT}[[ Ensuring SSH Port Open in Firewall ]]${COLOR_DEFAULT}"
sudo ufw allow ssh

# Set locale
if [[ "$(grep_exists '^LANG="en_US.UTF-8"$' /etc/default/locale)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Setting Locale to US:English ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Setting Locale to US:English ]]${COLOR_DEFAULT}"
	sudo locale-gen --purge en_US.UTF-8
	sudo bash -c "echo 'LANG=\"en_US.UTF-8\"' > /etc/default/locale"
fi

# Set timezone
if [[ "$(readlink /etc/localtime)" == "/usr/share/zoneinfo/${INSTALL_TIMEZONE}" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Setting Timezone ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Setting Timezone ]]${COLOR_DEFAULT}"
	sudo ln -fs "/usr/share/zoneinfo/${INSTALL_TIMEZONE}" /etc/localtime
	sudo dpkg-reconfigure -f noninteractive tzdata
fi

# Install unattended upgrades
echo -e "${COLOR_BLUE_LIGHT}[[ Ensuring Unattended Upgrades Installed ]]${COLOR_DEFAULT}"
sudo apt -y install unattended-upgrades update-notifier-common

# Setup unattended upgrade options
if [[ '^APT::Periodic::Update-Package-Lists\s+"1";$' /etc/apt/apt.conf.d/20auto-upgrades == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Enabling 'Update-Package-Lists' option ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Enabling 'Update-Package-Lists' option ]]${COLOR_DEFAULT}"
	sudo bash -c "echo 'APT::Periodic::Update-Package-Lists \"1\";' >> /etc/apt/apt.conf.d/20auto-upgrades"
fi
if [[ '^APT::Periodic::Unattended-Upgrade\s+"1";$' /etc/apt/apt.conf.d/20auto-upgrades == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Enabling 'Unattended-Upgrade' option ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Enabling 'Unattended-Upgrade' option ]]${COLOR_DEFAULT}"
	sudo bash -c "echo 'APT::Periodic::Unattended-Upgrade \"1\";' >> /etc/apt/apt.conf.d/20auto-upgrades"
fi


... finish unattended upgrades ...

echo -e "${COLOR_BLUE_LIGHT}------------------${COLOR_DEFAULT}"
echo -e "${COLOR_BLUE_LIGHT}INSTALL COMPLETE !${COLOR_DEFAULT}"
echo -e "${COLOR_BLUE_LIGHT}------------------${COLOR_DEFAULT}"
echo -e "${COLOR_BLUE_LIGHT}[[ Rebooting ]]${COLOR_DEFAULT}"
read -p "Press enter to continue"
sudo reboot
