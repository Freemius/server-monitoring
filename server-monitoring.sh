#!/bin/bash
PATH=/usr/sbin:/sbin:/usr/bin:/bin

# ==========================
# Server monitoring script
# 
# Usage examples:
#    // Check current server metrics (CPU, RAM, DISK).
#    bash server-monitoring.sh --info=true
#
#    // Monitor server.
#    bash server-monitoring.sh --debug=true --hostname=fs.app --from=server@yourdomain.com --to=admin@yourdomain.com --cpu=warning=20:critical=50 --memory=warning=30:critical=60 --disk=warning=40:critical=60:fatal=70
#
#	 // Cronjob that monitors server's health every 2 min.	
#	 */2 * * * * bash /server-monitoring/server-monitoring.sh --hostname=fs.app --from=server@yourdomain.com --to=admin@yourdomain.com --cpu=warning=20:critical=50 --memory=warning=30:critical=60 --disk=warning=40:critical=60:fatal=70
#
#    All arguments except --debug, --hostname, and --info are required.
#
# Author: Vova Feldman
# Company: Freemius, Inc.
# Website: https://freemius.com
#
# License MIT (https://opensource.org/licenses/MIT):
# --------------------------------------------------
# Copyright 2017 Freemius, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# ==========================

# Parse script arguments
# ==========================
for i in "$@"
do
case $i in
    -f=*|--from=*)
    FROM_EMAIL="${i#*=}"
    shift # past argument=value
    ;;
    -t=*|--to=*)
    TO_EMAIL="${i#*=}"
    shift # past argument=value
    ;;
    -c=*|--cpu=*)
    CPU="${i#*=}"
    shift # past argument=value
    ;;
    -m=*|--memory=*)
    MEMORY="${i#*=}"
    shift # past argument=value
    ;;
    -d=*|--disk=*)
    DISK="${i#*=}"
    shift # past argument=value
    ;;
    --debug=*)
    DEBUG="${i#*=}"
    shift # past argument=value
    ;;
    -h=*|--hostname=*)
    HOSTNAME="${i#*=}"
    shift # past argument=value
    ;;
    -i=*|--info=*)
    INFO="${i#*=}"
    shift # past argument=value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument with no value
    ;;
    *)
          # unknown option
    ;;
esac
done

# Set default values
# ==========================
if [ -z ${DEBUG+x} ]; then
    DEBUG="false"
fi

if [ -z ${HOSTNAME+x} ]; then
    HOSTNAME=$( hostname )
fi

# Detect distribution, for required module install later
# =======================================================
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "" ]; then OS=$ID; elif [ "$NAME" != "" ]; then OS=$NAME; fi
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/redhat-release ]; then
    # Older CentOS
    OS=$(cat /etc/redhat-release | cut -f 1 -d " ")
    VER=$(cat /etc/redhat-release | cut -f 3 -d " ")
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi
# Distribution name should be lowercase
DIST=$(echo $OS | tr '[:upper:]' '[:lower:]')

# Install missing modules
# ==========================
case "$DIST" in
    "debian*"|"ubuntu*")
        if ! type "sendmail" > /dev/null; then
          	echo "Installing Postfix for sendmail command..."

	        apt-get install -y postfix
        fi
        if ! type "bc" > /dev/null; then
          	echo "Installing bc (an arbitrary precision calculator language)..."

	        apt-get -y install bc
        fi
        if ! type "mpstat" > /dev/null; then
          	echo "Installing sar, sadf, mpstat, iostat, pidstat and sa tools..."

	        apt-get -y install sysstat
        fi
    ;;
    "centos*")
        if ! type "sendmail" > /dev/null; then
          	echo "Installing Sendmail..."

	        yum install -y sendmail
	        service sendmail start
	        chkconfig --levels 2345 sendmail on
        fi
        if ! type "bc" > /dev/null; then
          	echo "Installing bc (an arbitrary precision calculator language)..."

	        yum install -y bc
        fi
        if ! type "mpstat" > /dev/null; then
          	echo "Installing sar, sadf, mpstat, iostat, pidstat and sa tools..."

	        yum -y install sysstat
        fi
    ;;
    *)
        if ! type "sendmail" > /dev/null; then
            echo "You need sendmail to run this script, please install it manually"
            exit 127
        fi   
        if ! type "bc" > /dev/null; then
            echo "You need bc to run this script, please install it manually"
            exit 127
        fi
        if ! type "mpstat" > /dev/null; then
            echo "You need mpstat to run this script, please install it manually"
            exit 127
        fi
    ;;
esac

# Helper functions
# ==========================
get_server_ip () {
	ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'
}

echo_debug () {
	if [ $DEBUG = "true" ]; then
		echo $1
	fi
}

get_cpu_usage () {
	local CPU_IDLE=$( mpstat | grep -Po 'all.* \K[^ ]+$' | sed 's/\,/./' )
	local CPU_LOAD=$( bc <<< "100 - $CPU_IDLE" )
	echo "(${CPU_LOAD}+0.5)/1" | bc
	#top -b -n11 | awk '/^Cpu/ {print $2}' | cut -d. -f1
}

