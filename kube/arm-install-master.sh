sh ./arm-install.sh



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




rm /etc/kubernetes/manifests/kube-vip.yaml
cp ./kube-vip.yaml /etc/kubernetes/manifests/




kubeadm join 192.168.1.250:6443 --token th215m.36fvgzfv424dsuw9 \
        --discovery-token-ca-cert-hash sha256:b2ab702211bdc47f1416562cf20676f584fa044df9972fc504482c29d2645930 \
        --control-plane --certificate-key 78fdd303a3cfe1c0b196223969dc9a614ec24e403ff61747bb3ce7bf5df31146


sudo nano /boot/firmware/cmdline.txt

cgroup_enable=memory cgroup_memory=1


