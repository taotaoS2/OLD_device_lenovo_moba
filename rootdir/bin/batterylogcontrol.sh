#!/vendor/bin/sh

# Add by wangwq14, start to record battery log.

umask 022

VER=15

if [ -d /data/vendor/newlog/aplog ]; then
	APLOG_DIR=/data/vendor/newlog/aplog
else
	APLOG_DIR=/data/local/newlog/aplog
fi

BATT_LOGFILE_GROUP_MAX_SIZE=20971520

product=""
platform=""
get_product() {
    a=`getprop|grep ro.product.name`
    b=`echo ${a##*\[}`
    product=`echo ${b%]*}`
}

get_platform() {
    a=`getprop|grep ro.board.platform`
    b=`echo ${a##*\[}`
    platform=`echo ${b%]*}`
}
get_product
get_platform

if [[ "$product" == "doom" ]]; then
    FILE_NUM=$(getprop persist.log.tag.aplogfiles)
    if [ $FILE_NUM -gt 0 ]; then
        FILE_NUM=20
    else
        FILE_NUM=5
    fi

    /vendor/bin/batterylogger -n ${FILE_NUM} -s ${BATT_LOGFILE_GROUP_MAX_SIZE} -p ${APLOG_DIR}
    exit
fi

BATT_LOGSHELL="/vendor/bin/batterylog.sh"
BATT_LOGFILE=${APLOG_DIR}"/batterylog"
BATT_LOGFILE_QC=${APLOG_DIR}"/batterylog.qc"

# mv files.x-1 to files.x
mv_files()
{
    if [ -z "$1" ]; then
      echo "No file name!"
      return
    fi

    if [ -z "$2" ]; then
      fileNum=$(getprop persist.log.tag.aplogfiles)
      if [ $fileNum -gt 0 ]; then
        LAST_FILE=$fileNum
      else
        LAST_FILE=5
      fi
    else
      LAST_FILE=$2
    fi

    i=$LAST_FILE
    while [ $i -gt 0 ]; do
      prev=$(($i-1))
      if [ -e "$1.$prev" ]; then
        mv $1.$prev $1.$i
      fi
      i=$(($i-1))
    done

    if [ -e $1 ]; then
      mv $1 $1.1
    fi
}

file_count=0
count=1
prop_len=0
dumper_en=1

mv_files $BATT_LOGFILE
if [ $dumper_en -eq 1 ]; then
    mv_files $BATT_LOGFILE_QC
fi

out_data=""
out_name=""
batt1_path=""
batt1_name=""
batt2_path=""
batt2_name=""
cooling_path=""
cooling_name=""
tz_path=""
tz_name=""

