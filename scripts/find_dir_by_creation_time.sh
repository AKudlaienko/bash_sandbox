#!/bin/bash

# This script can find subfolders based on a creation date.
# The script searches folders under the provided path then checks corresponding
# inode creation time and compares it with a provided time gap in seconds.
# So, if the the difference (timestamp_now - folder_creation_timestamp), is bigger than the provided period,
# the script prints the result or can remove corresponding folders if --remove option was specified.

usage() {
  echo -e "\nUsage:\n  $0 -d /tmp/test -D /dev/vda1 -p 2629743\
   \n -d (--dir)  full path to the directory to scan subdirectories in; \
   \n -D (--device) the device to scan on, likde /dev/vda1; \
   \n -p (--period) time gap in seconds; \
   \n     --remove [y|yes] If defined, then ALL found files will be REMOVED !"
}


if [ $(whoami) != "root" ];then
  echo -e "\nSUDO privileges needed!\n"
  exit 1
fi


if [ $# -lt 6 -o $# -eq 7 ];then
  usage
  exit 1
fi

DATETIME_NOW_EPOCH=$(date +"%s")
ARGS=""
while (( "$#" )); do
    case "$1" in
      -d|--dir)
        DIR=$2
        shift 2
        ;;
      -D|--device)
        DEVICE=$2
        shift 2
        ;;
      -p|--period)
        PERIOD=$2
        shift 2
        ;;
      --remove)
        REMOVE=$2
        shift 2
        ;;
      *)
        usage
        exit 1
        ;;
    esac
done

eval set -- "$ARGS"

if [[ -z "$DIR" || -z "$DEVICE" ]] || [[ -z "$PERIOD" ]]; then
  usage
  exit 1
fi

if [[ -n $REMOVE ]] && [[ "$REMOVE" != "y" && "$REMOVE" != "yes" ]];then
  usage
  exit 1
fi


for e_folder in $(find $DIR -mindepth 1 -maxdepth 1 -type d | xargs);do
  RES=$(debugfs -R "stat <$(ls -id $e_folder | cut -d' ' -f1)>" "$DEVICE" 2>/dev/null)
  raw_folder_timestamp=$(echo -e "$RES" | tail -4 | grep crtime | awk -F"--" '{print$2}' | awk '{$1=$1;print}')
  folder_timestamp=$(date +"%s" -d "$raw_folder_timestamp")

  if [[ -z "$folder_timestamp" || $folder_timestamp -gt $DATETIME_NOW_EPOCH ]];then
    echo -e "\nIt seems that something went wrong. We got timestamp from a future :)"
    exit 1
  fi

  if [ $(($DATETIME_NOW_EPOCH - $folder_timestamp)) -ge $PERIOD ];then
    if [[ -n $REMOVE ]];then
      rm -fr "$e_folder"
    else
      echo "$e_folder"
    fi

  fi

done
