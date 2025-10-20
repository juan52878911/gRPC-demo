#cloud-config
package_update: true
package_upgrade: true

users:
  - name: ubuntu
    groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo,docker
    shell: /bin/bash
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_public_key}

ssh_deletekeys: false
ssh_pwauth: false

# Instalar dependencias básicas y Docker
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - software-properties-common
  - python3
  - python3-pip
  - vim
  - wget
  - htop

# Configurar límites del sistema para Kubernetes
bootcmd:
  - modprobe br_netfilter || true
  - modprobe overlay || true
  - echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.conf || true
  - echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
  - echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.conf || true
  - sysctl -p || true

# Archivos de configuración
write_files:
  - path: /etc/docker/daemon.json
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "100m",
          "max-file": "3"
        },
        "storage-driver": "overlay2"
      }
    permissions: '0644'

  - path: /etc/sysctl.d/99-kubernetes.conf
    content: |
      net.bridge.bridge-nf-call-iptables = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward = 1
      vm.swappiness = 0
    permissions: '0644'

  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter
    permissions: '0644'

# Comandos a ejecutar durante la inicialización
runcmd:
  # Cargar módulos del kernel necesarios
  - modprobe overlay || true
  - modprobe br_netfilter || true

  # Instalar Docker (compatible con ARM64 y AMD64)
  - |
    ARCH=$(dpkg --print-architecture)
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu

  # Crear directorios necesarios
  - mkdir -p /var/log/rancher
  - chown ubuntu:ubuntu /var/log/rancher

final_message: "Worker node dependencies installed after $UPTIME seconds. Ready for Ansible configuration."