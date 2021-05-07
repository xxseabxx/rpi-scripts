#!/bin/bash
# file: enable_uart.sh
#
# This script will enable the uart module in the config.txt.

#

# check if sudo is used
if [ "$(id -u)" != 0 ]; then
  echo 'Sorry, you need to run this script with sudo'
  exit 1
fi


if grep -q 'enable_uart=1' /boot/config.txt; then
  echo 'Seems uart parameter already set, skip this step.'
else
  echo 'enable_uart=1' >> /boot/config.txt
fi

if grep -q '^dtparam=i2c_arm=on' /boot/config.txt; then
  echo '2 - Seems i2c_arm parameter already set, skip this step.'
else
  echo 'dtparam=i2c_arm=on' >> /boot/config.txt
fi