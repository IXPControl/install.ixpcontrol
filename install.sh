#!/bin/bash
if [[ "$EUID" -ne 0 ]]; then
	echo "This installer needs to be run with superuser privileges."
	exit
fi

# Detect OS
# $os_version variables aren't always in use, but are kept here for convenience
if grep -qs "ubuntu" /etc/os-release; then
	os="ubuntu"
	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
	group_name="nogroup"
elif [[ -e /etc/debian_version ]]; then
	os="debian"
	os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
	group_name="nogroup"
elif [[ -e /etc/centos-release ]]; then
	os="centos"
	os_version=$(grep -oE '[0-9]+' /etc/centos-release | head -1)
	group_name="nobody"
elif [[ -e /etc/fedora-release ]]; then
	os="fedora"
	os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
	group_name="nobody"
else
	echo "Unsupported Operating System"
	exit
fi

if [[ "$os" == "ubuntu" && "$os_version" -lt 1804 ]]; then
	echo "Unsupported Operating System"
	exit
fi

if [[ "$os" == "debian" && "$os_version" -lt 9 ]]; then
	echo "Supported Operating System"
	exit
fi

if [[ "$os" == "centos" && "$os_version" -lt 7 ]]; then
	echo "Unsupported Operating System"
	exit
fi

echo -n "OceanIXP Server ID [0-9]: "
read IXPID
if [[ ! $IXPID =~ ^[0-9]+$ ]] ; then
    echo "Whoops.. try again, numbers between zero and nine please."
    exit
fi

# Enable net.ipv4.ip_forward for the system
	echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/30-ixpcontrol-forward.conf
# Enable without waiting for a reboot or service restart
	echo 1 > /proc/sys/net/ipv4/ip_forward
	if [[ -n "$ip6" ]]; then
		# Enable net.ipv6.conf.all.forwarding for the system
		echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/30-openvpn-forward.conf
		# Enable without waiting for a reboot or service restart
		echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
	fi
	
# Remove Existing Docker Install
apt-get -yq remove docker docker-engine docker.io containerd runc
	
apt-get -yq update && apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common -qy
	
# Add Repos
add-apt-repository main 2>&1 >> /dev/null
add-apt-repository universe 2>&1 >> /dev/null
add-apt-repository restricted 2>&1 >> /dev/null
add-apt-repository multiverse 2>&1 >> /dev/null
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"