get_memory_usage () {
	local TOTAL_MEM=$( free -m | awk 'NR==2{print $2}' )
	local USED_MEM=$( free -m | awk 'NR==3{print $3}' )
	local USED_MEM_PERCENTAGE=$( bc <<< "100 * $USED_MEM / $TOTAL_MEM" )
	echo "${USED_MEM_PERCENTAGE}"
}

get_disk_usage () {
	local DEVICES
	IFS=$'\n'; DEVICES=( $( cat /etc/mtab | grep '^/dev' | awk '{print $1}' ) )
	local DISKS_USAGE=( )
	local I=0

	for DEVICE in "${DEVICES[@]}"
	do
		local DISK_USAGE=$( df "${DEVICE}" | grep '%' | awk '{if(NR>1)print $(NF-1)}' | cut -d '%' -f 1 )
		DISKS_USAGE[I]="${DEVICE}"
		I=$((I+1))
		DISKS_USAGE[I]="${DISK_USAGE}"
		I=$((I+1))
	done
	
	echo "${DISKS_USAGE[*]}"
}

get_incident_filename () {
	# Parse function arguments.
	local METRIC_NAME=$( echo $1 | tr "/" "-" )
	local SEVERITY=$2

	if [ "${METRIC_NAME:0:1}" = "-" ]; then
		# Trim first '-'.
		METRIC_NAME=${METRIC_NAME:1:${#METRIC_NAME}}
	fi

	echo "./${METRIC_NAME}-${SEVERITY}.lock"

}

is_incident_open () {
	# Parse function arguments.
	local METRIC_NAME=$1
	local SEVERITY=$2

	local INCIDENT_FILE=$( get_incident_filename $METRIC_NAME $SEVERITY )

	if [ ! -f $INCIDENT_FILE ]; then
	    echo "false"
	else
		echo "true"
	fi
}

start_incident () {
	# Parse function arguments.
	local METRIC_NAME=$1
	local METRIC_VALUE=$2
	local SEVERITY=$3
	local LIMIT=$4

	local INCIDENT_ID=$RANDOM
	local INCIDENT_FILE=$( get_incident_filename $METRIC_NAME $SEVERITY )
	local START_TIME=$( date +%s )

	cat > $INCIDENT_FILE << EOF
INCIDENT_ID=${INCIDENT_ID}
START_TIME=${START_TIME}
EOF

	prepare_alert $INCIDENT_ID OPENED $METRIC_NAME $METRIC_VALUE $SEVERITY $LIMIT $START_TIME

	# Send email
	cat ./alert_email.txt | /usr/sbin/sendmail $TO_EMAIL
}

close_incident () {
	# Parse function arguments.
	local METRIC_NAME=$1
	local METRIC_VALUE=$2
	local SEVERITY=$3
	local LIMIT=$4

	local END_TIME=$( date +%s )

	local INCIDENT_FILE=$( get_incident_filename $METRIC_NAME $SEVERITY )

	IFS="="
	while read -r NAME VALUE
	do
		if [ $NAME = 'INCIDENT_ID' ]; then
			local INCIDENT_ID=$VALUE
		fi
		if [ $NAME = 'START_TIME' ]; then
			local START_TIME=$VALUE
		fi
	done < $INCIDENT_FILE

	prepare_alert $INCIDENT_ID CLOSED $METRIC_NAME $METRIC_VALUE $SEVERITY $LIMIT $START_TIME $END_TIME

	# Send email
	cat ./alert_email.txt | /usr/sbin/sendmail $TO_EMAIL

	# Delete incident file.
	rm -f "${INCIDENT_FILE}"
}

prepare_alert () {
	local INCIDENT_ID=$1
	local INCIDENT_STATUS=$2
	local METRIC_NAME=$3;
	local METRIC_VALUE=$4
	local SEVERITY=$5
	local LIMIT=$6
	local START_TIME=$7
	local END_TIME
	local DURATION

	if [ $# = 8 ]; then
		END_TIME=$8
		DURATION=$((END_TIME-START_TIME))

		if (( $DURATION > 60 )); then
			DURATION=$((DURATION/60))
			DURATION="${DURATION} min"
		else
			DURATION="${DURATION} sec"
		fi

		# Format datetime.
		END_TIME=$( date -d @$END_TIME)
	fi

	# Format datetime.
	START_TIME=$( date -d @$START_TIME)

	local SERVER_IP=$( get_server_ip )

	local COLOR='green'

	if [ $INCIDENT_STATUS = 'OPENED' ]; then
		COLOR='red'
	fi

	# Delete previous alert file.
	rm -f ./alert_email.txt

	cat > ./alert_email.txt << EOF
From: Server ${HOSTNAME} <${FROM_EMAIL}>
To: ${TO_EMAIL}
Subject: Incident ${INCIDENT_ID} ${INCIDENT_STATUS}: ${HOSTNAME} ${SERVER_IP} ${METRIC_NAME}
Content-Type: text/html
MIME-Version: 1.0

<div style="background: #fff; padding: 20px;">
	<table cellspacing="0" cellpadding="10px">
		<tr>
			<td style="background: yellow">Status:</td>
			<td style="background: yellow"><b style="color: ${COLOR}">${INCIDENT_STATUS}</b></td>
		</tr>
		<tr>
			<td>Metric:</td>
			<td>${METRIC_NAME} = ${METRIC_VALUE}% (&gt; ${LIMIT}%)</td>
		</tr>
		<tr>
			<td style="background: #ddd">Sevirity:</td>
			<td style="background: #ddd">${SEVERITY}</td>
		</tr>
		<tr>
			<td>Server:</td>
			<td>${HOSTNAME} (${SERVER_IP})</td>
		</tr>
		<tr>
			<td style="background: #ddd">Start:</td>
			<td style="background: #ddd">${START_TIME}</td>
		</tr>
		<tr>
			<td>End:</td>
			<td>${END_TIME}</td>
		</tr>
		<tr>
			<td style="background: #ddd">Duration</td>
			<td style="background: #ddd">${DURATION}</td>
		</tr>
	</table>
</div>
EOF
}

if [ $INFO = "true" ]; then
	echo "CPU:"
	get_cpu_usage
	echo "MEMORY:"
	get_memory_usage
	echo "DISK:"
	get_disk_usage
	exit
fi

if [ $DEBUG = "true" ]; then
	clear
	echo "DEBUG    = true"
	echo "CPU      = ${CPU}"
	echo "MEMORY   = ${MEMORY}"
	echo "DISK     = ${DISK}"
	echo "HOSTNAME = ${HOSTNAME}"
fi

# Main logic
# ==========================
METRICS=('cpu' 'memory' 'disk')
SETTINGS=($CPU $MEMORY $DISK)


for (( i=0; i<3; i++ ))
do
	METRIC_NAME="${METRICS[$i]}";
	METRIC_NAME_UPPER="$( echo $METRIC_NAME | awk '{print toupper($0)}' )"

	echo_debug "[${METRIC_NAME}] Checking ${METRIC_NAME}..."

	SETTING="${SETTINGS[$i]}";
	SETTING=(${SETTING//:/ })

	METRIC_VALUES=( $( get_${METRIC_NAME}_usage ) )

	if [[ $METRIC_NAME != 'disk' ]];then 
		METRIC_VALUES=( $METRIC_NAME ${METRIC_VALUES[0]} )
		METRIC_VALUES_COUNT=2
	else
		METRIC_VALUES_COUNT=${#METRIC_VALUES[@]}
		for (( j=0; j<$METRIC_VALUES_COUNT; j++ ))
		do
			if [ $(( $j % 2)) -eq 0 ]; then
				METRIC_VALUES[j]="${METRIC_VALUES[j]}-${METRIC_NAME}"
			fi
		done
	fi 

	for LEVEL in "${SETTING[@]}"
	do
		L=(${LEVEL//=/ })
		SEVIRITY="${L[0]}"
		LIMIT="${L[1]}"

		#echo_debug "==============================="
		#echo_debug "LEVEL = ${LEVEL}"
		#echo_debug "SEVIRITY = ${SEVIRITY}"
		#echo_debug "LIMIT = ${LIMIT}"

		for (( j=0; j<$METRIC_VALUES_COUNT; j++ ))
		do
			METRIC_NAME="${METRIC_VALUES[j]}"
			j=$((j+1))
			METRIC_VALUE="${METRIC_VALUES[j]}"

			echo_debug "[${METRIC_NAME}] [${SEVIRITY}] ${METRIC_NAME} = ${METRIC_VALUE}%"

			IS_INCIDENT_OPEN=$( is_incident_open $METRIC_NAME $SEVIRITY )

			if [ $IS_INCIDENT_OPEN == "true" ]; then
				echo_debug "[${METRIC_NAME}] [${SEVIRITY}] Incident already open"
			fi

			if (( $METRIC_VALUE > $LIMIT )); then
				echo_debug "[${METRIC_NAME}] [${SEVIRITY}] ${METRIC_NAME} > ${LIMIT}%, oops..."

				if [ $IS_INCIDENT_OPEN != "true" ]; then
					echo_debug "[${METRIC_NAME}] [${SEVIRITY}] Starting incident..."

					start_incident $METRIC_NAME $METRIC_VALUE $SEVIRITY $LIMIT

					echo_debug "[${METRIC_NAME}] [${SEVIRITY}] Incident OPENED"
				fi
			else
				echo_debug "[${METRIC_NAME}] [${SEVIRITY}] ${METRIC_NAME} < ${LIMIT}%, so all good!"

				if [ $IS_INCIDENT_OPEN == "true" ]; then
					echo_debug "[${METRIC_NAME}] [${SEVIRITY}] Closing incident..."

					$( close_incident $METRIC_NAME $METRIC_VALUE $SEVIRITY $LIMIT )

					echo_debug "[${METRIC_NAME}] [${SEVIRITY}] Incident CLOSED"
				fi
			fi
		done
	done
done
