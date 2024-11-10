#!/bin/sh
#
# Allow multiple forced commands in SSH
# See https://serverfault.com/questions/749474/ssh-authorized-keys-command-option-multiple-commands#749486
#
# You can have only one forced command in ~/.ssh/authorized_keys. Use this
# wrapper to allow several commands.

# Unison
CMD_UNISON_1="/usr/bin/unison -server"
CMD_UNISON_2="unison -server"
CMD_UNISON_NEWRPC="unison -server __new-rpc-mode"

# Always use the full-path version
CMD_UNISON_ACTUAL="/usr/bin/unison"
CMD_UNISON_ACTUAL_ARGS="-server"

# SFTP
CMD_SFTP_1="/usr/lib/sftp-server"
CMD_SFTP_2="/usr/lib/openssh/sftp-server"

case "$SSH_ORIGINAL_COMMAND" in
	"$CMD_UNISON_1")
		"$CMD_UNISON_ACTUAL" "$CMD_UNISON_ACTUAL_ARGS"
		;;
	"$CMD_UNISON_2")
		"$CMD_UNISON_ACTUAL" "$CMD_UNISON_ACTUAL_ARGS"
		;;
	"$CMD_UNISON_NEWRPC")
		"$CMD_UNISON_ACTUAL" "$CMD_UNISON_ACTUAL_ARGS" __new-rpc-mode
		;;
	"$CMD_SFTP_1")
		"$CMD_SFTP_1"
		;;
	"$CMD_SFTP_2")
		"$CMD_SFTP_2"
		;;
	*)
		echo "Access denied"
		# For debugging purposes
		echo "$SSH_ORIGINAL_COMMAND" > "$(mktemp --tmpdir tmp-ssh-failed.XXXXXXXXXX)"
		exit 1
		;;
esac
