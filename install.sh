#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

print_status() {
    echo -e
    echo -e "## $1"
    echo -e
}

if [ $# -lt 3 ]; then
    echo -e "Execution format ./install.sh zelnode_privkey collateral_txid tx_output_index nodetype"
    exit
fi

# Installation variables
zelnode_privkey=${1}
collateral_txid=${2}
tx_output_index=${3}
externalip=$(dig +short myip.opendns.com @resolver1.opendns.com)

if [ -z "$4" ]; then
  nodetype="basic"
else
  nodetype=${4}
fi

print_status "Installing the ZelCash node..."

echo -e "#########################"
echo -e "zelnode_privkey: $zelnode_privkey"
echo -e "collateral_txid: $collateral_txid"
echo -e "tx_output_index: $tx_output_index"
echo -e "#########################"

createswap() {
  # Create swapfile if less then 4GB memory
  totalmem=$(free -m | awk '/^Mem:/{print $2}')
  totalswp=$(free -m | awk '/^Swap:/{print $2}')
  totalm=$(($totalmem + $totalswp))
  if [ $totalm -lt 4000 ]; then
    print_status "Server memory is less then 4GB..."
    if ! grep -q '/swapfile' /etc/fstab ; then
      print_status "Creating a 4GB swapfile..."
      fallocate -l 4G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo -e '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
  fi
}

populateaptcache() {
  # Populating Cache
  print_status "Populating apt cache..."
  apt update
}

installdocker() {
  # Install Docker
  if ! hash docker 2>/dev/null; then
    print_status "Installing Docker..."
    apt -y remove docker docker-engine docker.io containerd runc > /dev/null 2>&1
    apt -y install \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg-agent \
      lsb-release \
      software-properties-common \
      > /dev/null 2>&1
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-key fingerprint 0EBFCD88
    add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
    apt-get update
    apt-get -y install \
      docker-ce \
      docker-ce-cli \
      containerd.io
      > /dev/null 2>&1
    systemctl enable docker
    systemctl start docker
  fi
  adduser $SUDO_USER docker
}

installdependencies() {
  print_status "Installing packages required for setup..."
  apt -y install \
  unattended-upgrades \
  dnsutils \
  wget \
  unzip \
  > /dev/null 2>&1
}

createdirs() {
  print_status "Creating the docker mount directories..."
  mkdir -p /mnt/zelcash/{config,data,zcash-params,}
}

zelconfig() {
  print_status "Creating the zel configuration."
  echo -e "rpcuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
rpcallowip=172.18.0.0/16
rpcport=16124
port=16125
zelnode=1
zelnodeprivkey=${zelnode_privkey}
zelnodeoutpoint=${collateral_txid}
zelnodeindex=${tx_output_index}
server=1
daemon=0
txindex=1
listen=1
externalip=${externalip}
bind=0.0.0.0
addnode=explorer.zel.cash
addnode=explorer2.zel.cash
addnode=explorer.zel.zelcore.io
addnode=blockbook.zel.network
maxconnections=256" | tee /mnt/zelcash/config/zelcash.conf
}

zelcashdservice() {
  print_status "Installing zelcash service..."
  echo -e "[Unit]
Description=ZeCash Daemon Container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=10m
Restart=always
ExecStartPre=-/usr/bin/docker stop zelcashd
ExecStartPre=-/usr/bin/docker rm  zelcashd
# Always pull the latest docker image
ExecStartPre=/usr/bin/docker pull greerso/zelcashd:latest
ExecStart=/usr/bin/docker run --rm --net=host -p 16125:16125 -p 16124:16124 -v /mnt/zelcash:/mnt/zelcash --name zelcashd greerso/zelcashd:latest
[Install]
WantedBy=multi-user.target" | tee /etc/systemd/system/zelcashd.service
}

startcontainers() {
  print_status "Enabling and starting container services..."
  systemctl daemon-reload
  systemctl enable zelcashd
  systemctl restart zelcashd
}

zelalias() {
  if ! grep -q "alias zelcash-cli" $HOME/.aliases ; then
    echo -e "alias zelcash-cli=\"docker exec -it zelcashd /usr/sbin/gosu user zelcash-cli\"" | tee -a $HOME/.aliases
  fi
  
  if ! grep -q ". $HOME/.aliases" $HOME/.bashrc ; then
    echo -e "if [ -f $HOME/.aliases ]; then . $HOME/.aliases; fi" | tee -a $HOME/.bashrc
  fi

  if ! grep -q "source $HOME/.aliases" $HOME/.zshrc ; then
    echo -e "source $HOME/.aliases" | tee -a $HOME/.zshrc
  fi

  su $($SUDO_USER) -c 'source $HOME/.aliases'
}

fetchparams() {
  print_status "Waiting for node to fetch params ..."
  until docker exec -it zelcashd /usr/sbin/gosu user zelcash-cli getinfo
  do
    echo -e ".."
    sleep 30
  done
}

getbootstrap() {
  # Check for and download blockchain bootstrap
  if [ ! -d "/mnt/zelcash/config/blocks" ]; then
      echo "Downloading ZelCash Blockchain Bootstrap"
      $(wget https://zelcore.io/zelcashbootstraptxindex.zip)
      $(unzip zelcashbootstraptxindex.zip -d /mnt/zelcash/config)
      $(rm zelcashbootstraptxindex.zip)
  fi
}

createswap
populateaptcache
installdocker
installdependencies
createdirs
zelconfig
zelcashdservice
startcontainers
fetchparams
getbootstrap

print_status "Install Finished"
echo -e "Please wait until the blocks are up to date..."
## add check for blocks up to date