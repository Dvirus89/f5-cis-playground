#!/bin/bash
apt-get update -y
snap install microk8s --classic
microk8s status -w
echo 'alias k="microk8s kubectl"' >> ~/.bashrc
echo 'alias kubectl="microk8s kubectl"' >> ~/.bashrc
echo 'alias helm="microk8s helm"' >> ~/.bashrc
cat /etc/netplan/50-cloud-init.yaml | sed 's/ens5/ens6/g' > /etc/netplan/70-cloud-init.yaml
netplan apply
sed -i 's@10.1.0.0/16@10.100.0.0/16@g' /var/snap/microk8s/current/args/cni-network/cni.yaml
sed -i 's@10.1.0.0/16@10.100.0.0/16@g' /var/snap/microk8s/current/args/kube-proxy
microk8s kubectl apply -f /var/snap/microk8s/current/args/cni-network/cni.yaml
microk8s kubectl delete ippools default-ipv4-pool -n kube-system
microk8s kubectl rollout restart daemonset/calico-node -n kube-system
microk8s reset
microk8s start
microk8s enable dns
microk8s enable metrics-server
microk8s enable dashboard
microk8s enable hostpath-storage
snap restart microk8s
./fix-worker-subnet.sh
