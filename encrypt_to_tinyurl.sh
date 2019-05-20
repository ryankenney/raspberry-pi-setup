#!/bin/bash

# ----------------
# encrypt_to_tinyurl.sh
# 
# Sends/receives small files through tinyurl.com,
# using password-based encryption.
# 
# Run without arguments for usage.
# ----------------

# Stop on error
set -e

SCRIPT_FILENAME=$(basename "$0")
SCRIPT_DIR=$(dirname `readlink -f "$0"`)

function do_upload() {

	local source_file="$1"

	# -e: Encrypt
	# -base64: Output data in ascii
	# -A: No linebreaks in base64 output
	# -bf-cbc: Sets crypto to Blowfish in CBC 
	local encrypt_command='openssl enc -e -base64 -A -bf-cbc'

	local encrypted_content="$(cat "$source_file" | $encrypt_command)"

	local tinyurl="$(curl -s "http://tinyurl.com/api-create.php?url=$encrypted_content")"

	echo "$tinyurl"
}

function do_download() {

	local source_file="$1"

	# -d: Decrypt
	# -base64: Output data in ascii
	# -bf-cbc: Sets crypto to Blowfish in CBC 
	local decrypt_command='openssl enc -d -base64 -bf-cbc'

	# -s: Suppress download progress
	# -I: Show headers
	local curl_command='curl -s -I'

	local decrypted_content="$($curl_command "$1" | sed -n 's|^Location:\s\+\(.\+\)$|\1|p' | $decrypt_command)"

	echo "$decrypted_content"
}

function print_usage_and_exit() {
	echo "" 1>&2
	echo "Usage: $SCRIPT_FILENAME [-e <file>] [-d <tiny-url>]" 1>&2
	echo "" 1>&2
	echo "  -e: Encrypt/upload to tiny-url" 1>&2
	echo "" 1>&2
	echo "    file: The file with contents to transfer" 1>&2
	echo "" 1>&2
	echo "  -d: Download/decrypt from tiny-url" 1>&2
	echo "" 1>&2
	echo "    tiny-url: The tiny-url to download" 1>&2
	echo "" 1>&2
	exit 1
}

if [[ "$#" != "2" ]]; then
	print_usage_and_exit
fi

if [[ "$1" = "-e" ]]; then
	shift
	do_upload "$1"
elif [[ "$1" = "-d" ]]; then
	shift
	do_download "$1"
else
	print_usage_and_exit
fi
