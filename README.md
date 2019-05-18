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

	git clone https://github.com/ryankenney/raspberry-pi-setup.git

Tweak the config to your needs:

	cp ./raspberry-pi-setup/config.sh.example ./raspberry-pi-setup/config.sh
	vi ./raspberry-pi-setup/config.sh

Run the script:

	./raspberry-pi-setup/bootstrap-raspberry-pi.sh

When prompted to reboot, press enter, allow reboot, and re-login as `pi`:

	--------------------------------
	Resume this script after reboot.
	--------------------------------
	[[ Rebooting ]]
	Press enter to continue

... and resume script:

	./raspberry-pi-setup/bootstrap-raspberry-pi.sh

Continue to do so until you see:

	------------------
	INSTALL COMPLETE !
	------------------
	[[ Rebooting ]]
	Press enter to continue

