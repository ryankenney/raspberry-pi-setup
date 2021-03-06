#!/bin/bash

# Stop on any failure
set -e

SCRIPT_FILENAME=$(basename "$0")
SCRIPT_DIR=$(dirname `readlink -f "$0"`)
INSTALL_CONFIG_FILE="${SCRIPT_DIR}/config.sh"
source "${INSTALL_CONFIG_FILE}"

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

# ----------------
# Verifies that the caller has another arg.
# 
# $1: The count of args of the caller. Pass in "$#".
# $2: The name of the arg to describe on error.
# ----------------
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

YES_NO_RESPONSE=
# ----------------
# Prompts the user for a y/n response (case insensitive, but default value capitalized in prompt).
#
# $1 - The one-line user prompt
# $2 - The default response (if user just hits enter). Value "true" or "false" (corresponding to "Y" or "N").
#
# The result of the user's input is returned via global variable YES_NO_RESPONSE.
# with user inputs of "Y" and "N" corrsponding to "true" and "false".
# ----------------
select_yes_no() {
	verify_has_arg "$#" "prompt"
    local PROMPT="$1"
    shift
	verify_has_arg "$#" "default_response"
    local DEFAULT="$1"
    shift

    local REPLY=
	local YES_NO_SUFFIX=

	if [[ "$DEFAULT" == "true" ]]; then
		YES_NO_SUFFIX="[Y/n]"
	else
		YES_NO_SUFFIX="[y/N]"
	fi

    echo ""
    echo "$PROMPT $YES_NO_SUFFIX"
    echo ""

    while read; do
            case $REPLY in
            "")
                    YES_NO_RESPONSE="$DEFAULT"
                    break 2 # Break out of case and loop
                    ;;
            [yY])
                    YES_NO_RESPONSE=true
                    break 2 # Break out of case and loop
                    ;;
            [nN])
                    YES_NO_RESPONSE=false
                    break 2 # Break out of case and loop
                    ;;
            *)
                    echo ""
                    echo "$PROMPT"
                    echo ""
                    ;;
            esac
    done
}

