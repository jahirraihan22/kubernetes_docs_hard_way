#! /bin/bash

# Check if the script is being run as root
if [[ $(id -u) -ne 0 ]]; then
  echo "Please run this script as root."
sleep 2
  
  exit 1
fi

envPath=$(echo "$0" | sed "s/\/[^/]*$/\/\.env/")
sleep 2


if [[ -e "$envPath" ]]; then
    source $envPath
else
    echo ".env is required.....exiting"
sleep 2

    exit 1
fi

