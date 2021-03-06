#!/bin/bash
echo "*******************************************************************************"
echo "                     01coin Masternode Setup Shell Script"
echo "                              Created by Evydder"
echo "*******************************************************************************"
homedir=$( getent passwd "$USER" | cut -d: -f6 )
install_preqs()
{
	echo "*******************************************************************************"
	echo "                           Installing Requirements"
	echo "*******************************************************************************"
	
	issudoinstalled="$(dpkg-query -W -f='${Status}' sudo 2>/dev/null | grep -c 'ok installed')"
	if [ $issudoinstalled = '0' ]
	then
	apt install -y sudo
	fi
	
	sudo apt install -y software-properties-common
	sudo add-apt-repository -y ppa:bitcoin/bitcoin
	sudo apt update 
	sudo apt install -y build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-all-dev libdb4.8-dev libdb4.8++-dev python-virtualenv nano git openssl dnsutils
}

download()
{
	echo "*******************************************************************************"
	echo "                      Downloading and Installing 01coin"
	echo "*******************************************************************************"
	
	if [ "$release" = '16.04' ] 
	then
	#Only needed for 16.04
		sudo apt-get install -y libminiupnpc-dev 
	fi
	mkdir ~/zeroone
	# wget http://files.01coin.io/build/linux/zeroonecore-0.12.3-x86_64-linux-gnu.tar.gz
	wget https://bitbucket.org/zocteam/zeroonecoin/downloads/zeroonecore-0.12.3-x86_64-linux-gnu.tar.gz
	tar -xvf zeroonecore-0.12.3-x86_64-linux-gnu.tar.gz
	rm ~/zeroonecore-0.12.3-x86_64-linux-gnu.tar.gz
	mv ~/zeroonecore-0.12.3/bin/* ~/zeroone/
	
	mkdir ~/.zeroonecore
}

compile()
{
#checks ram and makes swap if nessary
	ram="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
	minram="1048576"
	if [ "$ram" -le "$minram" ]
	then
		dd if=/dev/zero of=/swapfile count=2048 bs=1M
		chmod 600 /swapfile
		mkswap /swapfile
		swapon /swapfile
		echo "/swapfile   none    swap    sw    0   0" > /etc/fstab
	fi
	# Download and Compile 
	git clone https://github.com/zocteam/zeroonecoin
	cd ~/zeroonecoin
	sudo ./autogen.sh
	sudo ./configure CXXFLAGS="--param ggc-min-expand=1 --param ggc-min-heapsize=32768"
	cpucores = grep -c ^processor /proc/cpuinfo
	sudo make -j$cpucores
	mkdir ~/zeroone
	mv ~/zeroonecoin/src/zerooned ~/zeroone/zerooned
	mv ~/zeroonecoin/src/zeroone-cli ~/zeroone/zeroone-cli
	mv ~/zeroonecoin/src/zeroone-tx ~/zeroone/zeroone-tx
}

configQuestions()
{
	echo "*******************************************************************************"
	echo "                                    Config"
	echo "*******************************************************************************"

	#ram
	ram="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
	minram="1048576"
	if [ "$ram" -le "$minram" ]
	then
		echo "**************************************************************"
	while true; do
		read -p "Would you like to setup an swapfile to help with compiling?  [Y/N] " yn
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) echo "This script will now close";exit;;
			* ) echo "Please answer yes or no.";;
		esac
	done
	fi
	
	#IP
	vpsip=$(dig +short myip.opendns.com @resolver1.opendns.com)
	while true; do
		read -p "Is this your VPS IP address? ${vpsip} [Y/N] " yn
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) echo "Please type in your VPS IP address below:"; read vpsip;;
			* ) echo "Please answer yes or no.";;
		esac
	done

	rpcuser=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32})
	rpcpassword=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32})
	
	#Needed to be appended to the file before ask for incase of want to gen key Privatekey
	if [ ! -d ".zeroonecore" ]; then
		mkdir ~/.zeroonecore 
	fi
	
	echo "rpcuser=${rpcuser}" >> .zeroonecore/zeroone.conf
	echo "rpcpassword=${rpcpassword}" >> .zeroonecore/zeroone.conf
	
	echo "**************************************************************"
	while true; do
		read -p "Would you like to provide a private key (if you already have one)? ${privkey} [Y/N] " yn
		case $yn in
			[Yy]* ) echo "Please type in your private key below:"; askforprivatekey;break;;
			[Nn]* ) genkey;break;;
			* ) echo "Please answer yes or no.";;
		esac
	done

	echo "**************************************************************"
	while true; do
		read -p "Would you like a shell script to start the node?  [Y/N] " yn
		case $yn in
			[Yy]* ) echo "$homedir/zeroone/zerooned -daemon ">> startZeroOne.sh;askstartonboot;break;;
			[Nn]* ) break;;
			* ) echo "Please answer yes or no.";;
		esac
	done
	
	echo "**************************************************************"
	while true; do
		read -p "Would you like to install a node manager to keep the blockchain synced?  [Y/N] " yn
		case $yn in
			[Yy]* ) setup_manager;break;;
			[Nn]* ) break;;
			* ) echo "Please answer yes or no.";;
		esac
	done

}

askforprivatekey()
{
#Masternode Priv Key
	read privkey
	while true; do
		read -p "Is this the correct private key? ${privkey} [Y/N] " yn
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) echo "Please type in your private key below:"; read privkey;;
			* ) echo "Please answer yes or no.";;
		esac
	done
}

askstartonboot()
{
	echo "**************************************************************"
	while true; do
		read -p "Would you like to start the node automatically on boot?  [Y/N] " yn
		case $yn in
			[Yy]* ) startonboot;break;;
			[Nn]* ) break;;
			* ) echo "Please answer yes or no.";;
		esac
	done
}

startonboot()
{
	chmod -x startZeroOne.sh
	chmod 777 startZeroOne.sh
	sudo echo "@reboot $homedir/startZeroOne.sh" >> /etc/crontab
}

genkey()
{
		$homedir/zeroone/zerooned -daemon
		echo "Please wait while the 01coin daemon generates a new private key..."
		sleep 10
		while ! $homedir/zeroone/zeroone-cli getinfo; do
			sleep 10
		done
		privkey=$($homedir/zeroone/zeroone-cli masternode genkey)
		$homedir/zeroone/zeroone-cli stop
		sleep 10
}

setup_manager()
{
	
	wget https://raw.githubusercontent.com/zocteam/zoc-tools/master/mnchecker
	chmod 777 mnchecker
	echo "rpcport=10101" >> .zeroonecore/zeroone.conf

	crontab -l > mncheckercron
	echo "*/10 * * * * $homedir/mnchecker --currency-bin-cli=$homedir/zeroone/zeroone-cli --currency-bin-daemon=$homedir/zeroone/zerooned --currency-datadir=.zeroonecore" >> mncheckercron
	crontab mncheckercron
	rm mncheckercron
}

