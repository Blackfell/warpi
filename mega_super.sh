#!/bin/bash

# Globals
CONFIG_FILE="./warpi.conf"

# Erro message helpers
source "./prompt_functions.sh"

# Configure SSH on this Pi, key only if required $1 - Authorised key data
function configureSSH {
	# No root login with password
	sudo sed -i "s/^#\s{0,4}PermitRootLogin/PermitRootLogin/g" /etc/ssh/sshd_config
	# Key only auth
	sudo sed -i "s/^#\s{0,4}PasswordAuthenitcation yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
}

function configureAP {
	# RUNS AS ROOT - Set up Pi in-build NIC as an AP - Assumes full upgrade completed
	# TODO - To be implemented fully
	# $1 = Interface $2 = SSID $3 = PSK $4 = CIDR $5 = Hidden SSID $6 DHCP_RANGE
	sudo apt install hostapd dnsmasq
	sudo systemctl stop hostapd
	sudo systemctl stop dnsmasq
	# Configure dhcpd & dnsmasq
	echo -e "denyinterfaces $AP_CARD\n" | tee -a /etc/dhcpd.conf
	sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
	echo -e "interface=$AP_CARD\n\tdhcp-range=$AP_DHCP_RANGE,24h" | tee -a /etc/dnsmasq.conf
	# Hostapd config, based on local file
	$HAPD_CONF="/etc/hostapd/hostapd.conf"
	cp ./hostapd.conf $HAPD_CONF
	sed -i "s/AP_SSID/$AP_SSID/g" $HAPD_CONF
	sed -i "s/AP_PASSWORD/$AP_PASSWORD/g" $HAPD_CONF
	sed -i "s/AP_CARD/$AP_CARD/g" $HAPD_CONF
	sed -i "s/^#\s{0,4}DAEMON_CONF=/DAEMON_CONF=$HAPD_CONF/g" /etc/hostapd/hostapd
	# Setup AP IP and restart services - Overwrite intentional BTW
	pInf "Configured AP:\nSSID:\t$AP_SSID\nCIDR:\r$AP_CIDR\nPassword in config file."
        sudo cp -f ./interfaces /etc/network/interfaces	
	sudo sed -i "s/AP_CARD/$AP_CARD/g" /etc/network/interfaces
	sudo sed -i "s/AP_ADDR/$AP_ADDR/g" /etc/network/interfaces
	sudo sed -i "s/AP_NETMASK/$AP_NETMASK/g" /etc/network/interfaces
	sudo sed -i "s/AP_NETWORK/$(echo $AP_CIDR | cut -d '/' -f 1)/g" /etc/network/interfaces
	sudo systemctl enable dnsmasq
	sudo systemctl enable hostapd
	pWarn "AP Setup complete - Reboot required to start services..."
}

function configureWPAClient {
	sudo cp ./wpa_supplicant.conf /etc/wpa_supplicant.conf
	sudo systemctl restart wpa_supplicant
}

# Configure Kismet and enable as a service - requires root
function configureKismet {
	pInf "Applying Kismet Configuration."
	sudo mkdir -p /var/log/kismet
	sudo chown pi:kismet /var/log/kismet
	sudo cp ./kismet.conf.advanced /etc/kismet/kismet.conf
	sudo sed -i "s/WIFI_CARD/$ALFA_CARD/g" /etc/kismet/kismet.conf
	pInf "Enabling Kismet service..."	
	sudo cp ./kismet.service /etc/systemd/system
	sudo systemctl daemon-reload
	sudo systemctl enable kismet
}

# Install Kismet from latest release direct from Kismet
function installKismet	{
	SAVED_WD=$PWD
	cd /opt
	sudo git clone https://github.com/kismetwireless/kismet 
	cd kismet && git fetch --all --tags --prune
	git checkout tags/2021-08-R1 -b master	# We're gonna build 2021-08-R1 for now
	./configure
	make -j$(nproc) && sudo make suidinstall
	sudo usermod -aG kismet $USER
	cd $SAVED_WD
}

# Import config file
if [ -f $CONFIG_FILE ]
then
	source $CONFIG_FILE
else
	pErr "Config file: %s not found.\n Exiting...\n\n" $CONFIG_FILE
	exit 1
fi

# Run a full upgrade politely(ish)
while true
	do
		pPrompt 'OK to update/upgrade? [Y/n] '; read -r
          	if [[ $REPLY =~ ^[Yy]$ ]]
		then
			if sudo apt update && sudo apt full-upgrade -y
			then
				break
			else
				pErr "Update error. Exiting."
				exit 1
			fi
         	elif [[ $REPLY =~ ^[Nn]$ ]]
		then
	    		pErr "This script currently supports up-to-date systems only.\nExiting...\n"
	    		exit 1
          	fi
        done

# If SSH VAR is set, configure SSH key only no root pass
if [ "$SSH_LOCKDOWN" = "yes" ] 
then
	configureSSH
fi

# Install required packages
if sudo apt install byobu gpsd gpsd-clients python3-gps aircrack-ng dkms alsaplayer build-essential git libwebsockets-dev pkg-config zlib1g-dev libnl-3-dev libnl-genl-3-dev libcap-dev libpcap-dev libnm-dev libdw-dev libsqlite3-dev libprotobuf-dev libprotobuf-c-dev protobuf-compiler protobuf-c-compiler libsensors4-dev libusb-1.0-0-dev python3 python3-setuptools python3-protobuf python3-requests python3-numpy python3-serial python3-usb python3-dev python3-websockets librtlsdr0 libubertooth-dev libbtbb-dev -y
then
	pInf "Installed required packages"
else
	pErr "Could not install dependencies"
	exit 1
fi

# Install RTL8812AU Driver
if [ -n $(sudo dkms status | grep 8812au | grep -q installed) ]
then
	pInf "8812au Kernel module already seems to be installed. Continuing..."
else
	SAVED_WD=$PWD
	cd /opt
	sudo git clone -b v5.6.4.2 https://github.com/aircrack-ng/rtl8812au.git
	cd rtl8812au
	if sudo make dkms_install
	then 
		pInf "Installed RTL8812AU Driver"
	else
		pErr "Error installing RTL8812AU Driver"
		pWarn "Kismet will probably not run properly"	# No exit because you may be fine with this
	fi
	# Go back where we were
	cd $SAVED_WD
fi

# Install new Kismet
if installKismet
then 
	pInf "Kismet installed successfully."
else
	pErr "Kismet install failed. Exiting..."
	exit 1
fi

# Apply Kismet configuration
if configureKismet
then
	pInf "Kismet Configured"
else
	pErr "Error configuring Kismet. Exiting."
	exit 1
fi

# For newer Pi models, or for Zeros configure built in WAP if needed
if [ ! -v "$AP_SSID" ]
then
	configureAP 
fi


# Stop wpa_supplicant all the time, we don't want for wardriving
pSucc "Installation complete. Stopping wpa_supplicant so you can go driving."
pWarn "You may now lose your SSH connection during reboot."
pLow "If you configured your Pi as an AP, you'll need to connect to that."
sudo systemctl disable wpa_supplicant
sudo systemctl reboot
