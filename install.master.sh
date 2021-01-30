#!/bin/bash
if [[ "$EUID" -ne 0 ]]; then
	echo "This installer needs to be run with superuser privileges."
	exit
fi


apt-get -yq update && apt-get -yq upgrade && apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common -qy

# Add Repos
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

	

# Install Dependancies

apt-get update -yq && \
apt-get -yq install \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  htop \
  iftop \
  sudo \
  vnstat \
  curl \
  git \
  nano \
  wget \
  docker-ce \
  docker-ce-cli \
  containerd.io
  
# Get Variables..
IP_ADDR=$(curl -s https://ipv4.ixpcontrol.com)
IP6_GEN=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 4 | head -n 1)
COMPOSE_VERSION=$(git ls-remote https://github.com/docker/compose | grep refs/tags | grep -oE "[0-9]+\.[0-9][0-9]+\.[0-9]+$" | sort --version-sort | tail -n 1)
MYSQLPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
MYSQLROOT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
  
# Enable & Start Docker
systemctl enable docker
systemctl start docker

# Confirm Docker Install
docker version

# Install Docker-Compose
wget  https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)
sudo mv ./docker-compose-$(uname -s)-$(uname -m) /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose
export PATH=$PATH:/usr/bin/docker-compose
echo "export PATH=$PATH:/usr/bin/docker-compose" >>  $HOME/.bash_profile
echo "Confirming Docker-Compose is operating"
docker-compose --version
	
# Install Docker-Cleanup ( https://gist.github.com/wdullaer/76b450a0c986e576e98b )
git clone https://gist.github.com/76b450a0c986e576e98b.git /tmp/ixpcontrol/docker-cleanup
mv /tmp/ixpcontrol/docker-cleanup/docker-cleanup /usr/local/bin/docker-cleanup
sudo chmod +x /usr/local/bin/docker-cleanup


# Create Folders
#mkdir -pv 
#Data Folders
mkdir -pv /opt/ixpcontrol/data/bgp;
mkdir -pv /opt/ixpcontrol/data/portainer;
mkdir -pv /opt/ixpcontrol/data/mariadb/data;
mkdir -pv /opt/ixpcontrol/data/mariadb/conf;
mkdir -pv /opt/ixpcontrol/data/apache2/data;
mkdir -pv /opt/ixpcontrol/data/crontab;
mkdir -pv /opt/ixpcontrol/data/zerotier;
#Log Folders
mkdir -pv /opt/ixpcontrol/logs/bgp;
mkdir -pv /opt/ixpcontrol/logs/crontab;
mkdir -pv /opt/ixpcontrol/logs/apache2;
mkdir -pv /opt/ixpcontrol/logs/ixpcontrol;
#Other Folders
mkdir -pv /opt/ixpcontrol/www;
mkdir -pv /opt/ixpcontrol/build;


cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
version: "2.1"

networks:
  peering_v4:
    ipam:
      config:
        - subnet: 10.9.0.0/24
          gateway: 10.9.0.1
  peering_v6:
    enable_ipv6: true
    driver_opts:
      com.docker.network.enable_ipv6: "true"
      com.docker.network.bridge.enable_icc: "true"
      com.docker.network.bridge.enable_ip_forwarding: "true"
      com.docker.network.bridge.enable_ip_masquerade: "true"
    ipam:
      config:
        - subnet: fd83:7684:f21d:$IP6_GEN::/64
          ip_range: fd83:7684:f21d:$IP6_GEN:c0::/80

services:
# Docker-IPv6 NAT Translation Service ( https://github.com/robbertkl/docker-ipv6nat )
  ipv6nat:
    container_name: ipv6nat
    restart: always
    image: robbertkl/ipv6nat
    privileged: true
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /lib/modules:/lib/modules:ro

#Portainer ( https://www.portainer.io )
  portainer: 
    image: portainer/portainer-ce
    container_name: Portainer
    restart: unless-stopped
    environment:
      PUID: 1001
      PGID: 1001
    ports: 
      - 9000:9000
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/ixpcontrol/data/portainer:/data

EOL

read -p "Use BIRD for BGP Session to Upstream? [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
add-apt-repository ppa:cz.nic-labs/bird
apt-get -qy install bird

cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
  upstreambgp:
    image: ixpcontrol/bird.upstream
    container_name: Upstream_BGP
    restart: always
    privileged: true
    network_mode: host
    environment:
      PUID: 1001
      PGID: 1001
EOL

read -p "IPv4 Session? [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
      IPV4_ENABLE: enabled
EOL
read -p "Listen Address: "  bgp4Listen
echo "Setting $bgpListen"
read -p "Your ASN (NUMBERS ONLY): "  bgp4ASN
echo "Setting $bgpASN"
read -p "UPSTREAM ASN (NUMBERS ONLY): "  bgp4UpASN
echo "Setting $bgpUpASN"
read -p "Neighbour IP: "  bgp4UpNeigh
echo "Setting $bgpUpNeigh"
read -p "Anchor Subnet: "  bgp4Anchor
echo "Setting $bgpAnchor"
cat >> /opt/ixpcontrol/data/bgp/bird.conf <<EOL
router id $IP_ADDR;

listen bgp address $bgp4Listen;

log syslog { debug, trace, info, remote, warning, error, auth, fatal, bug };
log stderr all;

protocol kernel {
       learn;                  # Learn all alien routes from the kernel
        persist;                # Don't remove routes on bird shutdown
        scan time 20;           # Scan kernel routing table every 20 seconds
       import none;            # Default is import all
        export none;            # Default is export none
       kernel table 5;         # Kernel table to synchronize with (default: main)
}

protocol static export_routes {
    route $bgp4Anchor via $bgp4Listen;
}

protocol device {
        scan time 60;           # Scan interfaces every 10 seconds
}

 Disable automatically generating direct routes to all network interfaces.
protocol direct {
        disabled;               # Disable by default
}

protocol bgp {
        import all;
        export where proto = "export_routes";
        local as $bgp4ASN;
        neighbor $bgp4UpNeigh as $bgp4UpASN;
}

EOL
else
echo "#NEW FILE#" > /opt/ixpcontrol/data/bgp/bird.conf
fi

read -p "IPv6 Session? [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
      IPV6_ENABLE: enabled
EOL
read -p "Listen Address: "  bgp6Listen
echo "Setting $bgpListen"
read -p "Your ASN (NUMBERS ONLY): "  bgp6ASN
echo "Setting $bgpASN"
read -p "UPSTREAM ASN (NUMBERS ONLY): "  bgp6UpASN
echo "Setting $bgpUpASN"
read -p "Neighbour IP: "  bgp6UpNeigh
echo "Setting $bgpUpNeigh"
read -p "Anchor Subnet: "  bgp6Anchor
echo "Setting $bgpAnchor"

cat >> /opt/ixpcontrol/data/bgp/bird6.conf <<EOL
router id $IP_ADDR;

listen bgp address $bgp6Listen;

log syslog { debug, trace, info, remote, warning, error, auth, fatal, bug };
log stderr all;

protocol kernel {
        persist;                # Don't remove routes on bird shutdown
        scan time 20;           # Scan kernel routing table every 20 seconds
        export none;            # Default is export none
}

protocol static export_routes {
    route $bgp6Anchor via $bgp6Listen;
}

protocol device {
        scan time 60;           # Scan interfaces every 10 seconds
}

# Disable automatically generating direct routes to all network interfaces.
protocol direct {
        disabled;               # Disable by default
}

protocol bgp {
        import all;
        export where proto = "export_routes";
        local as $bgp6ASN;
        neighbor $bgp6UpNeigh as $bgp6UpASN;
}

EOL

else
echo "#NEW FILE#" > /opt/ixpcontrol/data/bgp/bird.conf
fi

fi

cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
    volumes:
      - /opt/ixpcontrol/data/bgp/bird.conf:/usr/local/etc/bird.conf
      - /opt/ixpcontrol/data/bgp/bird6.conf:/usr/local/etc/bird6.conf
      - /opt/ixpcontrol/logs/bgp/bird.log:/var/log/bird.log
      - /opt/ixpcontrol/logs/bgp/bird6.log:/var/log/bird6.log

EOL