config()
{
	echo "*******************************************************************************"
	echo "                        Configuring 01coin Masternode"
	echo "*******************************************************************************" 
	
	echo "externalip=${vpsip}:10000" >> .zeroonecore/zeroone.conf
	echo "masternode=1" >> .zeroonecore/zeroone.conf
	echo "masternodeprivkey=${privkey}" >> .zeroonecore/zeroone.conf
	echo "maxconnections=16" >> .zeroonecore/zeroone.conf
}

sentinel()
{
	echo "*******************************************************************************"
	echo "                         Installing 01coin Sentinel"
	echo "*******************************************************************************" 
	
	cd ~
	
	sudo apt install -y python-virtualenv virtualenv
	
	git clone https://github.com/zocteam/sentinel.git zoc_sentinel
	cd zoc_sentinel
	virtualenv ./venv
	./venv/bin/pip install -r requirements.txt
	
	crontab -l > mycron
	echo "* * * * * cd $(pwd) && SENTINEL_DEBUG=1 ./venv/bin/python bin/sentinel.py >> zoc_sentinel.log >/dev/null 2>&1" >> mycron
	crontab mycron
	rm mycron
	cd ~
}
bootstrap()
{
	cd $homedir
    cd .zeroonecore
    rm -f bootstrap.dat.old
    wget https://files.01coin.io/mainnet/bootstrap.dat.tar.gz
    tar xvf bootstrap.dat.tar.gz
    rm -f bootstrap.dat.tar.gz
}

start_mn()
{
	echo "*******************************************************************************"
	echo "                         Starting 01coin Masternode"
	echo "*******************************************************************************"

	$homedir/zeroone/zerooned -daemon -assumevalid=0000000005812118515c654ab36f46ef2b7b3732a6115271505724ff972417c7
	echo 'If the above says "ZeroOne Core server starting" then masternode is installed' 

}

adds_nodes()
{
	$homedir/zeroone/zeroone-cli stop
	sleep 10
	#fixes error if folders dont exist
	if [ ! -d ".zeroonecore" ]; then
		mkdir .zeroonecore 
	fi	
	addnodes
	#Reason for not starting it manually is I don't know where it's installed
	echo "*******************************************************************************"
	echo "                    Please Manually Start Your Masternode"
	echo "*******************************************************************************"

	info
	#Kill off the program
	exit 1
}

info()
{

	echo "*******************************************************************************"
	echo "                                Information"
	echo "*******************************************************************************"
	echo "In your local wallet, please append the following to masternode.conf:"
	echo ""
	echo "MN-X ${vpsip}:10000 ${privkey} collateral_output_txid collateral_output_index"
	echo ""
	echo "To manually start the node run            : zeroone/zerooned -daemon "
	echo "To check the status of the masternode run : zeroone/zeroone-cli getinfo "
	echo ""
	echo "If you require any help ask in the Discord server: https://discord.gg/jbMjjnV"
	echo ""
	echo "If this helps you out and you want to tip :"
	echo "(ZOC) ZNZL6JXTeF3nP8fSWf46wbRqAMjLezyRHK"
	echo "*******************************************************************************"

}

install_mn()
{
#Checks Versions
release=$(lsb_release -r -s)
case $release in
"14.04")
	download;;

"16.04")
	download;;

"18.04")
	download;;

"19.04")
	download;;
*)
	compile;;
	esac
}

#checks if install is there and ask if want reset it
if [ -d ".zeroonecore" ]; then
	echo "*******************************************************************************"
	echo "                                An Existing Setup Detected"
	echo "*******************************************************************************"
	while true; do
		read -p "Would you like to reset the install?  [Y/N] " yn
		case $yn in
			[Yy]* ) sudo rm -R .zeroonecore/;break;;
			[Nn]* ) exit 1;break;;
			* ) echo "Please answer yes or no.";;
		esac
	done
	fi	
#checks args then runs the functions
case $1 in
compile)
	install_preqs
	compile
	configQuestions
	sentinel
	config
	bootstrap
	start_mn
	info;;
manager)
	setup_manager;;
*)
	install_preqs
	install_mn
	configQuestions
	sentinel
	config
	bootstrap
	start_mn
	info
;;
esac
