#!/bin/bash
if [[ "$EUID" -ne 0 ]]; then
	echo "This installer needs to be run with superuser privileges."
	exit
fi


apt-get -yq update && apt-get -yq upgrade && apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common -qy

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
IP_ADDR=$(curl -s https://ip.ixpcontrol.com)
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
mkdir -pv /opt/ixpcontrol/data/routeserver/CONFIG;
mkdir -pv /opt/ixpcontrol/data/routeserver/PEERS;
mkdir -pv /opt/ixpcontrol/data/routeserver/SHARED;
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
#git clone http://github.com/IXPControl/bins.git /tmp/ixpcontrol
#chmod +x /tmp/ixpcontrol/bin/*
#mv /tmp/ixpcontrol/bin/* /bin
#cp -rlf /tmp/ixpcontrol/* /
#rm -rf /tmp/ixpcontrol

## CREATE BINS
cat > /bin/ixpcontrol_help <<EOL
#!/bin/bash
        clear
        echo ""
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
        echo -e "\e[0m"
		echo "IXPControl is a Community Based, Open-Source Internet Exchange Point Management System"
		echo "Please Visit https://www.ixpcontrol.com for more info"
		echo ""
        echo ":: Core Commands ::"
		echo ""
        echo "start/stop_ixpcontrol - Start/Stop All Required CTs (Includes Client BIRD Services)"
        echo "start/stop_rs - Start/Stop Route Server"
        echo "start/stop_www - Start/Stop IXPControl Web Interface Management"
        echo "start/stop_zerotier - Start/Stop ZeroTier One Service"
        echo "start/stop_openvpn - Start/Stop OpenVPN Service"
        echo "build_ixp - Build all docker files locally"
        echo "ixpclient - Create New Connection for IX"
		echo "rs4 - BIRDC Interface with RouteServer"
		echo "rs6 - BIRDC6 Interface with RouteServer"
		echo "up4 - BIRDC Interface with Upstream BGP"
		echo "up6 - BIRDC Interface with Upstream BGP"
        echo ""
		
EOL
chmod +x /bin/ixpcontrol_help;
cat > /bin/rs6 <<EOL
#!/bin/bash
echo "`date -u` Invoked ROUTESERVER6 Manual Commands Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker exec routeserver birdc6
EOL
chmod +x /bin/rs6;
cat > /bin/rs4 <<EOL
#!/bin/bash
echo "`date -u` Invoked ROUTESERVER4 Manual Commands Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker exec routeserver birdc
EOL
chmod +x /bin/rs4;
cat > /bin/up4 <<EOL
#!/bin/bash
echo "`date -u` Invoked UPSTREAM4 Manual Commands Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker exec Upstream_BGP birdc
EOL
chmod +x /bin/up4;
cat > /bin/up6 <<EOL
#!/bin/bash
echo "`date -u` Invoked UPSTREAM6 Manual Commands Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker exec Upstream_BGP birdc6
EOL
chmod +x /bin/up6;
cat > /bin/stop_zerotier <<EOL
#!/bin/bash
echo "`date -u` Invoked stop_zerotier Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml down zerotier
echo "`date -u` IXPControl ZeroTier Interface Stopped" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
EOL
chmod +x /bin/stop_zerotier;
cat > /bin/stop_www <<EOL
#!/bin/bash
echo "`date -u` Invoked stop_www Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml down ixpcontrol
echo "`date -u` IXPControl Web Interface Stopped" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
EOL
chmod +x /bin/stop_www;
cat > /bin/stop_rs <<EOL
#!/bin/bash
echo "`date -u` Invoked stop_rs Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml down routeserver
echo "`date -u` IXPControl RouteServer Stopped" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
EOL
chmod +x /bin/stop_rs;
cat > /bin/stop_openvpn <<EOL
#!/bin/bash
echo "`date -u` Invoked stop_openvpn Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml down openvpn
echo "`date -u` IXPControl OpenVPN Interface Stopped" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
EOL
chmod +x /bin/stop_openvpn;
cat > /bin/stop_ixpcontrol <<EOL
#!/bin/bash
echo "`date -u` Invoked Stop_IXPControl Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml down
echo "`date -u` Stop_IXPControl Stopped" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
EOL
chmod +x /bin/stop_ixpcontrol;
cat > /bin/start_zerotier <<EOL
#!/bin/bash
echo "`date -u` Invoked start_zerotier Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml up zerotier -d
echo "`date -u` IXPControl ZeroTier Interface Started" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
EOL
chmod +x /bin/start_zerotier;
cat > /bin/start_www <<EOL
#!/bin/bash
echo "`date -u` Invoked start_www Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml up ixpcontrol -d
echo "`date -u` IXPControl Web Interface Started" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
EOL
chmod +x /bin/start_www;
cat > /bin/start_rs <<EOL
#!/bin/bash
echo "`date -u` Invoked start_rs Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml up routeserver -d
echo "`date -u` IXPControl RouteServer 1 Started" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
EOL
chmod +x /bin/start_rs;
cat > /bin/start_openvpn <<EOL
#!/bin/bash
echo "`date -u` Invoked start_openvpn Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml up openvpn -d
echo "`date -u` IXPControl OpenVPN Interface Started" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
EOL
chmod +x /bin/start_openvpn;
cat > /bin/start_ixpcontrol <<EOL
#!/bin/bash
echo "`date -u` Invoked Stop_IXPControl Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml down
echo "`date -u` Stop_IXPControl Stopped" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
echo "`date -u` Invoked Stop_IXPControl Command via Shell" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
docker-compose -f /opt/ixpcontrol/docker-compose.yml up -d
echo "`date -u` Stop_IXPControl Started" >> /opt/ixpcontrol/logs/ixpcontrol/shell.log
EOL
chmod +x /bin/start_ixpcontrol;

wget https://raw.githubusercontent.com/IXPControl/bins/main/bin/ixpclient -O /bin/ixpclient;
chmod +x /bin/ixpclient;



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

listen bgp address $bgp4Listen port 180;

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

listen bgp address $bgp6Listen port 180;

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

read -p "Include ZeroTier for Virtual Connections? [Y/N]" -n 1 -r
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
fi

#Add Routeserver to Docker-Compose
cat >> /opt/ixpcontrol/docker-compose.yml <<EOL

  routeserver:
    image: ixpcontrol/bird.rs
    container_name: RouteServer
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      PUID: 1001
      PGID: 1001
EOL
read -p "RouteServer - Enable Bird4 for IPv4 Sessions? [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
      IPV4_ENABLE: enabled
EOL
fi

read -p "RouteServer - Enable Bird6 for IPv6 Sessions? [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
      IPV6_ENABLE: enabled
EOL
fi
cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
    volumes:
      - /opt/ixpcontrol/data/routeserver/bird.conf:/usr/local/etc/bird.conf
      - /opt/ixpcontrol/data/routeserver/bird6.conf:/usr/local/etc/bird6.conf
	  - /opt/ixpcontrol/data/routeserver:/root/ixpcontrol
      - /opt/ixpcontrol/logs/routeserver/bird.log:/var/log/bird.log
      - /opt/ixpcontrol/logs/routeserver/bird6.log:/var/log/bird6.log

EOL

read -p "Add BGPQ3 for Automated IRR Filtering?  [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
cat >> /opt/ixpcontrol/docker-compose.yml <<EOL
  bgpq4:
    image: ixpcontrol/bgpq4.rs
    container_name: BGPQ4.RS
    networks:
        peering_v4:
            ipv4_address: 10.10.$IXPID.4
        peering_v6:
            ipv6_address: fd83:7684:f21d:$IP6_GEN:c$IXPID::4
    volumes:
      - /opt/ixpcontrol/data/routeserver:/root/ixpcontrol
    restart: always

EOL
fi

## Add info here, to set up RS Configs :)


##IPv4 GEN
read -p "RouteServer IPv4 IP (ie, 10.10.5.1 : "  rs_ip4
echo "Setting $rs_ip4!"

read -p "RouteServer IPv4 ASN (Note: Cannot Use as a CLIENT): "  rs4_asn
echo "Setting $rs4_asn!"

cat > /opt/ixpcontrol/data/routeserver/bird6.conf <<EOL
router id $rs_ip4;

define RS_ASN		= $rs4_asn;
define RS_IP		= $rs_ip4;
define PREFIX_MIN	= 48;
define RS_ID		= $rs_ip4;
define PREFIX_MAX	= 8;

listen bgp address RS_IP;

include "/root/ixpcontrol/SHARED/*.conf";
include "/root/ixpcontrol/CONFIG/*_v4.conf";
include "/root/ixpcontrol/PEERS/*/prefix_v4.conf";
include "/root/ixpcontrol/PEERS/*/peer_v4.conf";
EOL

cat > /opt/ixpcontrol/data/routeserver/CONFIG/bogons.conf <<EOL
define V4_BOGONS = [
    0.0.0.0/0, 
    0.0.0.0/8+, 
    10.0.0.0/8+, 
    100.64.0.0/10, 
    127.0.0.0/8, 
    192.168.0.0/16+, 
    169.254.0.0/16+, 
    192.0.2.0/24+, 
    172.16.0.0/12+, 
    224.0.0.0/3+, 
    198.51.100.0/24+, 
    198.18.0.0/15+, 
    203.0.113.0/24+, 
    224.0.0.0/4,
    240.0.0.0/4
];

define ASN_BOGONS = [
    0,                      # RFC 7607
    23456,                  # RFC 4893 AS_TRANS
    64496..64511,           # RFC 5398 and documentation/example ASNs
    64512..65534,           # RFC 6996 Private ASNs
    65535,                  # RFC 6996 Last 16 bit ASN
    65536..65551,           # RFC 5398 and documentation/example ASNs
    65552..131071,          # RFC IANA reserved ASNs
    4200000000..4294967294, # RFC 6996 Private ASNs
    4294967295              # RFC 6996 Last 32 bit ASN
];
EOL

##IPv6 GEN

read -p "RouteServer IPv6 IP (ie, 2a0a:2a0a:2a0a::1 : "  rs_ip6
echo "Setting $rs_ip6!"

read -p "RouteServer IPv6 ASN (Note: Cannot Use as a CLIENT): "  rs6_asn
echo "Setting $rs6_asn!"

cat > /opt/ixpcontrol/data/routeserver/bird6.conf <<EOL
router id 10.10.$IXPID.1;

define RS_ASN		= $rs6_asn;
define RS_IP		= $rs_ip6;
define PREFIX_MIN	= 48;
define RS_ID		= 10.10.$IXPID.1;
define PREFIX_MAX	= 8;

listen bgp address RS_IP;

include "/root/ixpcontrol/SHARED/*.conf";
include "/root/ixpcontrol/CONFIG/*_v6.conf";
include "/root/ixpcontrol/PEERS/*/prefix_v6.conf";
include "/root/ixpcontrol/PEERS/*/peer_v6.conf";
EOL


cat > /opt/ixpcontrol/data/routeserver/CONFIG/bogons.conf <<EOL
define V6_BOGONS = [
    0000::/8+,
    0100::/8+,
    0200::/7+,
    0400::/6+,
    0800::/5+,
    1000::/4+,
    4000::/3+,
    6000::/3+,
    8000::/3+,
    A000::/3+,
    C000::/3+,
    E000::/4+,
    F000::/5+,
    F800::/6+,
    FC00::/7+,
    FE00::/9+,
    FE80::/10+,
    FEC0::/10+,
    FF00::/8+ 
];

define ASN_BOGONS = [
    0,                      # RFC 7607
    23456,                  # RFC 4893 AS_TRANS
    64496..64511,           # RFC 5398 and documentation/example ASNs
    64512..65534,           # RFC 6996 Private ASNs
    65535,                  # RFC 6996 Last 16 bit ASN
    65536..65551,           # RFC 5398 and documentation/example ASNs
    65552..131071,          # RFC IANA reserved ASNs
    4200000000..4294967294, # RFC 6996 Private ASNs
    4294967295              # RFC 6996 Last 32 bit ASN
];
EOL

#SHARED

cat > /opt/ixpcontrol/data/routeserver/SHARED/protocols.conf <<EOL
template bgp ix_peer
{
	local RS_IP as RS_ASN;
	rs client;
}

protocol device {
		scan time 10;
}
EOL


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

read -p "Add ARouteServer? (Manual configuration required)  [Y/N]" -n 1 -r
echo  ""
if [[ $REPLY =~ ^[Yy]$ ]]
then


cat >> /opt/ixpcontrol/docker-compose.yml <<EOL

## ARouteServer ( https://arouteserver.readthedocs.io )
  arouteserver:
    image: ixpcontrol/arouteserver
    container_name: arouteserver
    restart: unless-stopped
    networks:
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


fi


read -p "Install the Panel Stuff?  [Y/N]" -n 1 -r
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
	 
fi	 


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

ixpcontrol_help


