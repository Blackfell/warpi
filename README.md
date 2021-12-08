# WarPi

## Let's go Wardriving again! 

I love my [pwnagotchi](https://pwnagotchi.ai), but there's something about
GPS wardriving all the frequencies that is just a bit more fun. This script is
to get me set up to go wardriving on my old 
[Raspberry Pi 2B](https://www.raspberrypi.com/products/raspberry-pi-2-model-b/)
in a few minutes. Just like that. 

## Shopping list

This may work on your debain spin on any host, but has only been tested on a
Pi 2B, so starting with one of those is probably a good idea.

As I write this, [Kismet](https://www.kismetwireless.net) is still the best 
turnkey wardriving solution and the 
[Alfa AWUS036ACH](https://www.alfa.com.tw/products/awus036ach) is the best 
looking WiFi card out there RN.

As for GPS adapters I like
[GT-U7 based adapters](https://hobbycomponents.com/wired-wireless/1069-gt-u7-gps-module-with-eeprom-and-active-antenna)
, in part because I have future ambitions to update this project with some 
nice hardware/software updates in future, but also because they're cheap and 
will take a different IPEX antenna if we want. 

# Get Setup

## Start at the start

This is for a RPi 2B install, so get yourself one of them. Pop an SD card in 
your PC and set the imager going. The new 
[Official Imager](https://www.raspberrypi.com/news/raspberry-pi-imager-imaging-utility/) 
is kind of nice. I just use the lite (no desktop) image, because that's all 
we need. 

For fancy Linux folks, go old faithful:

```bash
sudo dd if=some_rpi_image_path.img of=/dev/definately_the_right_disk status=progress
```

### Post-Flash Pi Config

If you mess with Pi stuff, this won't be news to you, but if not, get your 
brew/coffee in while that's flashing, but when it's done STOP. Don't even 
un-plug that SD card. 

With the card still in your machine, find the boot partition (usually so 
named) and create a blank file called 'ssh'. This enables ssh - neat, right?
On Linux, this might look like:

```bash
blackfell@secretbase~$ mount | grep boot
[...SNIP...]
/dev/sda on /run/media/boot type [...SNIP...]
blackfell@secretbase~$ sudo touch /run/media/boot/ssh
```

Hopefully you have a wired network and you can connect your Pi to some network
you're working on and hey-presto DHCP does magic and you can talk. If not, you 
can configure wpa_supplicant and a WiFi card, or just use HDMI and console right 
in. If you're putting your Pi on the network, Linux has us covered to find it:

```bash
blackfell@secretbase~$ sudo netdiscover -P
_____________________________________________________________________________
   IP            At MAC Address     Count     Len  MAC Vendor / Hostname      
-----------------------------------------------------------------------------
192.168.1.42	b8:27:ca:fe:f0:0d	1	60 Raspberry Pi Foundation
```

Or you can use (in order of cool) arp, cmd/PowerShell, nmap, fing or your 
home router admin panel to find the IP. 

It's probably a good idea to:

```bash
blackfell@secretbase~$ sudo ssh-copy-id -i ~/.ssh/id_rsa pi@192.168.1.42
blackfell@secretbase~$ sudo ssh -i ~/.ssh/id_rsa pi@192.168.1.42
pi@192.168.1.42~$ passwd
```

Just to be safe :)

## Get configured fully

This repo is meant to be run directly on your Pi, so we don't have to worry 
about working over network, serial, keyboard etc. we just run stuff on the Pi.
For this to work, you will need to get your Pi networked so it can get this 
repo on disk. Just hook up network access if you don't already have it and 
install the mighty Git, plus this repo:

```bash
pi@192.168.1.42~$ sudo apt install git
pi@192.168.1.42~$ git clone https://github.com/blackfell/warpi
cd warpi && cp warpi.conf.example warpi.conf
```

Once that's done, you are free to tweak a few (very limited settings) in warpi.conf, 
but you should be running a Pi, with one USB WiFi card and one USB GPS dongle, 
so settings can just be left as default and stuff will hopefully just work. 

That means it's just one line to get the Pi 2B version running for most people:

```bash
./setup.sh
```

Hit Y and go for coffee. 

When asked, always install tools like tshark, Kismet etc. with elevated (may
be called SUID) privilege and if you're asked about adding a user to a group, 
that user should be 'pi' without the quotes. Just agree everything OK? 

Now when you reboot your Pi, it will automagically run kismet as a service.

# Now use it

## Do wardriving stuff

Now plug all your stuff in, get a powerbank and go wardriving - yay! 

If you want to check Kismet status during drives, you can do so by SSH-ing
into your Pi and running `kismet_client` in a terminal. This can be done on
the fly, but we haven't configured a static IP on the Pi to ensure this will 
always work.

If it's the same day, chances are the IP assigned by your home LAN is still 
valid and you can conenct point-to-point with a laptop. 

# Other notes

## Where logs at?

Your Kismet logs will be on your Pi at /var/log/kismet. Enjoy.

## Configuration Options

Config options are very basic and in beta, tweak with caution.

### Restart Interval

This is the most janky setting, a Cron job will restart kismet every 10 mins
by default, to ensure logs roll over in a semi-safe way, so on power loss, 
only 10 mins of logs are lost worse case. 

If you like long or short wardriving sessions, you may choose to increase or 
decrease this interval accordingly, but the script will only work well for 
intervalse between 1 and 60 mins currently because of cron syntax. 

### Device names

You can configure the name of the WiFi and GPS devices to be used in the Pi, 
but unless yoyu're adding additional devices, there should be no need. 

## Audio

Audio is enabled on Kismet server, so feel free to hook up some headphones 
or a speaker to get alerts for new networks, packets, gps locka nd loss and 
alerts. 

# What's next?

This config used legacy Kismet and some workarounds for log rotation. I'm also 
not happy with the monitoring and shutdown situation, so I'd like to migrate to 
'new' Kismet, maybe taking advantage of the Pi's lovely GPIO to help with 
graceful notification and shutdown.

Let me know, or just submit a PR if you want to. 
