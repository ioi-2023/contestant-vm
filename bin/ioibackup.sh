#!/bin/bash

source /opt/ioi/config.sh

QUIET=0
MODE=backup

while [[ $# -gt 0 ]]; do
	case $1 in
		-r)
			MODE=restore
			shift
			;;
	esac
done

if [ -f /opt/ioi/run/ioibackup.pid ]; then
	if ps -p "$(cat /opt/ioi/run/ioibackup.pid)" > /dev/null; then
		echo Already running
		exit 1
	fi
fi

# XXX

rm /opt/ioi/run/ioibackup.pid

# vim: ft=bash ts=4 noet
