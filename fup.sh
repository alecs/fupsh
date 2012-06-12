#!/bin/sh
#
# fup.sh - shitty QoS solution, cron based for pptpd
# servers that need some bandwidth throttling.
#
# prolly GPL.
#
# Authors:
#
# Alex Negulescu <alecs@hol.ro>
# Ovidiu Popa <ovidiu@hol.ro>
#
# Changelog:
#
# * Mon Jun 11 2012 Alex Negulescu <alecs@hol.ro> 0.1.5-qa
#   - added LUSERS to log limited users presence
#   - added dependencies check
# * Mon Jun 11 2012 Popa Ovidiu <ovidiu@hol.ro> 0.1.5
#   - added L flag option in admin (meaning the adresses
#     limited by LIMIT var)
# * Fri May 18 2012 Alex Negulescu <alecs@hol.ro> 0.1.4
#   - fixed custom limits admin test
#   - replaced the fixed for with case
# * Fri May 18 2012 Ovidiu Popa <ovidiu@hol.ro> 0.1.3
#   - fixed a for in the admins check
#   - added check for admins, within a case, in custom
#     limits
# * Thu May 17 2012 Alex Negulescu <alecs@hol.ro> 0.1.2
#   - added ADMINS - unlimited bandwidth
# * Fri Mar 23 2012 Alex Negulescu <alecs@hol.ro> 0.1.1
#   - added custom cases
# * Sat Mar 15 2012 Alex Negulescu <alecs@hol.ro> 0.1.0
#   - basic script
#
#######################################################################
COUNT=`/sbin/ip ad | grep ppp | grep 172.17.72 | wc -l`
DEVICES=`/sbin/ip ad | grep ppp | grep 172.17.72 | cut -d"/" -f2 | cut -f4 -d" "`
ADMINS="172.17.72.9/32 172.17.72.90/32L"
LIMIT=3000
BW=50000
FUP=$[$BW/$COUNT]
DATE=`date +"%d/%m/%y %H:%M:%S"`

if [[ ! -e /sbin/ip || ! -e /sbin/tc ]];then
    echo "You need to install iputils for this to work."
    echo "Type *apt-get install iputils* to install the package."
    exit
fi

case "$1" in
	apply)
		echo "Script ran at ${DATE}"
		echo "Connected: ${COUNT}users"
		echo "Total bandwidth: ${BW}kbit"
		echo "Per capita: ${FUP}kbit"
		for CON in ${DEVICES};do
			IPAD=`/sbin/ip ad sh dev ${CON} | grep inet | awk '{print $4}'`
			if [ `/sbin/tc class show dev ${CON} | wc -l` -ge 1 ];then
				case $ADMINS in
					*"${IPAD}L"*)
						echo "${CON} has L flag, limit to ${LIMIT}kbit"
						/sbin/tc class change dev ${CON} parent 1: classid 1:10 htb rate ${LIMIT}kbit burst 8
						LUSERS=$[$LUSERS+1]
						;;
					*$IPAD*)
						echo "${CON} is admin, no limit"
						/sbin/tc class change dev ${CON} parent 1: classid 1:10 htb rate 100000kbit burst 8
						CADMIN=$[$CADMIN+1]
						;;
					*)
						echo "Set ${FUP}kbit download limit for ${CON}"
						/sbin/tc class change dev ${CON} parent 1: classid 1:10 htb rate ${FUP}kbit burst 8
						;;
				esac
			else
				echo "${CON} had no limit, adding ${FUP}kbit"
				/sbin/tc qdisc add dev ${CON} root handle 1: htb r2q 256
				/sbin/tc class add dev ${CON} parent 1: classid 1:10 htb rate ${FUP}kbit burst 8k
				/sbin/tc qdisc add dev ${CON} parent 1:10 handle 10: sfq perturb 10
				/sbin/tc filter add dev ${CON} protocol ip parent 1:0 prio 1 u32 match ip dst 172.17.72.0/24 classid 1:10
			fi
		done
		echo "Ran script at ${DATE}. There were ${COUNT} connected users, of wich ${CADMIN} admins and ${LUSERS} limited, and I set a limit of ${FUP}kbit for the users." >> /root/configs/fup.log
	;;
	flush)
		for CON in ${DEVICES};do
			if [ `/sbin/tc class show dev ${CON} | wc -l` -ge 1 ];then
				echo "Set ${BW}kbit download limit for ${CON}"
				/sbin/tc class change dev ${CON} parent 1: classid 1:10 htb rate ${BW}kbit burst 8
			else
				echo "${CON} had no limit at the moment"
			fi
		done
		echo "Ran script at ${DATE}. There were ${COUNT} connected users, of wich ${CADMIN} admins and ${LUSERS} limited, and I set a limit of ${BW}kbit for each of them." >> /root/configs/fup.log
	;;
	custom)
		if [[ ! -z $2 && $2 =~ ^[0-9]+$ ]];then
		echo "Connected: ${COUNT}users"
		echo "Total bandwidth: ${BW}kbit"
		echo "Per capita: ${FUP}kbit"
		FUP=$2
		echo "Per capita (enforced): ${FUP}kbit"
			for CON in ${DEVICES};do
			IPAD=`/sbin/ip ad sh dev ${CON} | grep inet | awk '{print $4}'`
				if [ `/sbin/tc class show dev ${CON} | wc -l` -ge 1 ];then
					case $ADMINS in
						*"${IPAD}L"*)
							echo "${CON} has L flag, limit to ${LIMIT}kbit"
							/sbin/tc class change dev ${CON} parent 1: classid 1:10 htb rate ${LIMIT}kbit burst 8
							LUSERS=$[$LUSERS+1]
							;;
						*$IPAD*)
							echo "${CON} is admin, no limit"
							/sbin/tc class change dev ${CON} parent 1: classid 1:10 htb rate 100000kbit burst 8
							CADMIN=$[$CADMIN+1]
							;;
						*)
							echo "Set ${FUP}kbit download limit for ${CON}"
							/sbin/tc class change dev ${CON} parent 1: classid 1:10 htb rate ${FUP}kbit burst 8
							;;
					esac
				else
					echo "${CON} had no limit, adding ${FUP}kbit"
					/sbin/tc qdisc add dev ${CON} root handle 1: htb r2q 256
					/sbin/tc class add dev ${CON} parent 1: classid 1:10 htb rate ${FUP}kbit burst 8k
					/sbin/tc qdisc add dev ${CON} parent 1:10 handle 10: sfq perturb 10
					/sbin/tc filter add dev ${CON} protocol ip parent 1:0 prio 1 u32 match ip dst 172.17.72.0/24 classid 1:10
				fi
			done
			echo "Ran script at ${DATE}. There were ${COUNT} connected users, of wich ${CADMIN} admins and ${LUSERS} limited, and I set a limit of ${FUP}kbit for each of them." >> /root/configs/fup.log
		else
			echo "Expecting parameter."
		fi
	;;
	*)
		echo "Usage: $0 apply|flush"
		echo "apply  - apply new bandwidth limit"
		echo "flush  - remove limits"
		echo "custom - add custom limit (requires bandwidth as a parameter, in kbit)"
esac
