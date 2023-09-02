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

wget https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/


echo -e "Generate a kubeconfig file for the kube-proxy service: \n"

kubectl config set-cluster $CLUSTER_NAME \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://${LOADBALANCER}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=/var/lib/kubernetes/pki/kube-proxy.crt \
  --client-key=/var/lib/kubernetes/pki/kube-proxy.key \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=$CLUSTER_NAME \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

sleep 1

echo -e "Generate a kubeconfig file for the kube-scheduler service: \n"

kubectl config set-cluster $CLUSTER_NAME \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=/var/lib/kubernetes/pki/kube-scheduler.crt \
  --client-key=/var/lib/kubernetes/pki/kube-scheduler.key \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=$CLUSTER_NAME \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

sleep 1

echo -e "Generate a kubeconfig file for the kube-controller-manager service:"

kubectl config set-cluster $CLUSTER_NAME \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=/var/lib/kubernetes/pki/kube-controller-manager.crt \
  --client-key=/var/lib/kubernetes/pki/kube-controller-manager.key \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=$CLUSTER_NAME \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

sleep 1

echo -e "Generate a kubeconfig file for the kube-scheduler service:"

kubectl config set-cluster $CLUSTER_NAME \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=/var/lib/kubernetes/pki/kube-scheduler.crt \
  --client-key=/var/lib/kubernetes/pki/kube-scheduler.key \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=$CLUSTER_NAME \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

sleep 1

echo -e "Generate a kubeconfig file for the admin service:"

kubectl config set-cluster $CLUSTER_NAME \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.crt \
  --client-key=admin.key \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=$CLUSTER_NAME \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

sleep 1

echo -e "Copy the appropriate kube-proxy kubeconfig files to each worker instance:"
for instance in worker-1 worker-2; do
  scp kube-proxy.kubeconfig ${instance}:~/
done

echo -e "Copy the appropriate admin.kubeconfig, kube-controller-manager and kube-scheduler kubeconfig files to each controller instance:"
for instance in master-1 master-2; do
  scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${instance}:~/
done

