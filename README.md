Raspberry Pi Setup Scripts
================

Overview
----------------

This contains bootstrap scripts to apply setup/lockdown mechaisms to Raspberry Pi.

Features included in `bootstrap-raspberry-pi.sh`:

* Set keyboard layout to US
* Create non-default admin user
* Delete default admin user
* Generate SSH keys
* Configure wifi
* Configure static network settings
* Configure hostname
* Configure locale
* Configure timezone
* Install/configure ufw firewall
* Install/configure SSH server
* Install/configure unattended OS upgrades


Bootstrapping a Fresh Raspbian Image
----------------

Load a fresh Raspbian Stretch image and boot the Raspberry Pi

Connect to the network via ethernet port or [Manually Setup Wifi](Manually-Setup-Wifi.md)

Login as the `pi` user

Install git:

	sudo apt -y install git

Clone this repo:

	# Create directory owned by pi
	sudo install -o pi -g pi -d /opt/raspberry-pi-setup
	# Clone repo to directory
	git clone https://github.com/ryankenney/raspberry-pi-setup.git /opt/raspberry-pi-setup

Tweak the config to your needs:

	cp /opt/raspberry-pi-setup/config.sh.example /opt/raspberry-pi-setupconfig.sh
	vi /opt/raspberry-pi-setupconfig.sh

Run the script:

	/opt/raspberry-pi-setup/bootstrap-raspberry-pi.sh

When prompted to reboot, press enter, allow reboot:

	--------------------------------
	Resume this script after reboot.
	--------------------------------
	[[ Rebooting ]]
	Press enter to continue

... and re-login as `pi` and resume the script:

	/opt/raspberry-pi-setup/bootstrap-raspberry-pi.sh

If prompted for admin password, provide your chosen new password
for the `INSTALL_ADMIN_USER` user in `config.sh`:

	[[ Creating Admin User ]]
	New Admin Password: 

When prompted to switch to your new admi user, press enter, allow reboot:

	------------------
	Login as your new admin user after${COLOR_DEFAULT}"
	reboot and resume this script.${COLOR_DEFAULT}"
	------------------
	[[ Rebooting ]]
	Press enter to continue

... and re-login as your `INSTALL_ADMIN_USER` and resume the script:

	/opt/raspberry-pi-setup/bootstrap-raspberry-pi.sh

Continue to do so until you see:

	------------------
	INSTALL COMPLETE !
	------------------
	[[ Rebooting ]]
	Press enter to continue
