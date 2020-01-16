#!/bin/bash
#
# host2guest.sh payload.txt telnetport architecture disksize
#
#This script will feed the guestvm its qemu console monitor via nc -N with fake 
#scripted keyboard input line by line from a payload file givin by argument. It
#will echo keysend commands, commented progress and wait time in seconds. After 
#the last line it just stops...

filename="$1"
telnetport="$2"
iarch="$3"
dsize=$4

echo "host2guest input $filename $telnetport $iarch $dsize"

while read -r line
do
	filtercommentonly=$(echo $line | grep '#')
	echo $filtercommentonly
	filterqemuonly=$(echo $line | grep -v '#' | grep -v wait)
	echo $filterqemuonly | nc -N 127.0.0.1 $telnetport >/dev/null 2>&1
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
 	echo $sendkeyact | nc -N 127.0.0.1 $telnetport >/dev/null 2>&1
 	sendkeybct=$(case $(echo $line | grep '#STEPSIZEDIFF' | sed -e 's/#//g') in
        STEPSIZEDIFF)
            case $dsize in
                        1GB)
                        echo "sendkey 1"
                           ;;
                        2GB)
                        echo "sendkey 2"
                           ;;
			4GB)
                        echo "sendkey 2"
                           ;;
            esac
           ;;
       esac
      )
 	echo $sendkeybct | nc -N 127.0.0.1 $telnetport >/dev/null 2>&1
 	sendkeycct=$(case $(echo $line | grep '#STEPPSELDIFF' | sed -e 's/#//g') in
        STEPPSELDIFF)
            case $dsize in
                1GB)
                echo ""
                ;;
                2GB)
                echo "sendkey spc"
                ;;
                4GB)
                echo "sendkey spc"
                ;;
            esac
            ;;
       esac
      )
 	echo $sendkeycct | nc -N 127.0.0.1 $telnetport >/dev/null 2>&1
	sleep 2
	filterwaittime=$(echo $line | grep wait | sed -e 's/wait//g' -)
	echo $filterwaittime
	sleep $filterwaittime >/dev/null 2>&1
done < "$filename"
