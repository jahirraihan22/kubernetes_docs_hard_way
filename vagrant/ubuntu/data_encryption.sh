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

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

echo -e "encryption-config.yaml \n"

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

echo -e "Copy the encryption-config.yaml encryption config file to each controller instance:\n"

for instance in master-1 master-2; do
  scp encryption-config.yaml ${instance}:~/
done

echo -e "Move encryption-config.yaml encryption config file to appropriate directory.\n"
for instance in master-1 master-2; do
  ssh ${instance} sudo mkdir -p /var/lib/kubernetes/
  ssh ${instance} sudo mv encryption-config.yaml /var/lib/kubernetes/
done