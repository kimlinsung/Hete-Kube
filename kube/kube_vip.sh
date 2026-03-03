

#三个都要kube-vip3
apt update && apt install -y jq
export VIP=192.168.1.250
export INTERFACE=eth0
KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")

alias kube-vip="ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION; ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip"
kube-vip manifest pod \
    --interface $INTERFACE \
    --address $VIP \
    --controlplane \
    --services \
    --arp \
    --leaderElection | tee /etc/kubernetes/manifests/kube-vip.yaml


#修改hostpath为super-admin.conf


kubeadm init   --control-plane-endpoint "192.168.1.250:6443"   --upload-certs   --pod-network-cidr=10.244.0.0/16   --kubernetes-version=v1.33.2

#修改回admin.conf

wget https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kube apply -f kube-flannel.yml


#加入集群
kubeadm join 192.168.1.250:6443 --token th215m.36fvgzfv424dsuw9 \
        --discovery-token-ca-cert-hash sha256:b2ab702211bdc47f1416562cf20676f584fa044df9972fc504482c29d2645930 \
        --control-plane --certificate-key 78fdd303a3cfe1c0b196223969dc9a614ec24e403ff61747bb3ce7bf5df31146