read -p "Include ZeroTier for Virtual Connection to Nodes? [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
read -p "ZeroTier Network ID: "  zeroNetwork
echo "Setting $zeroNetwork!"

cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
  zerotier:
    image: ixpcontrol/zerotier
    container_name: ZeroTier
    network_mode: host
    privileged: true
    restart: always
    volumes:
      - /opt/ixpcontrol/data/zerotier:/var/lib/zerotier-one
    environment:
      - NETWORK_ID=$zeroNetwork
EOL
fi

cat >> /opt/ixpcontrol/data/crontab/config.json  <<EOL

EOL

fi


read -p "Add Watchtower for Auto-Update of Docker Containers?  [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
# WatchTower ( https://github.com/containrrr/watchtower )
  watchtower: 
   image: containrrr/watchtower
   container_name: Watchtower
   restart: unless-stopped
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock
   command: --interval 500

EOL

fi

cat >> /opt/ixpcontrol/docker-compose.yml <<EOL

  ixpcontrol:
    image: ixpcontrol/www
	container_name: IXPControl
    depends_on:
      - mariadb
    restart: always
    ports:
      - 9999:80
    links:
      - mariadb
    volumes: 
      - /opt/ixpcontrol/www:/var/www/html
      - /opt/ixpcontrol/logs/apache2:/var/log/apache2
      - /opt/ixpcontrol/data/apache2/data:/etc/apache2

  mariadb:
    image: ixpcontrol/mariadb
    container_name: mariadb
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQLROOT
      MYSQL_DATABASE: ixpcontrol
      MYSQL_USER: ixpcontrol
      MYSQL_PASSWORD: $MYSQLPASS
    networks:
        peering_v4:
            ipv4_address: 10.10.$IXPID.3
        peering_v6:
            ipv6_address: fd83:7684:f21d:$IP6_GEN:c$IXPID::3
    restart: always
    volumes:
      - /opt/ixpcontrol/data/mariadb/data:/var/lib/mysql/data
      - /opt/ixpcontrol/logs/mariadb:/var/lib/mysql/logs
      - /opt/ixpcontrol/data/mariadb/conf:/etc/mysql

EOL
	 
start_ixpcontrol


echo -e "\e[32m ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: \e[1m"
echo -e "\e[32m '####:'##::::'##:'########:::'######:::'#######::'##::: ##:'########:'########:::'#######::'##::::::: \e[1m";
echo -e "\e[32m . ##::. ##::'##:: ##.... ##:'##... ##:'##.... ##: ###:: ##:... ##..:: ##.... ##:'##.... ##: ##::::::: \e[1m"
echo -e "\e[32m : ##:::. ##'##::: ##:::: ##: ##:::..:: ##:::: ##: ####: ##:::: ##:::: ##:::: ##: ##:::: ##: ##::::::: \e[1m"
echo -e "\e[32m : ##::::. ###:::: ########:: ##::::::: ##:::: ##: ## ## ##:::: ##:::: ########:: ##:::: ##: ##::::::: \e[1m"
echo -e "\e[32m : ##:::: ## ##::: ##.....::: ##::::::: ##:::: ##: ##. ####:::: ##:::: ##.. ##::: ##:::: ##: ##::::::: \e[1m"
echo -e "\e[32m : ##::: ##:. ##:: ##:::::::: ##::: ##: ##:::: ##: ##:. ###:::: ##:::: ##::. ##:: ##:::: ##: ##::::::: \e[1m"
echo -e "\e[32m '####: ##:::. ##: ##::::::::. ######::. #######:: ##::. ##:::: ##:::: ##:::. ##:. #######:: ########: \e[1m"
echo -e "\e[32m ....::..:::::..::..::::::::::......::::.......:::..::::..:::::..:::::..:::::..:::.......:::........:: \e[1m"
echo -e "\e[32m :::::::::::::::::::::::::::::::::::: https://www.ixpcontrol.com :::::::::::::::::::::::::::(v 0.1a):: \e[1m"
echo "IXPControl: http://$IP_ADDR:9999"
echo "MySQL Username: root"
echo "MySQL Password: $MYSQLROOT"
echo "MySQL Username: ixpcontrol"
echo "MySQL Password: $MYSQLPASS"
echo ""