if [[ "$platform" == "kona" ]]; then
    pause_time=5
    while [ 1 ]
    do
        utime=($(cat /proc/uptime))
        ktime=${utime[0]}

        if [[ "$out_name" == "" ]] || [ ! -f ${BATT_LOGFILE} ]; then
            # add header
            out_name="time,uptime,version,log_cnt,rec_cnt,platform,product,"

            # add freq
            freq_name="pwr_cur,perf_cur,perfp_cur,pwr_max,perf_max,perfp_max,gpu_cur,gpu_max,mpctl,backlight,"
            freq_path="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq \
                        /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_cur_freq \
                        /sys/devices/system/cpu/cpu7/cpufreq/cpuinfo_cur_freq \
                        /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq \
                        /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_max_freq \
                        /sys/devices/system/cpu/cpu7/cpufreq/cpuinfo_max_freq \
                        /sys/devices/platform/soc/*.qcom,kgsl-3d0/kgsl/kgsl-3d0/gpuclk \
                        /sys/devices/platform/soc/*.qcom,kgsl-3d0/kgsl/kgsl-3d0/max_gpuclk \
			/sys/devices/system/cpu/cpu0/rq-stats/mpctl \
                        /sys/class/backlight/panel0-backlight/brightness "

            # add ps
            cd /sys/class/power_supply
            for i in *
            do
                if [[ "$i" == "dc" ]]; then
                    continue
                fi

                cd $i
                for j in *
                do
                    if [ -d $j ] || [[ "$j" == "uevent" ]] || [[ "$j" == "flash_trigger" ]]; then
                        continue
                    fi
                    # ps file path
                    ps_path+=/sys/class/power_supply/${i}/${j}" "
                    # ps name
                    if [[ "$i" == "bq27z561-master"* ]]; then
                        ps_name+="batt1"-${j},
                    elif [[ "$i" == "bq27z561-slave"* ]]; then
                        ps_name+="batt2"-${j},
                    elif [[ "$i" == "bq2589h-charger"* ]]; then
                        ps_name+="sec"-${j},
                    elif [[ "$i" == "bq2597x-master"* ]]; then
                        ps_name+="cp1"-${j},
                    elif [[ "$i" == "bq2597x-slave"* ]]; then
                        ps_name+="cp2"-${j},
                    elif [[ "$i" == "bq2597x-sec-master"* ]]; then
                        ps_name+="cp3"-${j},
                    elif [[ "$i" == "bq2597x-sec-slave"* ]]; then
                        ps_name+="cp4"-${j},
                    else
                        ps_name+=${i}-${j},
                    fi
                done
                cd -
            done
            cd -

            # add battery1 info
            p=/sys/devices/platform/soc/988000.i2c/i2c-3/3-0055
            cd $p
            for i in *
            do
                if [ -d $i ] || [[ "$i" == "uevent" ]] || \
                        [[ "$i" == "modalias" ]] || \
                        [[ "$i" == "name" ]] || \
                        [[ "$i" == "DeviceInfo" ]] || \
                        [[ "$i" == "RaTable" ]]; then
                    continue
                fi
                # batt1 file path
                batt1_path+=${p}/${i}" "
                # batt1 name
                batt1_name+=batt1-${i},
            done
            cd -

            # add battery2 info
            p=/sys/devices/platform/soc/990000.i2c/i2c-5/5-0055
            cd $p
            for i in *
            do
                if [ -d $i ] || [[ "$i" == "uevent" ]] || \
                        [[ "$i" == "modalias" ]] || \
                        [[ "$i" == "name" ]] || \
                        [[ "$i" == "DeviceInfo" ]] || \
                        [[ "$i" == "RaTable" ]]; then
                    continue
                fi
                # batt2 file path
                batt2_path+=${p}/${i}" "
                # batt2 name
                batt2_name+=batt2-${i},
            done
            cd -

            # add cooling device
            p=/sys/class/thermal
            cd $p
            for i in cooling_device*
            do
                # cooling device path
                cooling_path+=${p}/${i}/cur_state" "
                # cooling device name
                cooling_name+=dev-`cat ${p}/${i}/type`,
            done
            cd -

            # add thermal zone
            p=/sys/class/thermal
            cd $p
            for i in thermal_zone*
            do
                # tz path
                tz_type=`cat ${p}/${i}/type`

                if [[ "$tz_type" == "modem-mmw1-mod-usr" ]] || \
                        [[ "$tz_type" == "modem-mmw2-mod-usr" ]] || \
                        [[ "$tz_type" == "modem-mmw3-mod-usr" ]]; then
                    continue;
                fi

                tz_path+=${p}/${i}/temp" "
                # tz name
                tz_name+=tz-${tz_type},
            done
            cd -

            # write prop name to file
            out_name+=${freq_name}${ps_name}${batt1_name}${batt2_name}${cooling_name}${tz_name}
            echo ${out_name} >${BATT_LOGFILE}
        fi

        # add header
        out_data="`echo $(date "+%Y-%m-%d %H:%M:%S.%3N")`,${ktime},${VER},${file_count},${count},${platform},${product},"
        # add freq
        freq_data=`cat ${freq_path} | tr '\n' ','`
        # add ps
        ps_data=`cat ${ps_path} | tr '\n' ','`
        # add batt1
        batt1_data=`cat ${batt1_path} | tr '\n' ','`
        # add batt2
        batt2_data=`cat ${batt2_path} | tr '\n' ','`
        # add cooling device
        cooling_data=`cat ${cooling_path} | tr '\n' ','`
        # add tz
        tz_data=`cat ${tz_path} | tr '\n' ','`
        # write data to file
        out_data+=${freq_data}${ps_data}${batt1_data}${batt2_data}${cooling_data}${tz_data}
        echo ${out_data} >>${BATT_LOGFILE}

        if [ $(((count - 1) % 5)) -eq 0 ]; then
            dumper_flag=1
        else
            dumper_flag=0
        fi

        BATT_LOGFILE_size=`stat -c "%s" $BATT_LOGFILE`
        BATT_LOGFILE_GROUP_size=$(($BATT_LOGFILE_size))

        let count=$count+1
        sleep $pause_time

        if [ $BATT_LOGFILE_GROUP_size -gt $BATT_LOGFILE_GROUP_MAX_SIZE ]; then
            mv_files $BATT_LOGFILE
            if [ $dumper_en -eq 1 ]; then
                mv_files $BATT_LOGFILE_QC
            fi
            let file_count=$file_count+1
        fi
    done
else
    pause_time=10
    while [ 1 ]
    do
        utime=($(cat /proc/uptime))
        ktime=${utime[0]}

        if [ $(((count - 1) % 5)) -eq 0 ]; then
            dumper_flag=1
        else
            dumper_flag=0
        fi

        #      0              1                                  2        3             4          5            6           7           8      9
        buf=`. $BATT_LOGSHELL "$(date "+%Y-%m-%d %H:%M:%S.%3N")" ${ktime} $BATT_LOGFILE $dumper_en $dumper_flag "$prop_len" $file_count $count $pause_time`

        buf=`echo ${buf##*prop_len=\[}`
        prop_len=`echo ${buf%\]=prop_len*}`

        BATT_LOGFILE_size=`stat -c "%s" $BATT_LOGFILE`
        if [ $dumper_en -eq 1 ]; then
            BATT_LOGFILE_QC_size=`stat -c "%s" $BATT_LOGFILE_QC`
        else
            BATT_LOGFILE_QC_size=0
        fi
        BATT_LOGFILE_GROUP_size=$(($BATT_LOGFILE_size+$BATT_LOGFILE_QC_size))

        let count=$count+1
        sleep $pause_time

        if [ $BATT_LOGFILE_GROUP_size -gt $BATT_LOGFILE_GROUP_MAX_SIZE ]; then
            mv_files $BATT_LOGFILE
            if [ $dumper_en -eq 1 ]; then
                mv_files $BATT_LOGFILE_QC
            fi
            let file_count=$file_count+1
        fi
    done
fi
