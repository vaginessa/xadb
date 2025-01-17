#!/bin/bash
#__   __             _____    ____  
#\ \ / /     /\     |  __ \  |  _ \ 
# \ V /     /  \    | |  | | | |_) |
#  > <     / /\ \   | |  | | |  _ < 
# / . \   / ____ \  | |__| | | |_) |
#/_/ \_\ /_/    \_\ |_____/  |____/ 

#android_dir="$xia0/android/"
XADB_ROOT_DIR=`cat ~/.xadb/rootdir`

ANDROID_SDK_PATH=`cat ~/.xadb/sdk-path`

XADB_DEVICE_SERIAL="$HOME/.xadb/device-serial"

ADB=""

if [[ -e "$HOME/.xadb/adb-path" ]];then
	ADB=`cat ~/.xadb/adb-path`
fi

if [[ -z $ADB ]];then
	ADB=$ANDROID_SDK_PATH/platform-tools/adb
fi

# If update.lock exsist : there is new version for updating. use adb update
XADB_UPDATE_LOCK_FILE="$HOME/.xadb/update.lock"

# last-check-update.time : the last timestamp of checking update
XADB_LAST_CHECKUPDATE_TIMEFILE="$HOME/.xadb/last-check-update.time"

function XADBILOG(){

	echo -e "\033[32m[I]:$1 \033[0m"
}

function XADBELOG(){
	
	echo -e "\033[31m[E]:$1 \033[0m"
	
}

function XADBDLOG(){
	echo "[DEBUG]:$1" > /dev/null
}

function XADBTimeNow(){
	now=$(date "+%Y%m%d-%H:%M:%S")
	echo $now
}

function XADBDeviceState(){
	device=`XADB get-state 2>/dev/null`
	echo $device

}

function XADBCheckUpdate(){
	if [[ ! -f $XADB_LAST_CHECKUPDATE_TIMEFILE ]]; then 

		XADBDLOG "XADB_LAST_CHECKUPDATE_TIMEFILE Not Exsist."
		sh -c "cd $XADB_ROOT_DIR;git remote show origin | grep -q \"local out of date\" && (touch $XADB_UPDATE_LOCK_FILE) || rm $XADB_UPDATE_LOCK_FILE 2>/dev/null"
		echo `date '+%s'` > $XADB_LAST_CHECKUPDATE_TIMEFILE

	else
		XADBDLOG "XADB_LAST_CHECKUPDATE_TIMEFILE Exsist."
		lastTimestamp=`cat $XADB_LAST_CHECKUPDATE_TIMEFILE`
		nowTimestamp=`date '+%s'`
		oneDayTimestamp=43200
		needTimestamp=`expr $nowTimestamp - $lastTimestamp`
		# echo $lastTimestamp $nowTimestamp $needTimestamp
		# Last check update is one day ago?
		if [[ $needTimestamp >  $oneDayTimestamp ]]; then 
			sh -c "cd $XADB_ROOT_DIR;git remote show origin | grep -q \"local out of date\" && (touch $XADB_UPDATE_LOCK_FILE) || rm $XADB_UPDATE_LOCK_FILE 2>/dev/null"
			echo `date '+%s'` > $XADB_LAST_CHECKUPDATE_TIMEFILE
		fi
	fi


	if [[ -f $XADB_UPDATE_LOCK_FILE ]]; then

		XADBILOG "XADB has updated! Run \"adb update\" get new version :)"
	fi

	XADBDLOG "Update Check Done!"
}


function XADBISEMULATOR(){
	test -f $XADB_DEVICE_SERIAL || return 0 && (cat $XADB_DEVICE_SERIAL | grep -q "emulator" && return 1 || return 0 )
}

function XADB(){
	test -f $XADB_DEVICE_SERIAL && $ADB -s $(cat $XADB_DEVICE_SERIAL) $@ || $ADB -d $@
}


