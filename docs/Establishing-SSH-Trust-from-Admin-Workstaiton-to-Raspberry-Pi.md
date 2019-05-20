Establishing SSH Trust from Admin Workstaiton to Raspberry Pi
================

Overview
----------------

We would like the admin user on the Raspberry Pi to trust
a public key from our admin workstation, since we will
turn-off username/password authentication to SSH on the
Raspberry Pi.

I've created a small helper script that will let us transfer
small, encrypted files through tinyurl.com. Techinically,
this content (a public key) doesn't need to be encrypted,
but it's nice to obscure it from tinyurl.com's databases.


Procedure
----------------

We will assume you're running linux on your admin workstation
as well.

We will also assume that you've clone this repo to:

	~/raspberry-pi-setup/

From here, you can encrypt your default public ssh key with:

	~/raspberry-pi-setup/encrypt_to_tinyurl.sh -e ~/.ssh/id_rsa.pub

... responding to a prompt for an ecryption password:

	enter bf-cbc encryption password:
	Verifying - enter bf-cbc encryption password:

... which will result in something like this URL:

	http://tinyurl.com/abcdef01

From the Raspberry Pi, you can download/decrypt/install this with:

	# Download/decrypt/install
	/opt/raspberry-pi-setup/encrypt_to_tinyurl.sh \
	  -d http://tinyurl.com/abcdef01 >> ~/.ssh/authorized_keys
	# Reduce permissions on file (if newly created)
	chmod o-rwx ~/.ssh/authorized_keys

