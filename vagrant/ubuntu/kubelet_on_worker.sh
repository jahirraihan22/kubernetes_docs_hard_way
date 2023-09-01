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
HOSTNAME=$(hostname -s)
CLUSTER_DNS=$(echo $SERVICE_CIDR | awk 'BEGIN {FS="."} ; { printf("%s.%s.%s.10", $1, $2, $3) }')

wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v$KUBE_PROXY_VERSION/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v$KUBELET_VERSION/bin/linux/amd64/kubelet 

sudo mkdir -p \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes/pki \
  /var/run/kubernetes

chmod +x kubectl kube-proxy kubelet
sudo mv kubectl kube-proxy kubelet /usr/local/bin/


echo -e "\nCopying keys and config to correct directories and secure\n"

sudo mv ${HOSTNAME}.key ${HOSTNAME}.crt /var/lib/kubernetes/pki/
sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubelet.kubeconfig
sudo mv ca.crt /var/lib/kubernetes/pki/
sudo mv kube-proxy.crt kube-proxy.key /var/lib/kubernetes/pki/
sudo chown root:root /var/lib/kubernetes/pki/*
sudo chmod 600 /var/lib/kubernetes/pki/*
sudo chown root:root /var/lib/kubelet/*
sudo chmod 600 /var/lib/kubelet/*

echo -e "\nCreate the kubelet-config.yaml configuration file:\n"


cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /var/lib/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
  - ${CLUSTER_DNS}
resolvConf: /run/systemd/resolve/resolv.conf
runtimeRequestTimeout: "15m"
tlsCertFile: /var/lib/kubernetes/pki/${HOSTNAME}.crt
tlsPrivateKeyFile: /var/lib/kubernetes/pki/${HOSTNAME}.key
registerNode: true
EOF

echo -e "\nCreate the kubelet.service systemd unit file:\n"

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubelet.kubeconfig \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo -e "\nConfigure the Kubernetes Proxy\n"

sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kube-proxy.kubeconfig"
mode: "iptables"
clusterCIDR: ${POD_CIDR}
EOF

echo -e "\nCreate the kube-proxy.service systemd unit file:\n"

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable kubelet kube-proxy
sudo systemctl start kubelet kube-proxy

sleep 3