function XADBCheckxia0(){
	if [[  $(XADBDeviceState) != "device" ]]; then
		return
	fi
	if [[ "$1" = "clean" ]]; then
		XADBILOG "This cmd will delete all file in /data/local/tmp, continue? [yes/no]"
		read -p "This cmd will delete all file in /data/local/tmp, continue [yes/no]? : " yes_or_no
		
		if [[ "$yes_or_no" = "yes" ]]; then
			XADB shell su -c "rm -fr /data/local/tmp/*"
			if [[ "$?" != "0" ]]; then
				XADB shell su 0/0 "rm -fr /data/local/tmp/*"
			fi
		fi
		return
		# XADB shell "[ -d /sdcard/xia0 ] && rm -fr /sdcard/xia0"
		# return
	fi

	if [[ "$1" = "force" ]]; then
		XADBCheckxia0 clean
		XADB push "$XADB_ROOT_DIR/frida" /sdcard/xia0
		XADB push "$XADB_ROOT_DIR/tools" /sdcard/xia0
		XADB push "$XADB_ROOT_DIR/debug-server" /sdcard/xia0
		XADB push "$XADB_ROOT_DIR/script" /sdcard/xia0
		return
	fi

	script='[ -d /sdcard/xia0 ] || (mkdir -p /sdcard/xia0)'
	XADB shell "$script"

	ret=`XADB shell "[ -d /sdcard/xia0/frida ] && echo 1 || echo 0" | tr -d '\r'`
	if [[ "$ret" = "0" ]]; then
		XADB push "$XADB_ROOT_DIR/frida" /sdcard/xia0
	fi

	ret=`XADB shell "[ -d /sdcard/xia0/tools ] && echo 1 || echo 0" | tr -d '\r' `
	if [[ "$ret" = "0" ]]; then
		XADB push "$XADB_ROOT_DIR/tools" /sdcard/xia0
	fi

	ret=`XADB shell "[ -d /sdcard/xia0/debug-server ] && echo 1 || echo 0" | tr -d '\r'`
	if [[ "$ret" = "0" ]]; then
		XADB push "$XADB_ROOT_DIR/debug-server" /sdcard/xia0
	fi
 
	ret=`XADB shell "[ -d /sdcard/xia0/script ] && echo 1 || echo 0" | tr -d '\r'`
	if [[ "$ret" = "0" ]]; then
		XADB push "$XADB_ROOT_DIR/script" /sdcard/xia0
	fi

}



