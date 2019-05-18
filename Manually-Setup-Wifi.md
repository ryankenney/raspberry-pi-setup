Manually Setup Wifi
================

Boot/login to your Raspberry Pi


Edit this:

	sudo vi /etc/wpa_supplicant/wpa_supplicant.conf

... adding:

	network={
	ssid="MyWifiNetworkName"
	psk="MyWifiPassword"
	}

Reboot

	sudo reboot
