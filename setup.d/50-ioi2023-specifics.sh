#!/bin/bash

set -x
set -e

sudo apt install -y python3-pip

pip3 install PySide6-Essentials
apt -y install fonts-recommended
