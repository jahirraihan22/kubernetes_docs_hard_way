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
WORKER_NODE_NAME=worker-1 # Bootstrapping the Kubernetes Worker Nodes 

cat > openssl-$WORKER_NODE_NAME.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = $WORKER_NODE_NAME
IP.1 = ${WORKER_1}
EOF

openssl genrsa -out $WORKER_NODE_NAME.key 2048
openssl req -new -key $WORKER_NODE_NAME.key -subj "/CN=system:node:$WORKER_NODE_NAME/O=system:nodes" -out $WORKER_NODE_NAME.csr -config openssl-$WORKER_NODE_NAME.cnf
openssl x509 -req -in $WORKER_NODE_NAME.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out $WORKER_NODE_NAME.crt -extensions v3_req -extfile openssl-$WORKER_NODE_NAME.cnf -days 1000

kubectl config set-cluster $CLUSTER_NAME \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://${LOADBALANCER}:6443 \
  --kubeconfig=$WORKER_NODE_NAME.kubeconfig

kubectl config set-credentials system:node:$WORKER_NODE_NAME \
  --client-certificate=/var/lib/kubernetes/pki/$WORKER_NODE_NAME.crt \
  --client-key=/var/lib/kubernetes/pki/$WORKER_NODE_NAME.key \
  --kubeconfig=$WORKER_NODE_NAME.kubeconfig

kubectl config set-context default \
  --cluster=$CLUSTER_NAME \
  --user=system:node:$WORKER_NODE_NAME \
  --kubeconfig=$WORKER_NODE_NAME.kubeconfig

kubectl config use-context default --kubeconfig=$WORKER_NODE_NAME.kubeconfig

scp ca.crt $WORKER_NODE_NAME.crt $WORKER_NODE_NAME.key $WORKER_NODE_NAME.kubeconfig $WORKER_NODE_NAME:~/

