#!/usr/bin/env bash
# Метрики системы раз в $1 мс. В цикле только builtins — без fork на тик
shopt -s nullglob
ms=${1:-1000}
t=$(printf '%d.%03d' $((ms / 1000)) $((ms % 1000)))
exec {sl}<> <(:)

rd() { REPLY=; [[ -r $1 ]] && read -r REPLY < "$1"; }

for d in /sys/class/drm/card*/device; do [[ -r $d/gpu_busy_percent ]] && { gd=$d; break; }; done
rh=(); nh=()
for h in /sys/class/hwmon/hwmon*; do
    rd "$h/name"
    case $REPLY in
        k10temp|coretemp|zenpower) ch=$h ;;
        amdgpu) gh=$h ;;
        spd5118|jc42) rh+=("$h") ;;
        nvme) dv=$(readlink -f "$h/device"); nh+=("${dv##*/}:$h") ;;
        mt79*|iwlwifi*|ath*) wh=$h ;;
    esac
done
ncpu=0
for c in /sys/devices/system/cpu/cpu[0-9]*; do ((ncpu++)); done
cp=/sys/devices/system/cpu/cpu0

# Статичные сведения
model=; cores=
while IFS=: read -r k v; do
    case $k in
        "model name"*) model=${v# } ;;
        "cpu cores"*) cores=${v# } ;;
    esac
    [[ $model && $cores ]] && break
done < /proc/cpuinfo
echo "I cpuModel $model"
echo "I cpuCores $cores"
echo "I threads $ncpu"
rd $cp/cpufreq/cpuinfo_max_freq; echo "I maxFreq $REPLY"
rd $cp/cpufreq/cpuinfo_min_freq; echo "I minFreq $REPLY"
rd $cp/cpufreq/scaling_driver; echo "I freqDriver $REPLY"
rd $cp/cpufreq/scaling_governor; echo "I governor $REPLY"
rd $cp/cpufreq/energy_performance_preference; echo "I epp $REPLY"
rd /sys/devices/system/cpu/cpufreq/boost; echo "I boost $REPLY"
for i in 0 1 2 3; do
    rd $cp/cache/index$i/level; l=$REPLY
    rd $cp/cache/index$i/type; ty=$REPLY
    rd $cp/cache/index$i/size
    [[ $l ]] && echo "I cache$i L$l ${ty:0:1} $REPLY"
done
rd /proc/sys/kernel/osrelease; echo "I kernel $REPLY"
rd /proc/sys/kernel/hostname; echo "I host $REPLY"
echo "I ramModules ${#rh[@]}"
if [[ $gd ]]; then
    while IFS== read -r k v; do
        case $k in PCI_ID) echo "I gpuId $v" ;; DRIVER) echo "I gpuDriver $v" ;; esac
    done < "$gd/uevent"
    rd $gd/vbios_version; echo "I vbios $REPLY"
    rd $gd/current_link_speed; s=$REPLY; rd $gd/current_link_width; echo "I pcie $s x$REPLY"
    rd $gd/mem_info_vram_total; echo "I vramTotal $REPLY"
    rd $gd/mem_info_gtt_total; echo "I gttTotal $REPLY"
    rd $gd/mem_info_vram_vendor; echo "I vramVendor $REPLY"
    x=; while read -r _ f _; do x=$f; done < $gd/pp_dpm_sclk; echo "I sclkMax ${x%[Mm]hz}"
    x=; while read -r _ f _; do x=$f; done < $gd/pp_dpm_mclk; echo "I mclkMax ${x%[Mm]hz}"
fi
if [[ $gh ]]; then
    rd $gh/power1_cap; echo "I powerCap $REPLY"
    rd $gh/fan1_max; echo "I fanMax $REPLY"
fi
echo "IE"

while :; do
    while read -r a b; do
        [[ $a == cpu* ]] || break
        echo "S $a $b"
    done < /proc/stat

    f="F"
    for ((i = 0; i < ncpu; i++)); do rd /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq; f+=" ${REPLY:-0}"; done
    echo "$f"

    m="M"
    while read -r k v _; do
        case $k in
            MemTotal:|MemAvailable:|Buffers:|Cached:|SwapTotal:|SwapFree:|Shmem:|Dirty:|SReclaimable:|SwapCached:) m+=" ${k%:}=$v" ;;
        esac
    done < /proc/meminfo
    echo "$m"

    read -r l1 l2 l3 tk _ < /proc/loadavg
    read -r up _ < /proc/uptime
    echo "L $l1 $l2 $l3 $tk $up"

    tt="T"
    if [[ $ch ]]; then
        for l in "$ch"/temp*_label; do rd "$l"; n=${REPLY// /_}; rd "${l%_label}_input"; tt+=" cpu_$n=$REPLY"; done
    fi
    if [[ $gh ]]; then
        for l in "$gh"/temp*_label; do rd "$l"; n=${REPLY// /_}; rd "${l%_label}_input"; tt+=" gpu_$n=$REPLY"; done
    fi
    for i in "${!rh[@]}"; do rd "${rh[i]}/temp1_input"; tt+=" ram$i=$REPLY"; done
    for e in "${nh[@]}"; do rd "${e#*:}/temp1_input"; tt+=" ${e%%:*}=$REPLY"; done
    [[ $wh ]] && { rd "$wh/temp1_input"; tt+=" wifi=$REPLY"; }
    echo "$tt"

    if [[ $gd ]]; then
        g="G"
        rd $gd/gpu_busy_percent; g+=" busy=$REPLY"
        rd $gd/mem_info_vram_used; g+=" vram=$REPLY"
        rd $gd/mem_info_gtt_used; g+=" gtt=$REPLY"
        if [[ $gh ]]; then
            rd $gh/freq1_input; g+=" sclk=$REPLY"
            rd $gh/freq2_input; g+=" mclk=$REPLY"
            rd $gh/fan1_input; g+=" fan=$REPLY"
            rd $gh/power1_average; [[ $REPLY ]] || rd $gh/power1_input; g+=" power=$REPLY"
            rd $gh/in0_input; g+=" vdd=$REPLY"
        fi
        echo "$g"
    fi

    d="D"
    while read -r _ _ n _ _ rs _ _ _ ws _; do
        case $n in sd[a-z]|nvme[0-9]n[0-9]|vd[a-z]|mmcblk[0-9]) d+=" $n=$rs,$ws" ;; esac
    done < /proc/diskstats
    echo "$d"

    echo "E"
    read -r -t "$t" -u $sl
done
