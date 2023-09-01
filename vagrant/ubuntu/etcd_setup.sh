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

####################################### end checking

INTERNAL_IP=$(ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d / -f 1)
ETCD_NAME=$(hostname -s)

echo -e "Download the official etcd release binaries from the etcd GitHub project: "

wget -q --show-progress --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/v$ETCD_VERSION/etcd-v$ETCD_VERSION-linux-amd64.tar.gz"

echo -e "\n Extract and install the etcd server and the etcdctl command line utility: \n"
tar -xvf etcd-v$ETCD_VERSION-linux-amd64.tar.gz
sudo mv etcd-v$ETCD_VERSION-linux-amd64/etcd* /usr/local/bin/

echo -e "\n Copying and secure certificates. Note that we place ca.crt in our main PKI directory and link it from etcd to not have multiple copies of the cert lying around.\n"
sudo mkdir -p /etc/etcd /var/lib/etcd /var/lib/kubernetes/pki
sudo cp etcd-server.key etcd-server.crt /etc/etcd/
sudo cp ca.crt /var/lib/kubernetes/pki/
sudo chown root:root /etc/etcd/*
sudo chmod 600 /etc/etcd/*
sudo chown root:root /var/lib/kubernetes/pki/*
sudo chmod 600 /var/lib/kubernetes/pki/*
sudo ln -s /var/lib/kubernetes/pki/ca.crt /etc/etcd/ca.crt

echo -e "\nCreate the etcd.service systemd unit file:\n"

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/etcd-server.crt \\
  --key-file=/etc/etcd/etcd-server.key \\
  --peer-cert-file=/etc/etcd/etcd-server.crt \\
  --peer-key-file=/etc/etcd/etcd-server.key \\
  --trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster master-1=https://${MASTER_1}:2380,master-2=https://${MASTER_2}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo -e "\nStarting etcd server\n"
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

sleep 5

echo -e "\nList the etcd cluster members:\n"

sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt \
  --cert=/etc/etcd/etcd-server.crt \
  --key=/etc/etcd/etcd-server.key