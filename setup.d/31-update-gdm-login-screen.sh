#!/bin/bash

set -x
set -e

sudo -u gdm dbus-run-session gsettings set org.gnome.login-screen logo '/opt/ioi/misc/ioi-transparent.png'
