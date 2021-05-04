[ -z $BASH ] && { exec bash "$0" "$@" || exit; }
#!/bin/bash

if [ -z "$1" ] ; then
	echo "Error: Missing argument mode (run,start,stop,set-apn)."
    exit 1
fi

# global variables
time_started=`date +%s`

# functions
reconnect_modem () {
	PINGip=8.8.8.8
	TIMEOUT=15
	VENDOR=$1
	PRODUCT=$2
	# Reconnect device if no internet connection.
	if [ -n "$(/bin/ping -q -W$TIMEOUT -c4 $PINGip | grep '0 received')" ]; then
		echo ">>> $PINGip is not reachable. => Reconnecing device $VENDOR:$PRODUCT"
		for DIR in $(find /sys/bus/usb/devices/ -maxdepth 1 -type l); do
			if [[ -f $DIR/idVendor && -f $DIR/idProduct &&
						$(cat $DIR/idVendor) == $VENDOR && $(cat $DIR/idProduct) == $PRODUCT ]]; then
				echo 0 > $DIR/authorized
				sleep 0.5
				echo 1 > $DIR/authorized
			fi
		done
	else
		echo ">>> Ping $PINGip succeeded."
	fi
}

connect_modems () {
	usb_modeswitch -v 12d1 -p 14fe -V 12d1 -P 1506 -M "55534243123456780000000000000011060000000000000000000000000000"
}

kill_old_wvdial () {
	# Kill a old wvdial process if ppp0 does not show up anymore
	pppExists=$(ip link show ppp0 | grep -c UP)
	if [ $pppExists != "1" ]; then
			time_stopped=`date +%s`
			time_running=$((time_stopped-time_started))
			echo ">>> ppp0 does not show up => Clean old processes. Runtime was $time_running seconds"
			killall wvdial
	fi
}

start_wvdial () {
	# Check if modem is connected (/dev/ttyUSB0 does exist)
	if ls -la /dev/$ttyUSB 2>/dev/null; then
		# Check if wvdial process is running
		if ! ps -C wvdial
				then
						echo ">>> No wvdial process running... Start WvDial to connect modem to internet."
						wvdial >> /home/pi/HoneyPi/rpi-scripts/wvdial.log 2>&1&
						time_started=`date +%s`
				fi
	fi
}

# main routine
run () {
		while true; do
			# Run usb_modewitch rule for specific surfsticks
			connect_modems
			# Check if wvdial process is running
			start_wvdial
		sleep 180
			# Kill a old wvdial process if ppp0 does not show up anymore
		kill_old_wvdial
		sleep 5
			reconnect_modem "12d1" "14dc"
			reconnect_modem "12d1" "1506"
	
		done
}

dialPPP(){
	if ls -la /dev/$ttyUSB 2>/dev/null; then
		# Check if wvdial process is running
		if ! ps -C wvdial
				then
						echo ">>> No wvdial process running... Start WvDial to connect modem to internet."
						wvdial $@ >> /home/pi/HoneyPi/rpi-scripts/wvdial.log 2>&1&
						time_started=`date +%s`
				fi
	fi
}
if [ "$1" = "dialPPP" ] ; then
	if [ -f /var/run/connection.pid ] ; then
		if ( ps -p $(cat /var/run/connection.pid) | grep pts ) ; then
			echo ">>>Process already running with PID $(cat /var/run/connection.pid)..."
		else
			echo ">>>Pid file existed but process was dead!"
			echo $$ >/var/run/connection.pid
			shift
			dialPPP $@ 
		fi
	else
		echo $$ >/var/run/connection.pid
		shift	
		dialPPP $@ 
	fi
elif [ "$1" = "run" ] ; then
	if [ -f /var/run/connection.pid ] ; then
		if ( ps -p $(cat /var/run/connection.pid) | grep pts ) ; then
			echo ">>>Process already running with PID $(cat /var/run/connection.pid)..."
		else
			echo ">>>Pid file existed but process was dead!"
			echo $$ >/var/run/connection.pid
			run
		fi
	else
		echo $$ >/var/run/connection.pid
		run
	fi
elif [ "$1" = "start" ] ; then
	if [ -f /var/run/connection.pid ] ; then
		if ( ps -p $(cat /var/run/connection.pid) | grep pts ) ; then
			echo ">>>Process already running with PID $(cat /var/run/connection.pid)..."
		else
			echo ">>>Pid file existed but process with PID $(cat /var/run/connection.pid) was dead!"
			echo $$ >/var/run/connection.pid
			run
		fi
	else
		echo $$ >/var/run/connection.pid
		run
	fi
elif [ "$1" = "stop" ] ; then
	if [ -f /var/run/connection.pid ] ; then
		killall wvdial
		kill -9 $(cat /var/run/connection.pid)
		rm /var/run/connection.pid
	fi
elif [ "$1" = "set-apn" ] ; then
    if [ -z "$2" ] ; then
    	echo "Warning: Missing argument APN."
        APN="pinternet.interkom.de" # default: NetzClub
    else
        APN="$2"
    fi

	if [ -z "$3" ] ; then
    	echo "Warning: Missing argument ttyUSB."
        ttyUSB="ttyUSB0" # default: ttyUSB0
    else
        ttyUSB="$3"
    fi

    export APN && export ttyUSB
    # Create the config for wvdial
    cat /etc/wvdial.conf.tmpl | envsubst > /etc/wvdial.conf
elif [ "$1" = "set-ppp" ] ; then
	shift
	apn='internet.interkom.de'
	interface="ttyAMA0"
	modem="sim800x"
	user=" "
	password=" "
	phone="*99#"
	pin=""
	

	while getopts a:i:m:u:p:t:n: flag
	do
    	case "${flag}" in
    	    a) apn=${OPTARG};;
    	    i) interface=${OPTARG};;
    	    m) modem=${OPTARG};;
			u) user=${OPTARG};;
			p) password=${OPTARG};;
			t) phone=${OPTARG};;
			n) pin=${OPTARG};;
    	esac
	done

echo $apn

	# enable uart interace
	bash ./utils/enable_uart.sh

	# copy settings for modem
	mv ./templates/wvdial.set.templ /etc/ppp/peer/peers/wvdial

	# set config with parameters
	APN=$apn
	ttyUSB=$interface
	USERNAME=$user
	PASSWORD=$password
	PHONE=$phone
	PIN=$pin

	export APN && export ttyUSB  && export USERNAME  && export PASSWORD  && export PHONE && export PIN

	# Create the config for wvdial
	#cat /etc/wvdial.conf.tmpl | envsubst > /etc/wvdial.conf
    cat /etc/wvdial.conf | envsubst <./templates/pppd/wvdial.conf.templ > ./wvdial.conf
else
    echo "Error: Unknown argument."
    exit 1
fi

exit 0
