#!/bin/bash

# Globals
CONFIG_FILE="./warpi.conf"

# Print out error messages
# $1 is the message
function pErr {
	printf "[${colors[RED]}!${colors[DEFAULT]}] - $1\n"
}
function pSucc {
	printf "[${colors[GREEN]}!${colors[DEFAULT]}] - $1\n"
}
function pInf {
	printf "[${colors[BLUE]}+${colors[DEFAULT]}] - $1\n"
}
function pDebug {
	printf "[${colors[RED]}+${colors[DEFAULT]}] - $1\n"
}
function pWarn {
	printf "[${colors[YELLOW]}+${colors[DEFAULT]}] - $1\n"
}
function pLow {
	printf "[${colors[MAGENTA]}-${colors[DEFAULT]}] - $1\n"
}
function pPrompt {
	printf "[${colors[MAGENTA]}\?${colors[DEFAULT]}] - $1"
}

# Configure SSH on this Pi, key only if required $1 - Authorised key data
function configureSSH {
	# No root login with password
	sudo sed -i "s/^#\s{0,4}PermitRootLogin/PermitRootLogin/g" /etc/ssh/sshd_config
	# Key only auth
	sudo sed -i "s/^#\s{0,4}PasswordAuthenitcation yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
}

# Configure Kismet and enable as a service - requires root
function configureKismet {
	pInf "Applying Kismet Configuration."
	mkdir -p /var/log/kismet
	chown pi:kismet /var/log/kismet
	cp ./kismet.conf /etc/kismet/kismet.conf
	sed -i "s/WIFI_CARD/$ALFA_CARD/g" /etc/kismet/kismet.conf
	pInf "Enabling Kismet service..."	
	cp ./kismet.service /etc/systemd/system
	systemctl daemon-reload
	systemctl enable kismet
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
if [ -z $SSH_LOCKDOWN ] 
then
	configureSSH
fi

# Install required packages
if sudo apt install byobu gpsd gpsd-clients python3-gps kismet aircrack-ng git tshark dkms alsaplayer libpcap0.8-dev libusb-1.0-0-dev libnetfilter-queue1 libnetfilter-queue-dev
then
	pInf "Installed required packages"
else
	pErr "Could not install dependencies"
	exit 1
fi

# Install Bettercap
#go get github.com/bettercap/bettercap
#cd $GOPATH/src/github.com/bettercap/bettercap
#make build
#sudo make install

# Install RTL8812AU Driver
cd /opt
sudo git clone -b v5.6.4.2 https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au
if sudo make dkms_install
then 
	pInf "Installed RTL8812AU Driver"
else
	pErr "Error installing RTL8812AU Driver"
	exit 1
fi

# Apply Kismet configuration
if sudo configureKismet
then
	pInf "Kismet Configured"
else
	pErr "Error configuring Kismet. Exiting."
	exit 1

# Running Bettercap - TODO in future??
# docker run -it --privileged --net=host bettercap/bettercap -h

if echo -e "*/$RESTART_INTERVAL *\t* * *\troot\tsystemctl restart kismet" | sudo tee -a /etc/crontab
then
	pSucc "Installation complete. Stopping wpa_supplicant so you can go driving."
else
	pErr "Error setting up Kismet reset Crontab."
	exit 1

pWarn "You may lose WiFi connectivity. Byeeee....."

# Stop wpa_supplicant all the time, we don't want for wardriving
sudo systemctl disable wpa_supplicant
sudo systemctl stop wpa_supplicant