function xadb(){

	# adb app [command] :show some app info 
	if [ "$1" = "app" ];then
		
		# check current screen is in StatusBar?
		curScreen=`xadb shell dumpsys window | grep -i  mCurrentFocus`
		if [[ "$curScreen" == *"StatusBar"* ]]; then
			XADBILOG "Current screen is in the StatusBar. Please unlock or focus on app"
			return
		fi

		case $2 in
			package )
				# APPID=`xadb shell dumpsys window | grep -i  mCurrentFocus | awk -F'/' '{print $1}' | awk '{print $NF}'`
				app_count=`xadb shell dumpsys window | grep -i  mCurrentFocus | grep '\b\w*\.[^\}]*' -o -c`
				if [[ $app_count -eq 2 ]]; then
					APPID=`xadb shell dumpsys window | grep -i  mCurrentFocus | grep -v "Waiting For Debugger" | grep '\b\w*\.[^\}]*' -o | awk -F'/' '{print $1}'`
				else
					APPID=`xadb shell dumpsys window | grep -i  mCurrentFocus | grep '\b\w*\.[^\}]*' -o | awk -F'/' '{print $1}'`
				fi

				if [[ "$APPID" = "Waiting" ]]; then
					APPID=`xadb shell dumpsys window | grep -i  mCurrentFocus | awk '{print $6}' | awk -F'}' '{print $1}'`
				fi
					
				echo $APPID
				;;

			activity )
				if [[ $3 = "main" ]]; then
					adb app info | tr -d '\r' | grep -A1 "android.intent.action.MAIN" | tr -d '\n' |awk '{print $3}'
				else
					app_count=`xadb shell dumpsys window | grep -i  mCurrentFocus | grep '\b\w*\.[^\}]*' -o -c`
					if [[ $app_count -eq 2 ]]; then
						adb shell dumpsys window | tr -d '\r' | grep -i  mCurrentFocus | grep -v "Waiting For Debugger" | awk '{print $3}' | awk -F'}' '{print $1}'
					else
						if  adb shell dumpsys window | tr -d '\r' | grep -i  mCurrentFocus | grep -q "Waiting For Debugger" ; then
							echo "[no activity found for app in debugging status]"
						else
							adb shell dumpsys window | tr -d '\r' | grep -i  mCurrentFocus | awk '{print $3}' | awk -F'}' '{print $1}'
						fi
					fi
				fi
				;;

			pid )
				APPID=`xadb app package | tr -d '\r'`
				APPPID=`xadb xdo ps | tr -d '\r' | grep  "$APPID$" | awk '{print $2}'`
				if [[ -z $APPPID || "$APPPID" = "" ]]; then
					APPPID=`xadb shell ps | tr -d '\r' | grep  "$APPID$" | awk '{print $2}'`
				fi
				echo $APPPID
				;;

			pidAll )
				APPID=`xadb app package | tr -d '\r'`
				APPPID=`xadb xdo ps | tr -d '\r' | grep  "$APPID" | awk '{print $2}'`
				if [[ -z $APPPID || "$APPPID" = "" ]]; then
					APPPID=`xadb shell ps | tr -d '\r' | grep  "$APPID$" | awk '{print $2}'`
				fi
				echo $APPPID
				;;
				
			debug )
				# 判断是否开启了调试
				isdebug=`xadb shell getprop ro.debuggable | tr -d '\r'`
				if [[ "$isdebug" = "0" ]]; then
					XADBILOG "Not open debug, opening..."
					ret=`adb shell "[ -f /data/local/tmp/mprop ] && echo "1" || echo "0"" | tr -d '\r'`

					if [[ "$ret" = "0" ]]; then
						xadb sudo "cp /sdcard/xia0/tools/mprop /data/local/tmp/"
					fi
					xadb sudo "chmod 777 /data/local/tmp/mprop"
					xadb sudo "/data/local/tmp/mprop"
					xadb sudo "setprop ro.debuggable 1"
					xadb sudo "/data/local/tmp/mprop -r"
					xadb sudo "getprop ro.debuggable"
					xadb sudo "stop"
					sleep 2
					xadb sudo "start"
					sleep 5

					XADBILOG "Opened debug, Retry for happy debugging!"
					return
				fi

				enforce=`xadb sudo getenforce | tr -d '\r'`

				if [[ "$enforce" =~ "Enforcing" || "$enforce" == "1" ]]; then
					XADBILOG "Set enforce to Permissive, Please wait..."
					xadb sudo "setenforce 0"
				fi

				activity=`xadb app activity | tr -d '\r'`
				xadb sudo "am start -D -n $activity"
				sleep 2
				pid=`xadb app pid`
				xadb forward tcp:8700 jdwp:$pid

				;;

			# get apk file from device
			apk )
				if [ -z "$3" ]; then
					APP_ID=`xadb app package | tr -d '\r'`

				else
					APP_ID=$3
				fi

				local_apk_file=`xadb app apk_in $APP_ID`

				XADBILOG "pull app apk from device done:$local_apk_file"
				;;

			apk_in )
				if [ -z "$3" ]; then
					APP_ID=`xadb app package | tr -d '\r'`

				else
					APP_ID=$3
				fi

				if [[ "$APP_ID" =~ "StatusBar" ]];then
					XADBELOG "now in statusBar, please unlock or focus on app"
					return
				fi

				base_apk=`xadb shell pm path $APP_ID | tr -d '\r' | grep "base.apk" |awk -F':' '{printf $2}'`
				# XADBILOG "found base.apk:$base_apk and start pull it from device"

				now=`XADBTimeNow`
				xadb pull $base_apk $APP_ID-$now.apk 1>/dev/null
				current_dir=`pwd`
				lcoal_apk="$current_dir/$APP_ID-$now.apk"
				echo $lcoal_apk
				# XADBILOG "pull apk form device done in:$lcoal_apk"
				;;
			sign )
				if [ -z "$3" ]; then
					APP_ID=`xadb app package | tr -d '\r'`

				else
					APP_ID=$3
				fi

				apk_file=`xadb app apk_in $APP_ID`

				if [ -z "$apk_file" ]; then
					XADBELOG "$APP_ID apk file can not copy from device"
					return
				fi
				SIGN_RSA=`unzip -l $apk_file | grep "META-INF.*\.RSA" | awk  '{printf $4}'`
				# echo $SIGN_RSA
				unzip -p $apk_file $SIGN_RSA | keytool -printcert
				rm $apk_file
				;;

			info )
				if [ -z "$3" ]; then
					APP_ID=`xadb app package | tr -d '\r'`

				else
					APP_ID=$3
				fi
				xadb shell dumpsys package $APP_ID
				;;

			version )
				if [ -z "$3" ]; then
					APP_ID=`xadb app package | tr -d '\r'`

				else
					APP_ID=$3
				fi
					version_prefix="versionName="
				    version=`xadb shell dumpsys package $APP_ID | grep versionName= | tr -d " "`
				    version_=${version:${#version_prefix}:${#version}}
				    echo $version_
				;;
			# get cureet screenshot 
			screen )
				xadb shell screencap -p > screen.png
				;;

			# dump current app so sharelib
			so|dumpso )
				if [ -z "$3" ]; then
					APPPID=`xadb app pid | tr -d '\r'`

				else
					APPPID=$3
				fi

				APPID=`adb app package | tr -d '\r'`
				XADBILOG "============================[PID=$APPPID PACKAGE:$APPID]=================================="
				xadb xdo "cat /proc/$APPPID/maps" | grep '\.so'
				;;
			maps )
				if [ -z "$3" ]; then
					APPPID=`xadb app pid | tr -d '\r'`

				else
					APPPID=$3
				fi

				APPID=`adb app package | tr -d '\r'`
				XADBILOG "============================[PID=$APPPID PACKAGE:$APPID]=================================="
				xadb xdo "cat /proc/$APPPID/maps"
				;;
			dump )
				XADBILOG "Dex Dump Power by hluwa, Please wait about 5 second...."
				# auto launch frida base device abi
				isArm64=`adb device abilist | grep -q "arm64-v8a" && echo "1" || echo "0"`

				if [[ "$isArm64" = "1" ]]; then
					XADBILOG "Deice is arm64-v8a, launch frida64"
					(adb frida64 > /dev/null 2>&1 &)
				else
					XADBILOG "Deice is not arm64-v8a, launch frida"
					(adb frida > /dev/null 2>&1 &)
				fi

				# sleep for frida launch
				sleep 5


				if [[ "$3" = "spawn" ]]; then

					APPID=`xadb app package`
					python "$XADB_ROOT_DIR/script/dumpdex.py" $APPID

				else

					APPPID=`xadb app pid`
					python "$XADB_ROOT_DIR/script/dumpdex.py" $APPPID
				fi

				XADBILOG "Dex Dump Done! Happy Reversing~"
				;;
			*)
				APP_ID=`xadb app package`
				APP_VERSION=$(xadb app version)
				APP_PIDS=`xadb app pidAll`
				APPA_CTIVITY=`xadb app activity`
				APP_MAINACTIVITY=`xadb app activity main`
				APP_DIR=`xadb app info | grep codePath`
				APP_DIR=${APP_DIR##*codePath=}
				APP_DATADIR=`xadb app info | grep dataDir`
				APP_DATADIR=${APP_DATADIR##*dataDir=}
				echo -e "app=$APP_ID\nversion=$APP_VERSION\npid=$APP_PIDS\nactivity=$APPA_CTIVITY\nmainActivity=$APP_MAINACTIVITY\nappdir=$APP_DIR\ndatadir=$APP_DATADIR"
				;;
		esac

		return
	fi
	
	# show device basic info
	if [ "$1" = "device" ];then
		case $2 in

			imei )
				imei=`xadb shell service call iphonesubinfo 1 | awk -F "'" '{print $2}' | sed '1 d' | tr -d '.' | awk '{print}' ORS=`
				echo "$imei"
				;;

			abilist )
				abilist=`xadb shell getprop ro.product.cpu.abilist | tr -d '\r' `
				echo "$abilist"
				;;
			
			*)
				model=`xadb shell getprop ro.product.model  | tr -d '\r' ` 
				serialno=`xadb shell getprop ro.serialno  | tr -d '\r'`
				brand=`xadb shell getprop ro.product.brand  | tr -d '\r'`
				manufacturer=`xadb shell getprop ro.product.manufacturer | tr -d '\r'`
				abilist=`xadb shell getprop ro.product.cpu.abilist | tr -d '\r' `
				imei=`xadb device imei | tr -d '\r' `
				android_id=`xadb shell settings get secure android_id | tr -d '\r' `
				sdk_api=`xadb shell getprop ro.build.version.sdk | tr -d '\r' `
				os_ver=`xadb shell getprop ro.build.version.release | tr -d '\r' `
				wifi_ip=`xadb shell ip addr show wlan0 | grep "inet\s" | awk -F'/' '{printf $1}' | awk '{printf $2}' | tr -d '\r'`
				wifi_mac=$(xadb shell ip address show wlan0 | grep "link/ether" | awk '{printf $2}' | tr -d '\r')
				# wifi_mac=`xadb shell cat /sys/class/net/wlan0/address | tr -d '\r'`
				debug=`xadb shell getprop ro.debuggable | tr -d '\r'`

				printf "%-20s %-20s \n" "model" "$model"
				printf "%-20s %-20s \n" "brand" "$brand"
				printf "%-20s %-20s \n" "manufacturer" "$manufacturer"
				printf "%-20s %-20s \n" "abilist" "$abilist"
				printf "%-20s %-20s \n" "sdk" "$sdk_api"
				printf "%-20s %-20s \n" "wifi ipv4" "$wifi_ip"
				printf "%-20s %-20s \n" "wifi mac" "$wifi_mac"
				printf "%-20s %-20s \n" "os version" "$os_ver"
				printf "%-20s %-20s \n" "serialno" "$serialno"
				printf "%-20s %-20s \n" "imei" "$imei"
				printf "%-20s %-20s \n" "android_id" "$android_id"
				printf "%-20s %-20s \n" "can debug?" "$debug"

			;;
		esac
		return
	fi

	# misc
	# if [ "$1" = "dumpdex" ]; then
	# 	xadb sudo "cp /sdcard/xia0/libnativeDump.so /system/lib/"
	# 	xadb sudo "chmod 777 /system/lib/libnativeDump.so"
	# 	return
	# fi

	# setup ida debug env
	if [[ "$1" =~ "debug" ]]; then
		# steps of debug apk
		echo "**********************************************************************************"
		echo "====>1.adb shell am start -D -n package_id/.MainActivity"
		echo "====>2.adb forward tcp:8700 jdwp:pid"
		echo "====>3.jdb -connect \"com.sun.jdi.SocketAttach:hostname=localhost,port=8700\""
		echo "====>[gdb]$ target remote :23946"
		echo "====>[gdb]$ handle SIG32 nostop noprint"
		echo "====>[lldb]$ platform select remote-android"
		echo "====>[lldb]$ pro hand -p true -s false SIGBUS"
		echo "====>[lldb]$ platform connect unix-abstract-connect:///data/local/tmp/debug.sock"
		echo "====>[lldb]$ platform connect connect://remote:5678"
		echo "====>[lldb]$ process attach --pid=14396 or platform process attach -p 8098"
		echo "**********************************************************************************"


		XADBISEMULATOR 
		if [[ $? == 0 ]]; then		
			# 判断是否开启了调试
			isdebug=`xadb shell getprop ro.debuggable`;
			if [[ "$isdebug" = "0" ]]; then
				XADBILOG "Not open debug, opening..."
				ret=`adb shell "[ -f /data/local/tmp/mprop ] && echo "1" || echo "0""`

				if [[ "$ret" = "0" ]]; then
					xadb sudo "cp /sdcard/xia0/tools/mprop /data/local/tmp/"
				fi
				xadb sudo "chmod 777 /data/local/tmp/mprop"
				xadb sudo "/data/local/tmp/mprop"
				xadb sudo "setprop ro.debuggable 1"
				xadb sudo "/data/local/tmp/mprop -r"
				xadb sudo "getprop ro.debuggable"
				xadb sudo "stop"
				sleep 2
				xadb sudo "start"
				sleep 5

				XADBILOG "Opened debug, Retry for happy debugging!"
				return
			fi
		fi

		# kill all server if process exsist
		xadb kill android_server64
		xadb kill android_server
		xadb kill android_x86_server
		xadb kill gdbserver
		xadb kill gdbserver64
		xadb kill lldb-server
		xadb kill lldb-server64


		case $2 in
			ida_x86 )

				# if not set debug port. use 23946 as default port
				if [[ -z "$3" ]]; then
					XADBILOG "Not set debug port, Use 23946 as default port"
					debugPort="23946"
				else
					XADBILOG "Set the debug port:$3"
					debugPort=$3
				fi

				# 32bit app ida debug
				server=`adb shell "[ -f /data/local/tmp/android_x86_server ] && echo "1" || echo "0"" | tr -d '\r'`

				if [[ "$server" = "0" ]]; then
					xadb sudo "cp /sdcard/xia0/debug-server/android_x86_server /data/local/tmp/"
				fi
				
				xadb sudo "chmod 777 /data/local/tmp/android_x86_server"
				
				xadb forward tcp:$debugPort tcp:$debugPort

				xadb sudo "/data/local/tmp/android_x86_server -p$debugPort"
				;;

			ida )

				# if not set debug port. use 23946 as default port
				if [[ -z "$3" ]]; then
					XADBILOG "Not set debug port, Use 23946 as default port"
					debugPort="23946"
				else
					XADBILOG "Set the debug port:$3"
					debugPort=$3
				fi

				# 32bit app ida debug
				server=`adb shell "[ -f /data/local/tmp/android_server ] && echo "1" || echo "0"" | tr -d '\r'`

				if [[ "$server" = "0" ]]; then
					xadb sudo "cp /sdcard/xia0/debug-server/android_server /data/local/tmp/"
				fi
				
				xadb sudo "chmod 777 /data/local/tmp/android_server"
				
				xadb forward tcp:$debugPort tcp:$debugPort

				xadb sudo "/data/local/tmp/android_server -p$debugPort"
				;;

			ida64 )
				# if not set debug port. use 23946 as default port
				if [[ -z "$3" ]]; then
					XADBILOG "Not set debug port, Use 23946 as default port"
					debugPort="23946"
				else
					XADBILOG "Set the debug port:$3"
					debugPort=$3
				fi

				# 64bit app ida debug
				server64=`adb shell "[ -f /data/local/tmp/android_server64 ] && echo "1" || echo "0"" | tr -d '\r'`

				if [[ "$server64" = "0" ]]; then
					xadb sudo "cp /sdcard/xia0/debug-server/android_server64 /data/local/tmp/"
				fi
				
				xadb sudo "chmod 777 /data/local/tmp/android_server64"

				xadb forward tcp:$debugPort tcp:$debugPort

				xadb sudo "/data/local/tmp/android_server64 -p$debugPort"
				return
				;;
			gdb )
				# 32bit app gdb debug
				pid=$3
				if [ -z "$pid" ]; then
					pid=`xadb app pid`
				fi

				server=`adb shell "[ -f /data/local/tmp/gdbserver ] && echo "1" || echo "0"" | tr -d '\r'`

				if [[ "$server" = "0" ]]; then
					xadb sudo "cp /sdcard/xia0/debug-server/gdbserver /data/local/tmp/"
				fi
				
				xadb sudo "chmod 777 /data/local/tmp/gdbserver"
				
				xadb forward tcp:23946 tcp:23946

				xadb sudo "/data/local/tmp/gdbserver :23946 --attach $pid"
				return
				;;
			gdb64 )
				# 64bit app gdb debug
				pid=$3
				if [ -z "$pid" ]; then
					pid=`xadb app pid`
				fi

				server64=`adb shell "[ -f /data/local/tmp/gdbserver64 ] && echo "1" || echo "0"" | tr -d '\r'`

				if [[ "$server64" = "0" ]]; then
					xadb sudo "cp /sdcard/xia0/debug-server/gdbserver64 /data/local/tmp/"
				fi
				
				xadb sudo "chmod 777 /data/local/tmp/gdbserver64"

				xadb forward tcp:23946 tcp:23946

				xadb sudo "/data/local/tmp/gdbserver64 :23946 --attach $pid"
				return
				;;

			lldb )
				server=`adb shell "[ -f /data/local/tmp/lldb-server ] && echo "1" || echo "0"" | tr -d '\r'`

				if [[ "$server" = "0" ]]; then
					xadb sudo "cp /sdcard/xia0/debug-server/lldb-server /data/local/tmp/"
				fi
				
				xadb sudo "chmod 777 /data/local/tmp/lldb-server"

				# xadb shell /data/local/tmp/lldb-server platform --server --listen unix-abstract:///data/local/tmp/debug.sock

				if [[ "$3" = "port" ]]; then
					xadb forward tcp:5678 tcp:5678
					xadb sudo "/data/local/tmp/lldb-server platform --listen \"*:5678\" --server"
				else
					xadb sudo "/data/local/tmp/lldb-server platform --server --listen unix-abstract:///data/local/tmp/debug.sock"
				fi

				return
				;;

			lldb64 )
				server64=`adb shell "[ -f /data/local/tmp/lldb-server64 ] && echo "1" || echo "0"" | tr -d '\r'`

				if [[ "$server64" = "0" ]]; then
					xadb sudo "cp /sdcard/xia0/debug-server/lldb-server64 /data/local/tmp/"
				fi
				
				xadb sudo "chmod 777 /data/local/tmp/lldb-server64"

				if [[ "$3" = "port" ]]; then
					xadb forward tcp:5678 tcp:5678
					xadb sudo "/data/local/tmp/lldb-server64 platform --listen \"*:5678\" --server"
				else
					xadb sudo "/data/local/tmp/lldb-server64 platform --server --listen unix-abstract:///data/local/tmp/debug.sock"
				fi
				;;
			* )
				XADBELOG "\"$2\" debug server not found."
				return 
				;;
		esac
		return
	fi

	if [[ "$1" =~ "frida" ]]; then
		# https://github.com/frida/frida/releases
		script="find '/sdcard/xia0/frida' -type f -name \"frida*arm\""
		server=`xadb shell "$script" | awk -F'/' '{print $NF}' | tr -d '\r'`

		script="find '/sdcard/xia0/frida' -type f -name \"frida*arm64\""
		server64=`xadb shell "$script" | awk -F'/' '{print $NF}' | tr -d '\r' `

		XADBILOG "Current frida-server version, for more version visit:[https://github.com/frida/frida/releases]"
		printf "[%5s]: %-50s\n" "arm" $server
		printf "[%5s]: %-50s\n" "arm64" $server64

		xadb kill $server
		xadb kill $server64

		xadb forward tcp:27042 tcp:27042

		if [[ "$1" = "frida64" ]]; then
			ret=`xadb shell "[ -f '/data/local/tmp/$server64' ] && echo "1" || echo "0"" | tr -d '\r'`

			if [[ "$ret" = "0" ]]; then
				xadb sudo "cp '/sdcard/xia0/frida/$server64' '/data/local/tmp/'"
			fi

			xadb sudo "chmod 777 '/data/local/tmp/$server64'"
			xadb sudo "'/data/local/tmp/$server64'"
			return
		fi

		ret=`xadb shell "[ -f '/data/local/tmp/$server' ] && echo "1" || echo "0"" | tr -d '\r' `

		if [[ "$ret" = "0" ]]; then
			xadb sudo "cp '/sdcard/xia0/frida/$server' '/data/local/tmp/'"
		fi

		xadb sudo "chmod 777 '/data/local/tmp/$server'"
		xadb sudo "'/data/local/tmp/$server'"

		return
	fi

	if [[ "$1" = "pcat" ]]; then
		filepath=$2
		filename=${filepath##*/}
		xadb xdo "cat $2" > $filename
		return
	fi

	if [[ "$1" = "scp" ]]; then

		file1=$2
		file2=$3

		# isRemoteFile=`adb shell "[ -f $file1 ] && echo "1" || echo "0"" | tr -d '\r'`
		if [[ -f "$file1" || -d "$file1" ]]; then
			echo "$file1 is local file, so copy it to device"
			xadb push "$file1" "$file2"
		else
			filename=${file1##*/}
			echo "$file1 is remote file, so copy it to local"
			xadb sudo "cp -r $file1 /sdcard"
			xadb pull "/sdcard/$filename" "$file2"
			xadb sudo "rm -r /sdcard/$filename"
		fi
		return
	fi

	# sudo 
	if [ "$1" = "sudo" ]; then
		cmd=${@:2:$#}
		XADBILOG "Run \"$cmd\""

		XADBISEMULATOR 
		if [[ $? == 1 ]]; then	
			xadb shell "$cmd"
			return
		fi

		xadb shell "su -c \"$cmd\"" #2>/dev/null;

		if [[ "$?" != "0" ]]; then
			xadb shell su 0/0 "\"$cmd\"" #2>/dev/null;
		fi
		return
	fi

	# xdo == sudo. just for clean output cmd. NO "Run $cmd" Log
	if [[ "$1" = "xdo" ]]; then
		cmd=${@:2:$#}

		XADBISEMULATOR 
		if [[ $? == 1 ]]; then	
			xadb shell "$cmd"
			return
		fi

		xadb shell su -c "\"$cmd\"" 2>/dev/null;

		if [[ "$?" != "0" ]]; then
			xadb shell su 0/0 "$cmd" 2>/dev/null;
		fi

		return
	fi

	# kill process by name
	if [[ "$1" = "kill" ]]; then
		process_name=$2
		live=`xadb sudo "ps" | tr -d '\r' | grep $process_name | awk '{print $9}'`
		# echo $process_name
		if [[ -n "$live" && "$live" = "$process_name" ]]; then
			xadb sudo "killall -9 $process_name"
		fi
		return
	fi


	if [[ "$1" = "ps" ]]; then
		process_name=$2
		if [[ -n "$process_name" ]]; then
			xadb sudo "ps -ef" | grep -i $process_name
		fi
		return
	fi

	if [[ "$1" = "maps" ]]; then
		apppid="$2"
		if [[ -n "$apppid" ]]; then
			xadb sudo "cat /proc/$apppid/maps"
		fi
		return
	fi

	# show log of app
	if [ "$1" = "xlog" ];then
		if [ -z "$2" ]; then
			APPPID=`xadb app pid | tr -d '\r'`
			xadb xlog $APPPID
			return
		fi

		APPPID=$2
		APPID=`xadb app package | tr -d '\r'`
		XADBILOG "============================[PID=$APPPID PACKAGE:$APPID]=================================="
		
		isLogcatSupportPID=`adb logcat -x 2>&1 | grep -q "Only prints logs from the given pid" && echo "1" || echo "0"`

		if [[ $isLogcatSupportPID = "1" ]]; then
			XADBILOG "logcat support --pid option, so use origin to filter pid"
		 	xadb logcat --pid=$APPPID

		else
			XADBILOG "logcat not support --pid option, so use xia0PIDFilter to filter pid"
			xadb logcat | awk '{if($3 == pid){print $0}}' pid="$APPPID"
		fi

		# adb logcat --pid=1234 | grep -q "Unrecognized Option" && echo "0" || echo "1"  & sleep 5; kill $!)
		return
	fi

	if [ "$1" = "pstree" ];then
		ret=`adb shell "[ -f /data/local/tmp/pstree.sh ] && echo "1" || echo "0"" | tr -d '\r'`

		if [[ "$ret" = "0" ]]; then
			xadb sudo "cp /sdcard/xia0/script/pstree.sh /data/local/tmp/"
		fi

		xadb sudo "chmod 777 /sdcard/xia0/script/pstree.sh"
		XADBILOG "Runing sh /sdcard/xia0/script/pstree.sh, Please wait..."
		xadb xdo "sh /sdcard/xia0/script/pstree.sh" | more
		return
	fi

	if [ "$1" = "sign" ];then
		if [[ -z $2 ]]; then
			XADBILOG "[usage] adb sign local-apk-file"
			return
		fi

		apk_file=$2

		SIGN_RSA=`unzip -l $apk_file | grep "META-INF.*\.RSA" | awk  '{printf $4}'`
		# echo $SIGN_RSA
		unzip -p $apk_file $SIGN_RSA | keytool -printcert
		return
	fi


	if [ "$1" = "restart" ];then
		XADBILOG "kill all process except init"
		adb sudo "kill -- -1"
		return
	fi


	if [ "$1" = "agent" ];then
		if [[ "$2" = "reinstall" ]]; then
			XADBCheckxia0 force
		fi

		if [[ "$2" = "clean" ]]; then
			XADBCheckxia0 clean
		fi
		return
	fi

	if [ "$1" = "sslkill" ];then
		args=${@:2:$#}
		frida_args="$args"
		if [[ "$args" =~ "-h" ]]; then
			XADBELOG "[usage] -f package_id [-D device_id / -U] -p pid"
			return
		fi 

		if [[ ! "$args" =~ "-D" && ! "$args" =~ "-U" ]]; then
			XADBILOG "not special device, use -U"
			frida_args="$frida_args -U"
		fi

		if [[ ! "$args" =~ "-f" ]]; then
			apppid=`adb app package`
			XADBILOG "not special -f package, use $apppid"
			frida_args="$frida_args -f $apppid"
		fi


		frida -l "$XADB_ROOT_DIR/script/pinning.js" $frida_args --no-pause 
		return
	fi


	if [ "$1" = "update" ];then
		XADBDLOG "Run adb update"
		sh -c "cd $XADB_ROOT_DIR;git pull"
		sh -c "cd $XADB_ROOT_DIR;git remote show origin | grep -q \"local out of date\" && (touch $XADB_UPDATE_LOCK_FILE) || rm $XADB_UPDATE_LOCK_FILE 2>/dev/null"
		return
	fi

 	# usage 
	if [[  "$1" = "-h" ]]; then
		printf " %-8s \n\t %-35s %-20s \n" "device" "[imei]" "show connected android device basic info"
		printf " %-8s \n\t %-35s %-20s \n" "serial" "[-s/-r]" "set/remove adb connect device serial such as emulator connecting"
		printf " %-8s \n\t %-35s %-20s \n" "app" "[sign/so/pid/apk/debug/dump]" "show current app, debug and dump dex "
		printf " %-8s \n\t %-35s %-20s \n" "xlog" "[package]" "logcat just current app or special pid"
		printf " %-8s \n\t %-35s %-20s \n" "debug" "[ida/ida64,lldb/lldb64, gdb/gdb64]" "open debug and setup ida/lldb/gdb debug enviroment"
		printf " %-8s \n\t %-35s 		 \n" "frida/64" "start frida server on device"
		printf " %-8s \n\t %-35s %-20s \n" "scp" "local/remote remote/local" "copy device file to local or copy local file to device"
		printf " %-8s \n\t %-35s 		 \n" "pstree" "show the process tree of device"
		printf " %-8s \n\t %-35s %-20s \n" "sign" "[local-apk-file]" "show sign of local apk file"
		printf " %-8s \n\t %-35s %-20s \n" "agent" "[clean/reinstall]" "clean caches and reinstall agent"
		printf " %-8s \n\t %-35s		 \n" "restart" "soft reboot:kill all process except init"
		printf " %-8s \n\t %-35s		 \n" "-h" "show this help usage"
		printf " %-8s \n\t %-35s		 \n" "update" "update xadb for new version!"
		return
	fi

	XADB $@
}

function XADBTimeout() {

    time=$1
	# test -f $XADB_DEVICE_SERIAL && $ADB -s $(cat $XADB_DEVICE_SERIAL) $@ || $ADB -d $@
	if [[ -f $XADB_DEVICE_SERIAL ]]; then
		tmp_serial=$(cat $XADB_DEVICE_SERIAL)
		payload="$ADB -s $tmp_serial shell uname"
	else
		payload="$ADB -d shell uname"
	fi
	# echo $payload
    # start the command in a subshell to avoid problem with pipes
    # (spawn accepts one command)
    command="$SHELL -c \"$payload > /dev/null\""

    expect -c "set echo \"-noecho\"; set timeout $time; spawn -noecho $command; expect timeout { exit 1 } eof { exit 0 }"    

    if [ $? = 1 ] ; then
        XADBELOG "timeout after ${time} seconds, will kill-server"
		XADB kill-server
    fi
}

function adb(){

	if [[ "$1" = "kill-server" ]]; then
		XADB kill-server
		return;
	fi

	if [[ "$1" = "serial" ]]; then
		if [[ "$2" = "-s" || "$2" = "set" ]]; then

			echo "$3" > $XADB_DEVICE_SERIAL

		elif [[ "$2" = "-r" || "$2" = "remove" ]]; then
			test -f $XADB_DEVICE_SERIAL && rm $XADB_DEVICE_SERIAL
		else
			test -f $XADB_DEVICE_SERIAL && cat $XADB_DEVICE_SERIAL || XADBILOG "not set device serial"
		fi

		return
	fi

	if [[  "$1" != "update"  ]] && [[  "$1" != "-h"  ]]; then
		if [[  $(XADBDeviceState) != "device" ]]; then
			# XADBELOG "no device found, please check connect state"
			XADBILOG "The device not found, now use original adb"
			XADB $@
			return
		fi
	fi
	XADBTimeout 5
	XADBCheckxia0
	XADBCheckUpdate
	xadb $@
}