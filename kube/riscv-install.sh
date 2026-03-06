cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF
sudo modprobe br_netfilter
sudo modprobe ip_vs
sudo modprobe ip_vs_rr
sudo modprobe ip_vs_wrr
sudo modprobe ip_vs_sh
sudo modprobe nf_conntrack

#配置 sysctl 并永久保存
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness = 0
EOF
sudo sysctl --system

#关闭 swap（立即 + 永久）
sudo swapoff -a
sudo sed -i '/\sswap\s/s/^/#/' /etc/fstab

#禁用 Ubuntu 防火墙（ufw）
sudo systemctl stop ufw
sudo systemctl disable ufw
ufw disable
ufw stop
sudo systemctl stop nftables
sudo systemctl disable nftables
sudo systemctl stop dphys-swapfile
sudo systemctl disable dphys-swapfile
sudo swapoff -a

# 禁用 zram 初始化服务（核心）
sudo systemctl disable --now systemd-zram-setup@zram0.service

# 屏蔽服务（防止被其他进程自动拉起）
sudo systemctl mask systemd-zram-setup@zram0.service

# 若存在 zram 回写服务，同样禁用（树莓派部分版本有）
sudo systemctl disable --now rpi-zram-writeback.service
sudo systemctl mask rpi-zram-writeback.service

# 重载 systemd 配置使修改生效
sudo systemctl daemon-reload



mkdir -p /run/flannel
cat <<EOF >/run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
EOF



mkdir -p /etc/systemd/system/containerd.service.d/
cat <<EOF >/etc/systemd/system/containerd.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://192.168.1.119:7897"
Environment="HTTPS_PROXY=http://192.168.1.119:7897"
Environment="ALL_PROXY=socks5h://192.168.1.119:7897"
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl restart containerd









export https_proxy=http://192.168.1.119:7897      http_proxy=http://192.168.1.119:7897     all_proxy=socks5://192.168.1.119:7897







mkdir kube && cd kube
apt purge containerd -y
apt autoremove -y
apt install sudo wget curl -y

wget https://github.com/containerd/containerd/releases/download/v1.6.2/containerd-1.6.2-linux-riscv64.tar.gz
sudo tar Cxzvf /usr/local containerd-2.0.5-linux-riscv64.tar.gz

wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo mkdir -p /usr/local/lib/systemd/system
sudo cp containerd.service /usr/local/lib/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

wget https://github.com/opencontainers/runc/releases/download/v1.4.0/runc.riscv64
sudo install -m 755 runc.riscv64 /usr/local/sbin/runc
sudo mkdir -p /opt/cni/bin

wget https://github.com/containernetworking/plugins/releases/download/v1.9.0/cni-plugins-linux-riscv64-v1.9.0.tgz
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-riscv64-v1.6.2.tgz
sudo cp kubeadm kubelet kubectl /usr/bin/






cat <<EOF >/etc/systemd/system/kubelet.service
#/usr/lib/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/kubelet.service.d/10-kubeadm.conf
#/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
#Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable kubelet
#重载并重启 kubelet
sudo mkdir -p /run/systemd/resolve
echo "nameserver 8.8.8.8" | sudo tee /run/systemd/resolve/resolv.conf

ctr -n k8s.io images import kube1340clientriscv64.tar




sudo apt-get remove --purge -y kubelet kubeadm kubectl
sudo apt-mark unhold kubelet kubeadm kubectl


sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet






unset https_proxy  http_proxy all_proxy no_proxy