# Install Dependancies

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
IP_ADDR=$(curl -s https://api.ipify.org) 
#IP_ADDR=$(curl -s https://ip.ixpcontrol.com)
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
git clone https://gist.github.com/76b450a0c986e576e98b.git /tmp
mv /tmp/76b450a0c986e576e98b/docker-cleanup /usr/local/bin/docker-cleanup
sudo chmod +x /usr/local/bin/docker-cleanup


# Create Folders
#mkdir -pv 
#Data Folders
mkdir -pv /opt/ixpcontrol/data/bgp;
mkdir -pv /opt/ixpcontrol/data/portainer;
mkdir -pv /opt/ixpcontrol/data/routeserver;
mkdir -pv /opt/ixpcontrol/data/arouteserver;
mkdir -pv /opt/ixpcontrol/data/mariadb/data;
mkdir -pv /opt/ixpcontrol/data/mariadb/conf;
mkdir -pv /opt/ixpcontrol/data/apache2/data;
#Log Folders
mkdir -pv /opt/ixpcontrol/logs/bgp;
mkdir -pv /opt/ixpcontrol/logs/arouteserver;
mkdir -pv /opt/ixpcontrol/logs/apache2;
mkdir -pv /opt/ixpcontrol/logs/ixpcontrol;
#Other Folders
mkdir -pv /opt/ixpcontrol/www;
mkdir -pv /opt/ixpcontrol/build;

#Get Bin Stuff, and move it into place.
git clone http://github.com/IXPControl/bins.git /tmp/ixpcontrol
chmod +x /tmp/ixpcontrol/bin/*
mv /tmp/ixpcontrol/bin/* /bin
cp -rlf /tmp/ixpcontrol/* /
rm -rf /tmp/ixpcontrol


#Set .bash_profile
cat > /root/.bash_profile <<EOL
#!/bin/sh
v4Addr=$(ip route get 8.8.8.8 | head -1 | cut -d' ' -f7)
v6Addr=$(ip -6 route get 2001:4860:4860::8888 | head -1 | cut -d' ' -f9)
v4Session=$(docker ps -a | grep '_v4' | wc -l)
v6Session=$(docker ps -a | grep '_v6' | wc -l)
v4Active=$(docker ps | grep '_v4' | wc -l)
v6Active=$(docker ps | grep '_v6' | wc -l)
v4Inactive=$(docker container ls -f 'status=exited' -f 'status=dead' -f 'status=created' | grep '_v4' | head -1 | wc -l)
v6Inactive=$(docker container ls -f 'status=exited' -f 'status=dead' -f 'status=created' | grep '_v6' | head -1 | wc -l)
RS1Status=$(docker ps -q -f status=running -f name=^/"routeserver"$)
upSeconds="$(/usr/bin/cut -d. -f1 /proc/uptime)"
secs=$((${upSeconds}%60))
mins=$((${upSeconds}/60%60))
hours=$((${upSeconds}/3600%24))
days=$((${upSeconds}/86400))
UPTIME=`printf "%d days, %02dh%02dm%02ds" "$days" "$hours" "$mins" "$secs"`
        clear
        echo ""
		echo -e "\e[32m      ,a8a,  ,ggg,          ,gg ,ggggggggggg,       ,gggg,                                                                    ";
		echo -e "\e[32m     ,8\" \"8,dP\"\"\"Y8,      ,dP' dP\"\"\"88\"\"\"\"\"\"Y8,   ,88\"\"\"Y8b,                              I8                            ,dPYb,\e[1m"
		echo -e "\e[32m     d8   8bYb,_  \"8b,   d8\"   Yb,  88      \`8b  d8\"     \`Y8                              I8                            IP'\`Yb\e[1m"
		echo -e "\e[32m     88   88 \`\"\"    Y8,,8P'     \`\"  88      ,8P d8'   8b  d8                           88888888                         I8  8I\e[1m"
		echo -e "\e[32m     88   88         Y88\"           88aaaad8P\" ,8I    \"Y88P'                              I8                            I8  8'\e[1m"
		echo -e "\e[32m     Y8   8P        ,888b           88\"\"\"\"\"    I8'             ,ggggg,     ,ggg,,ggg,     I8     ,gggggg,    ,ggggg,    I8 dP \e[1m"
		echo -e "\e[32m     \`8, ,8'       d8\" \"8b,         88         d8             dP\"  \"Y8ggg ,8\" \"8P\" \"8,    I8     dP\"\"\"\"8I   dP\"  \"Y8ggg I8dP  \e[1m"
		echo -e "\e[32m8888  \"8,8\"      ,8P'    Y8,        88         Y8,           i8'    ,8I   I8   8I   8I   ,I8,   ,8'    8I  i8'    ,8I   I8P   \e[1m"
		echo -e "\e[32m\`8b,  ,d8b,     d8\"       \"Yb,      88         \`Yba,,_____, ,d8,   ,d8'  ,dP   8I   Yb, ,d88b, ,dP     Y8,,d8,   ,d8'  ,d8b,_ \e[1m"
		echo -e "\e[32m  \"Y88P\" \"Y8  ,8P'          \"Y8     88           \`\"Y8888888 P\"Y8888P\"    8P'   8I   \`Y888P\"\"Y888P      \`Y8P\"Y8888P\"    8P'\"Y88\e[1m"
        echo -e "\e[1;35mSystem Uptime: $UPTIME \e[1m\e[0m"
        echo "IPv4: $v4Addr - IPv6: $v6Addr"
if [ "${RS1Status}" ]; then
  echo -e "Route Server 1 Status: \e[1;32mONLINE\e[1m\e[0m"
else
  echo -e "Route Server 1 Status: \e[1;31mOFFLINE\e[1m\e[0m"
fi
        echo "IPv4 Sessions: $v4Session (Active: $v4Active Inactive: $v4Inactive)"
        echo "IPv6 Sessions: $v6Session (Active: $v6Active Inactive: $v6Inactive)"
        echo ""
        echo "For IXPControl Commands, Please Use The Command 'ixpcontrol_help'"
EOL



cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
version: "2.1"

networks:
  peering_v4:
    ipam:
      config:
        - subnet: 10.10.$IXPID.0/24
          gateway: 10.10.$IXPID.1
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
          ip_range: fd83:7684:f21d:$IP6_GEN:c$IXPID::/80

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

read -p "Use BIRD for BGP Session to Upstream?" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
add-apt-repository ppa:cz.nic-labs/bird
apt-get -qy install bird

read -p "IPv4 Session? [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
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
#router id $IP_ADDR;
#
#listen bgp address $bgpListen port 180;
#
#log syslog { debug, trace, info, remote, warning, error, auth, fatal, bug };
#log stderr all;
#
#protocol kernel {
#       learn;                  # Learn all alien routes from the kernel
#        persist;                # Don't remove routes on bird shutdown
#        scan time 20;           # Scan kernel routing table every 20 seconds
#       import none;            # Default is import all
#        export none;            # Default is export none
#       kernel table 5;         # Kernel table to synchronize with (default: main)
#}
#
#protocol static export_routes {
#    route $bgp6Anchor via $bgp6Listen;
#    route 2a0a:6040:dead::/48 via $bgp6Listen;
#    route 2a0a:6040:beef::/48 via $bgp6Listen;
#	route 2a0a:6040:ac1::/48 via $bgp6Listen;
#	route 2a0a:6040:ac2::/48 via $bgp6Listen;
#}
#
#protocol device {
#        scan time 60;           # Scan interfaces every 10 seconds
#}
#
# Disable automatically generating direct routes to all network interfaces.
#protocol direct {
#        disabled;               # Disable by default
#}
#
#protocol bgp {
#        import all;
#        export where proto = "export_routes";
#        local as $bgpASN;
#        neighbor $bgpUpNeigh as $bgpUpASN;
#}

EOL


read -p "IPv6 Session? [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
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

listen bgp address $bgp6Listen port 180;

log syslog { debug, trace, info, remote, warning, error, auth, fatal, bug };
log stderr all;

protocol kernel {
        persist;                # Don't remove routes on bird shutdown
        scan time 20;           # Scan kernel routing table every 20 seconds
        export none;            # Default is export none
}

protocol static export_routes {
    route $bgp6Anchor via $bg6pListen;
    route 2a0a:6040:dead::/48 via $bgp6Listen;
    route 2a0a:6040:beef::/48 via $bgp6Listen;
	route 2a0a:6040:ac1::/48 via $bgp6Listen;
	route 2a0a:6040:ac2::/48 via $bgp6Listen;
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

fi


cat >> /opt/ixpcontrol/docker-compose.yml <<EOL

  upstreambgp:
    image: ixpcontrol/bird.rs.docker
    container_name: Upstream_BGP
    restart: always
    network_mode: host
    environment:
      PUID: 1001
      PGID: 1001
      IPV4_ENABLE: disabled
      IPV6_ENABLE: enabled
    volumes:
      - /opt/ixpcontrol/data/bgp/bird.conf:/usr/local/etc/bird.conf
      - /opt/ixpcontrol/data/bgp/bird6.conf:/usr/local/etc/bird6.conf
      - /opt/ixpcontrol/logs/bgp/bird.log:/var/log/bird.log
      - /opt/ixpcontrol/logs/bgp/bird6.log:/var/log/bird6.log

EOL

fi

fi



read -p "Include ZeroTier for Virtual Connections? [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
read -p "ZeroTier Network ID: "  zeroNetwork
echo "Setting $zeroNetwork!"

cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
  zerotier:
    image: croc/zerotier
	network_mode: host
    privileged: true
    restart: always
    environment:
      - NETWORK_ID=$zeroNetwork
EOL

read -p "Include Secondary ZeroTier? [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
read -p "Secondary ZeroTier Network ID: "  zeroSecondary
echo "Setting $zeroSecondary!"
cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
      - NETWORK_REGIONAL=$zeroSecondary
EOL
fi

#Add Routeserver to Docker-Compose
cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
  routeserver:
    image: ixpcontrol/bird.rs
    container_name: routeserver
    restart: unless-stopped
    network_mode: host
    environment:
      PUID: 1001
      PGID: 1001
      IPV4_ENABLE: disabled
      IPV6_ENABLE: enabled
    volumes:
      - /opt/ixpcontrol/data/routeserver/bird.conf:/usr/local/etc/bird.conf
      - /opt/ixpcontrol/data/routeserver/bird6.conf:/usr/local/etc/bird6.conf
      - /opt/ixpcontrol/logs/routeserver/bird.log:/var/log/bird.log
      - /opt/ixpcontrol/logs/routeserver/bird6.log:/var/log/bird6.log

EOL


read -p "Add Watchtower for Auto-Update of Docker Containers?" -n 1 -r
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

read -p "Add ARouteServer? (Manual configuration required)" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then


cat >> /opt/ixpcontrol/docker-compose.yml <<EOL

## ARouteServer ( https://arouteserver.readthedocs.io )
  arouteserver:
    build: ixpcontrol/arouteserver
    container_name: arouteserver
    restart: unless-stopped
    network:
        peering_v4:
            ipv4_address: 10.10.$IXPID.2
        peering_v6:
            ipv6_address: fd83:7684:f21d:$IP6_GEN:c$IXPID::2
    environment:
      SETUP_AND_CONFIGURE_AROUTESERVER: 0
      PUID: 1001
      PGID: 1001
    volumes:
      - /opt/ixpcontrol/data/routeserver/bird.conf:/etc/bird/bird.conf
      - /opt/ixpcontrol/data/routeserver/bird6.conf:/etc/bird/bird6.conf
      - /opt/ixpcontrol/data/arouteserver/clients.yml:/root/clients.yml
      - /opt/ixpcontrol/data/arouteserver/general.yml:/etc/arouteserver/general.yml
      - /opt/ixpcontrol/logs/arouteserver/bird.log:/var/log/bird.log

EOL





read -p "Install the Panel Stuff?" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then

cat >> /opt/ixpcontrol/docker-compose.yml <<EOL

  ixpcontrol:
    image: ixpcontrol/www
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
	    network:
        peering_v4:
            ipv4_address: 10.10.$IXPID.2
        peering_v6:
            ipv6_address: fd83:7684:f21d:$IP6_GEN:c$IXPID::2  
    restart: always
    volumes:
      - /opt/ixpcontrol/data/mariadb/data:/var/lib/mysql/data
      - /opt/ixpcontrol/logs/mariadb:/var/lib/mysql/logs
      - /opt/ixpcontrol/data/mariadb/conf:/etc/mysql
EOL
	 
	 

read -p "Want to add PowerDNS (PDNS) Stack to IXPControl?" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then


fi


start_ixpcontrol

echo -e "\e[32m      ,a8a,  ,ggg,          ,gg ,ggggggggggg,       ,gggg,                                                                    ";
echo -e "\e[32m     ,8\" \"8,dP\"\"\"Y8,      ,dP' dP\"\"\"88\"\"\"\"\"\"Y8,   ,88\"\"\"Y8b,                              I8                            ,dPYb,\e[1m"
echo -e "\e[32m     d8   8bYb,_  \"8b,   d8\"   Yb,  88      \`8b  d8\"     \`Y8                              I8                            IP'\`Yb\e[1m"
echo -e "\e[32m     88   88 \`\"\"    Y8,,8P'     \`\"  88      ,8P d8'   8b  d8                           88888888                         I8  8I\e[1m"
echo -e "\e[32m     88   88         Y88\"           88aaaad8P\" ,8I    \"Y88P'                              I8                            I8  8'\e[1m"
echo -e "\e[32m     Y8   8P        ,888b           88\"\"\"\"\"    I8'             ,ggggg,     ,ggg,,ggg,     I8     ,gggggg,    ,ggggg,    I8 dP \e[1m"
echo -e "\e[32m     \`8, ,8'       d8\" \"8b,         88         d8             dP\"  \"Y8ggg ,8\" \"8P\" \"8,    I8     dP\"\"\"\"8I   dP\"  \"Y8ggg I8dP  \e[1m"
echo -e "\e[32m8888  \"8,8\"      ,8P'    Y8,        88         Y8,           i8'    ,8I   I8   8I   8I   ,I8,   ,8'    8I  i8'    ,8I   I8P   \e[1m"
echo -e "\e[32m\`8b,  ,d8b,     d8\"       \"Yb,      88         \`Yba,,_____, ,d8,   ,d8'  ,dP   8I   Yb, ,d88b, ,dP     Y8,,d8,   ,d8'  ,d8b,_ \e[1m"
echo -e "\e[32m  \"Y88P\" \"Y8  ,8P'          \"Y8     88           \`\"Y8888888 P\"Y8888P\"    8P'   8I   \`Y888P\"\"Y888P      \`Y8P\"Y8888P\"    8P'\"Y88\e[1m"
echo "IXPControl: http://$IP_ADDR:9999"
echo "MySQL Username: root"
echo "MySQL Password: $MYSQLROOT"
echo "MySQL Username: ixpcontrol"
echo "MySQL Password: $MYSQLPASS"
echo ""