# ----------------
# Fully restarts the network
# ----------------
function restart_network() {
	sudo systemctl daemon-reload
	sudo systemctl stop dhcpcd
	for NET_DEV in /sys/class/net/*; do
		sudo ip addr flush dev "$(basename "$NET_DEV")"
	done
	sudo systemctl start dhcpcd
	sudo systemctl restart networking.service
}

# ----------------
# Tests whether the pattern exists in a file.
# On true, echos "true". On false, echos "false".
# Always exits 0 if no error.
# 
# $1: The pattern to grep.
# $2: The file to grep in.
# ----------------
function grep_exists() {
	verify_has_arg "$#" "pattern"
	local grepPattern="$1"
	shift
	verify_has_arg "$#" "file"
	local grepFile="$1"
	shift

	set +e
	sudo grep "$grepPattern" "$grepFile" > /dev/null
	local exitCode="$?"
	set -e

	if [[ "$exitCode" == "0" ]]; then
		echo "true"
	else
		echo "false"
	fi
}

function setup_static_ip() {
	verify_has_arg "$#" "device_name"
	local device_name="$1"
	shift
	verify_has_arg "$#" "ip_address"
	local ip_address="$1"
	shift
	verify_has_arg "$#" "gateway"
	local gateway="$1"
	shift
	verify_has_arg "$#" "domain_name_servers"
	local domain_name_servers="$1"
	shift

	if [[ "$(grep_exists "^interface ${device_name}\$" /etc/dhcpcd.conf)" == "true" ]]; then
		echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Configuring Static IP for ${device_name} ]]${COLOR_DEFAULT}"
	else
		echo -e "${COLOR_BLUE_LIGHT}[[ Configuring Static IP for ${device_name} ]]${COLOR_DEFAULT}"
		sudo cat >> /etc/dhcpcd.conf << EOL

interface ${device_name}
static ip_address=${ip_address}
static routers=${gateway}
static domain_name_servers=${domain_name_servers}
EOL

		echo -e "${COLOR_BLUE_LIGHT}[[ Restarting Network ]]${COLOR_DEFAULT}"
		restart_network
	fi
}


# Initialize data dir
INSTALL_DATA_DIR="/opt/${SCRIPT_FILENAME}"
sudo mkdir -p "$INSTALL_DATA_DIR"

# Setup keyboard layout (and reboot)
if [[ "$(grep_exists '^XKBLAYOUT="us"$' /etc/default/keyboard)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Setting Keyboard Layout to US ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Setting Keyboard Layout to US ]]${COLOR_DEFAULT}"
	sudo sed -i 's|^XKBLAYOUT=.*$|XKBLAYOUT="us"|g' /etc/default/keyboard
	# Reload keyboard configuration in the active session
	sudo setupcon -k
fi

# Create admin user
if sudo test -f "${INSTALL_DATA_DIR}/ADMIN_USER_CREATED"; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Creating Admin User ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Creating Admin User ]]${COLOR_DEFAULT}"
	if [[ "$INSTALL_ADMIN_PASS" == "" ]]; then
		read -s -p "New Admin Password: " INSTALL_ADMIN_PASS
	fi
	sudo adduser --disabled-password --gecos "" "$INSTALL_ADMIN_USER"
	echo -e "$INSTALL_ADMIN_PASS\n$INSTALL_ADMIN_PASS" | sudo passwd "$INSTALL_ADMIN_USER"
	# Clear password variable as soon as possible
	INSTALL_ADMIN_PASS=""
	sudo bash -c "touch \"${INSTALL_DATA_DIR}/ADMIN_USER_CREATED\""
fi

# Create SSH key
if sudo test -f "/home/${INSTALL_ADMIN_USER}/.ssh/id_rsa"; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Generating SSH Key ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Creating SSH Directory ]]${COLOR_DEFAULT}"
	sudo install -o "${INSTALL_ADMIN_USER}" -g "${INSTALL_ADMIN_USER}" -m "0700" -d "/home/${INSTALL_ADMIN_USER}/.ssh"
	echo -e "${COLOR_BLUE_LIGHT}[[ Generating SSH Key ]]${COLOR_DEFAULT}"
	sudo ssh-keygen -b 2048 -t rsa -f "/home/${INSTALL_ADMIN_USER}/.ssh/id_rsa" -q -N ""
	sudo find "/home/${INSTALL_ADMIN_USER}/.ssh/" -name "id_rsa*" \
	  -exec sudo chmod "0600" "{}" \; \
	  -exec chown "${INSTALL_ADMIN_USER}:${INSTALL_ADMIN_USER}" "{}" \;
fi

# Add admin to sudoers
if sudo test -f "/etc/sudoers.d/99_admin_user"; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Granting Admin User Permissions ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Granting Admin User Permissions ]]${COLOR_DEFAULT}"
	sudo bash -c "echo \"$INSTALL_ADMIN_USER ALL=(ALL) ALL\" >> \"${INSTALL_DATA_DIR}/99_admin_user\""
	# NOTE: This will fail in production if it has a "." or "~" in the filename
	sudo visudo -cf "${INSTALL_DATA_DIR}/99_admin_user"
	sudo install -o root -g root -m "0440" "${INSTALL_DATA_DIR}/99_admin_user" /etc/sudoers.d/
	sudo rm -f "${INSTALL_DATA_DIR}/99_admin_user"
fi

# Configure wifi
if [[ "$INSTALL_WIFI_SSID" != "" && "$INSTALL_WIFI_PASS" != "" ]]; then
	if [[ "$(grep_exists "^ssid=\"$INSTALL_WIFI_SSID\"\$" /etc/wpa_supplicant/wpa_supplicant.conf)" == "true" ]]; then
		echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Configuring Wifi ]]${COLOR_DEFAULT}"
	else
		echo -e "${COLOR_BLUE_LIGHT}[[ Configuring Wifi ]]${COLOR_DEFAULT}"
		sudo bash -c "cat >> /etc/wpa_supplicant/wpa_supplicant.conf" << EOL

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
# We skip ugrade on repeated re-runs
sudo apt install -y --no-upgrade ufw
sudo ufw enable

# Setup static IPs
if [[ "$INSTALL_WIFI_IP_ADDR" != "" ]]; then
	setup_static_ip "wlan0" "$INSTALL_WIFI_IP_ADDR" "$INSTALL_WIFI_GATEWAY" "$INSTALL_WIFI_DNS_SERVERS"
fi
if [[ "$INSTALL_ETHERNET_IP_ADDR" != "" ]]; then
	setup_static_ip "eth0" "$INSTALL_ETHERNET_IP_ADDR" "$INSTALL_ETHERNET_GATEWAY" "$INSTALL_ETHERNET_DNS_SERVERS"
fi

# Configure hostname
if [[ "$(grep_exists "^${INSTALL_HOSTNAME}\\.${INSTALL_DOMAIN}\$" /etc/hostname)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Updating Hostname ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Updating Hostname ]]${COLOR_DEFAULT}"
	sudo sed -i "s|^127\\.0\\.1\\.1\s\+.\+|127.0.1.1\t${INSTALL_IP_ADDR} ${INSTALL_HOSTNAME} ${INSTALL_HOSTNAME}.${INSTALL_DOMAIN}|g" /etc/hosts
	sudo bash -c "echo \"${INSTALL_HOSTNAME}.${INSTALL_DOMAIN}\" > /etc/hostname"
	sudo hostname "${INSTALL_HOSTNAME}.${INSTALL_DOMAIN}"
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

# Enable locale
if [[ "$(grep_exists '^en_US.UTF-8 UTF-8$' /etc/locale.gen)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Enabling US:English Locale ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Enabling US:English Locale ]]${COLOR_DEFAULT}"
	sudo bash -c 'echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen'
fi

# Set locale
if [[ "$(locale | grep '^LANG=')" == "LANG=en_US.UTF-8" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Setting Locale to US:English ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Setting Locale to US:English ]]${COLOR_DEFAULT}"
	sudo locale-gen --purge en_US.UTF-8
	sudo update-locale 'LANG=en_US.UTF-8'
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
# We skip ugrade on repeated re-runs
sudo apt install -y --no-upgrade ufw unattended-upgrades update-notifier-common

# Setup unattended upgrade options
if [[ "$(grep_exists '^APT::Periodic::Update-Package-Lists\s\+"1";$' /etc/apt/apt.conf.d/20auto-upgrades)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Enabling 'APT::Periodic::Update-Package-Lists' option ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Enabling 'APT::Periodic::Update-Package-Lists' option ]]${COLOR_DEFAULT}"
	sudo bash -c "echo 'APT::Periodic::Update-Package-Lists \"1\";' >> /etc/apt/apt.conf.d/20auto-upgrades"
fi
if [[ "$(grep_exists '^APT::Periodic::Unattended-Upgrade\s\+"1";$' /etc/apt/apt.conf.d/20auto-upgrades)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Enabling 'APT::Periodic::Unattended-Upgrade' option ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Enabling 'APT::Periodic::Unattended-Upgrade' option ]]${COLOR_DEFAULT}"
	sudo bash -c "echo 'APT::Periodic::Unattended-Upgrade \"1\";' >> /etc/apt/apt.conf.d/20auto-upgrades"
fi
if [[ "$(grep_exists '^\s\+"origin=Raspbian,codename=${distro_codename},label=Raspbian";$' /etc/apt/apt.conf.d/50unattended-upgrades)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Updating 'Unattended-Upgrade::Origins-Pattern' option ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Updating 'Unattended-Upgrade::Origins-Pattern' option ]]${COLOR_DEFAULT}"
	sudo sed -i 's|^\(\s\+"origin=Debian,codename=${distro_codename},label=Debian-Security";\s*\)$|//\1\n\t"origin=Raspbian,codename=${distro_codename},label=Raspbian";\n\t"origin=Raspberry Pi Foundation,codename=${distro_codename},label=Raspberry Pi Foundation";|g' /etc/apt/apt.conf.d/50unattended-upgrades
fi
if [[ "$(grep_exists '^Unattended-Upgrade::Automatic-Reboot "true";$' /etc/apt/apt.conf.d/50unattended-upgrades)" == "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Enabling 'Unattended-Upgrade::Automatic-Reboot' option ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Enabling 'Unattended-Upgrade::Automatic-Reboot' option ]]${COLOR_DEFAULT}"
	sudo bash -c "echo 'Unattended-Upgrade::Automatic-Reboot \"true\";' >> /etc/apt/apt.conf.d/50unattended-upgrades"
fi

# APT update
if sudo test -f "${INSTALL_DATA_DIR}/APT_UPDATED"; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Applying APT Updates ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Applying APT Updates ]]${COLOR_DEFAULT}"
	sudo apt -y update
	sudo apt -y dist-upgrade
	sudo bash -c "touch \"${INSTALL_DATA_DIR}/APT_UPDATED\""
fi

if [[ "$(grep_exists '^pi:' /etc/passwd)" != "true" ]]; then
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Deleting pi User ]]${COLOR_DEFAULT}"
else
	if [[ "$USER" = "pi" ]]; then
		echo -e "${COLOR_MAGENTA_LIGHT}------------------${COLOR_DEFAULT}"
		echo -e "${COLOR_MAGENTA_LIGHT}Login as your new admin user after${COLOR_DEFAULT}"
		echo -e "${COLOR_MAGENTA_LIGHT}reboot and resume this script.${COLOR_DEFAULT}"
		echo -e "${COLOR_MAGENTA_LIGHT}------------------${COLOR_DEFAULT}"
		echo -e "${COLOR_BLUE_LIGHT}[[ Rebooting ]]${COLOR_DEFAULT}"
		read -p "Press enter to continue"
		sudo reboot
	fi
	echo -e "${COLOR_BLUE_LIGHT}[[ Deleting pi User ]]${COLOR_DEFAULT}"
	sudo deluser pi
fi

if [[ ! -f "${INSTALL_CONFIG_FILE}" ]]; then 
	echo -e "${COLOR_BLUE_LIGHT}[[ SKIP: Deleting Config File ]]${COLOR_DEFAULT}"
else
	echo -e "${COLOR_BLUE_LIGHT}[[ Deleting Config File ]]${COLOR_DEFAULT}"
	echo -e "${COLOR_MAGENTA_LIGHT}Your config file may contain passwords or other secrets.${COLOR_DEFAULT}"
	echo -e "Config file: ${INSTALL_CONFIG_FILE}"
	select_yes_no "Automatically delete file?" true
	if [[ "${YES_NO_RESPONSE}" == "true" ]]; then
		sudo shred --remove "${INSTALL_CONFIG_FILE}"
	fi
fi

echo -e "${COLOR_BLUE_LIGHT}------------------${COLOR_DEFAULT}"
echo -e "${COLOR_BLUE_LIGHT}INSTALL COMPLETE !${COLOR_DEFAULT}"
echo -e "${COLOR_BLUE_LIGHT}------------------${COLOR_DEFAULT}"
echo -e "${COLOR_BLUE_LIGHT}[[ Rebooting ]]${COLOR_DEFAULT}"
read -p "Press enter to continue"
sudo reboot
