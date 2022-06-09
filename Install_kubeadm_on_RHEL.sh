# Change Hostname of Machine permanently
hostnamectl set-hostname 'k8s-master'
#git
# Disable selinux
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

# Disable Swap 
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system

# Set Firewall Rules
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10251/tcp
firewall-cmd --permanent --add-port=10252/tcp
firewall-cmd --permanent --add-port=10255/tcp
firewall-cmd --reload

# Add Docker-Repo
cat <<EOF | sudo tee /etc/yum.repos.d/docker.repo
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/centos/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg

[centos-extras]
name=Centos extras - $basearch
baseurl=http://mirror.centos.org/centos/7/extras/x86_64
enabled=1
gpgcheck=1
gpgkey=http://centos.org/keys/RPM-GPG-KEY-CentOS-7
EOF


# Install docker-ce , docker-ce-cli , containerd & docker-compose-plugin
yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install kubeadm, kubectl, kubelet & kubernetes-cni


Goto:  vi /etc/containerd/config.toml
Comment this line: disabled_plugins = ["cri"]


# List all the required images
kubeadm config images list

# If Internet working then 
kubeadm config images pull

# If internet not working then create a aws ec2 with intenet and download all the images there and export then using docker or ctr.
docker save busybox > busybox.tar
ctr images export image.tar <whatever-my-image-ref>

# Then goto your server without internet and import the images to k8s.io namespace.
ctr -n k8s.io i import kube-scheduler.tar

# If you need to delete all the images then:
ctr -n k8s.io images rm $(ctr -n k8s.io images ls name~='k8s' | awk {'print $1'})

# To list all the images:
ctr -n k8s.io i ls

sudo systemctl daemon-reload
systemctl restart docker && systemctl enable docker
systemctl restart containerd && systemctl enable containerd
systemctl  restart kubelet && systemctl enable kubelet

# If you wish to see default values of kubeadm then:
kubeadm config print init-defaults > init.yaml
sudo kubeadm init --config=init.yaml

# Initilize cluster:
kubeadm init --pod-network-cidr 192.168.0.0/16 --apiserver-advertise-address=10.190.165.58  --kubernetes-version=1.24.0

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# By default, apps won’t get scheduled on the master node. If you want to use the master node for scheduling apps then remove taint from master node.
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-


# Command to install the calico network plugin on the cluster.
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml


Note:
1. If you get an error while scheduling related to DiskPressure then dick if you have space available in your root volume.
2. List of images currently present in my server:
docker.io/calico/cni:v3.23.1 
docker.io/calico/kube-controllers:v3.23.1 
docker.io/calico/node:v3.23.1
k8s.gcr.io/coredns/coredns:v1.8.6
k8s.gcr.io/etcd:3.5.3-0
k8s.gcr.io/kube-apiserver:v1.24.0 
k8s.gcr.io/kube-controller-manager:v1.24.0
k8s.gcr.io/kube-proxy:v1.24.0 
k8s.gcr.io/kube-scheduler:v1.24.0
k8s.gcr.io/pause:3.7                                                    
k8s.gcr.io/pause:3.6                                                    

