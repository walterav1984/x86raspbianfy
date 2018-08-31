#!/bin/bash
#
# host2guest.sh payload.txt telnetport architecture
#
#This script will feed the guestvm its qemu console monitor via telnet with fake 
#scripted keyboard input line by line from a payload file givin by argument. It
#will echo keysend commands, commented progress and wait time in seconds. After 
#the last line it just stops...

telnetport="$2"
iarch="$3"
  
filename="$1"
while read -r line
do
	filtercommentonly=$(echo $line | grep '#')
	echo $filtercommentonly
	filterqemuonly=$(echo $line | grep -v '#' | grep -v wait)
	echo $filterqemuonly | telnet localhost 93$telnetport >/dev/null 2>&1
	echo $filterqemuonly
 	sendkeyact=$(case $(echo $line | grep '#STEPARCHDIFF' | sed -e 's/#//g') in
        STEPARCHDIFF)
            case $iarch in
            i386)
            echo "sendkey up"
            ;;
            amd64)
            echo ""
            ;;
            esac
        ;;
        esac
        )
 	echo $sendkeyact | telnet localhost 93$telnetport >/dev/null 2>&1
	sleep 3
	filterwaittime=$(echo $line | grep wait | sed -e 's/wait//g' -)
	echo $filterwaittime
	sleep $filterwaittime >/dev/null 2>&1
done < "$filename"
