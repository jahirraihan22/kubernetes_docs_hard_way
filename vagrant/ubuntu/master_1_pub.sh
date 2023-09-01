#! /bin/bash
source .env

if [[ $MASTER_1_PUB_KEY == "" ]]
then
	echo "MASTER_PUB_KEY is empty...Exiting"
	exit 1
fi

cat >> ~/.ssh/authorized_keys <<EOF
$MASTER_1_PUB_KEY
EOF
