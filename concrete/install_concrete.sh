#!/bin/bash
#!/bin/bash

# Check if I am root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root." 1>&2
    exit 1
fi

echo ">>>>>> Installing $NM Masternodes..."

echo ">>>>>> Installing required components..."

apt-get -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y install \
 aptitude \
 software-properties-common \
 sshpass \
 build-essential \
 libtool \
 autotools-dev \
 autoconf \
 automake \
 wget \
 htop \
 unzip \
 curl \
 jq \
 git

if [[ $? -ne 0 ]]; then
    echo "error found" 1>&2
    exit 1
fi

add-apt-repository -y ppa:bitcoin/bitcoin  1>/dev/null 2>&1
add-apt-repository -y ppa:ubuntu-toolchain-r/test 1>/dev/null 2>&1

apt-get -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y update
apt-get -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y full-upgrade

apt-get -qq -y autoremove

apt-get -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y install \
 libssl-dev \
 libboost-all-dev \
 libdb4.8-dev \
 libdb4.8++-dev \
 libminiupnpc-dev \
 libqt4-dev \
 libprotobuf-dev \
 protobuf-compiler \
 libevent-pthreads-2.0-5 \
 libqrencode-dev \
 pkg-config \
 libzmq3-dev \
 libevent-dev

if [[ $? -ne 0 ]]; then
    echo "error found" 1>&2
    exit 1
fi

BASENAME="concrete"
BASEPORT=32812
BASERPCPORT=32813
DFTPORT=32812
CONFIGFILE="${BASENAME}.conf"
PIDFILE="${BASENAME}d.pid"
CLIENT="${BASENAME}-cli"
SERVER="${BASENAME}d"
TX="${BASENAME}-tx"
TMPDIR="${HOME}/cctmp"
IP=`dig +short ANY myip.opendns.com @resolver1.opendns.com`

if [ -d $HOME/.${BASENAME} ]; then
    echo "Masternode is already installed, if you want to reinstall you must remove it before" 1>&2
    exit 1
fi

echo ">>>>>> Locating latest Concrete version..."

TARBALLURL=$(curl -s https://api.github.com/repos/ZioFabry/concrete/releases/latest | grep "browser_download_url.*linux\-ubuntu18\.tar\.gz"| cut -d '"' -f 4)
TARBALLNAME=$(echo "${TARBALLURL}"|awk -F '/' '{print $NF}')

if [[ ${#TARBALLNAME} -eq 0 ]]; then
    echo "TARBALL not found" 1>&2
    exit 1
fi

echo ">>>>>> Locating latest snapshot..."

SNAPSHOTURL=$(curl -s https://api.github.com/repos/ZioFabry/concrete/releases/latest | grep "browser_download_url.*snapshot\-.*\.zip" | cut -d '"' -f 4)
SNAPSHOTNAME=$(echo "${SNAPSHOTURL}"|awk -F '/' '{print $NF}')

if [[ ${#SNAPSHOTNAME} -eq 0 ]]; then
    echo "SNAPSHOT not found"
fi

echo "Tarball : ${TARBALLURL} -> ${TARBALLNAME}"
echo "Snapshot: ${SNAPSHOTURL} -> ${SNAPSHOTNAME}"
echo "Server  : ${SERVER}"
echo "Client  : ${CLIENT}"
echo "Home    : ${HOME}"
echo "Config  : ${CONFIGFILE}"
echo "IP      : ${IP}"

rm -rf $TMPDIR
mkdir -p $TMPDIR/snap

pushd $TMPDIR 1>/dev/null 2>&1

echo ">>>>>> Donwloading Concrete..."
rm -f $TARBALLNAME
wget $TARBALLURL
if [[ $? -ne 0 ]]; then
    echo "Unable to download $TARBALLURL" 1>&2
    exit 1
fi

tar zxvvf $TARBALLNAME 1>/dev/null
cp $CLIENT /usr/local/bin
cp $SERVER /usr/local/bin
cp $TX /usr/local/bin

if [[ ${#SNAPSHOTNAME} -gt 0 ]]; then
    echo ">>>>>> Downloading Snapshot to $TMPDIR/${SNAPSHOTNAME}..."
    
    wget $SNAPSHOTURL
    
    if [[ $? -ne 0 ]]; then
        echo "Unable to download $SNAPSHOTURL" 1>&2
        SNAPSHOTNAME=""
    else
        unzip -d $TMPDIR/snap $TMPDIR/${SNAPSHOTNAME}
    fi
fi

if ! [ -f /swapfile ]; then
    echo ">>>>>> Generating Swapfile..."
    MEM=$(free|grep Mem|awk '{print $2}')
    SWAP=$(expr $MEM / 1024 / 1024 + 1)
    fallocate -l ${SWAP}G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    swapon --show
    free -h
fi

configureNode()
{
    SNAP=$1
    MN=$2
    PKEY=$3
    DIR=${HOME}/.${BASENAME}
    CFG=${DIR}/${CONFIGFILE}
    PORT=$DFTPORT
    MAXCONN=512
    RPCPORT=$BASERPCPORT

    mkdir -p $DIR

    if [[ $SNAP -eq 1 ]]; then
        echo "Installing snapshot into $DIR"
        cp -r $TMPDIR/snap/* $DIR
    fi

    echo "Generating config file $CFG"
    
    cat >$CFG << _EOF
datadir=${HOME}/.${BASENAME}${NUM}
bind=0.0.0.0:${PORT}
externalip=${IP}
rpcbind=127.0.0.1
rpcconnect=127.0.0.1
rpcport=${RPCPORT}
rpcallowip=127.0.0.0/24
rpcuser=concrete
rpcpassword=_bah1la137h1g1
listen=1
daemon=1
server=1
staking=1
logintimestamps=1
logips=1
port=${PORT}
maxconnections=${MAXCONN}
_EOF

    if [[ $MN -eq 1 ]]; then
        cat >>$CFG << _EOF
masternode=1
masternodeaddr=${IP}:${PORT}
masternodeprivkey=${PKEY}
_EOF
    fi
}

startNode()
{
    CFG=${HOME}/.${BASENAME}/${CONFIGFILE}

    echo "Starting node..."
    /usr/local/bin/$SERVER -conf=${CFG}
}

stopNode()
{
    CFG=${HOME}/.${BASENAME}/${CONFIGFILE}
    PID=${HOME}/.${BASENAME}/${PIDFILE}

    echo "Stopping node..."
    /usr/local/bin/${CLIENT} -conf=${CFG} stop
    while [ -f ${PID} ]; do
        sleep 2s
    done
}

# ------------------------------------------------------------------------------------------------

echo ">>>>>> Starting the 1st node to generate the masternode keys..."

configureNode 0 0 ''
startNode 

CFG=${HOME}/.${BASENAME}/${CONFIGFILE}

echo "Waiting 5 seconds..."
sleep 5s

echo "Generating keys..."
p=0
MNKEY[$p]=`/usr/local/bin/${CLIENT} -conf=${CFG} createmasternodekey`
echo "Key: ${MNKEY[$p]}"

stopNode
sleep 2s

rm -rf ${HOME}/.${BASENAME}

# ------------------------------------------------------------------------------------------------

echo ">>>>>> Creating masterndoes $i..."
p=0
configureNode 1 1 ${MNKEY[$p]}
startNode

# ------------------------------------------------------------------------------------------------

echo ">>>>>> Generating Alias/Config..."

echo "alias p='ps -efH'" >>${HOME}/.bash_aliases

sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' ${HOME}/.bashrc
sed -i 's/ls \-CF/ls \-alh/g' ${HOME}/.bashrc
sed -i 's/;32m/;31m/g' ${HOME}/.bashrc

# ------------------------------------------------------------------------------------------------

echo ">>>>>> Generating Script..."

echo "#!/bin/bash" >$HOME/startNodes.sh
CFG=${HOME}/.${BASENAME}/${CONFIGFILE}
PID=${HOME}/.${BASENAME}/${PIDFILE}
echo "if [ \$(ps -efH|grep $SERVER|grep \"\\.${BASENAME}\"|wc -l) -eq 0 ]; then /usr/local/bin/$SERVER -conf=$CFG; fi" >>$HOME/startNodes.sh
chmod +x $HOME/startNodes.sh

echo "#!/bin/bash" >$HOME/stopNodes.sh
CFG=${HOME}/.${BASENAME}/${CONFIGFILE}
PID=${HOME}/.${BASENAME}/${PIDFILE}
echo "if [ -f ${PID} ]; then /usr/local/bin/$CLIENT -conf=$CFG stop; fi" >>$HOME/stopNodes.sh
chmod +x $HOME/stopNodes.sh

echo ">>>>>> Generating crontab..."

/usr/bin/crontab -l |grep -v "startNode\.sh" >$TMPDIR/crontab.last
echo "*/5 * * * * ${HOME}/startNodes.sh 1>/dev/null 2>&1" >>$TMPDIR/crontab.last
crontab $TMPDIR/crontab.last

# ------------------------------------------------------------------------------------------------

clear

echo "# you can use this masternode.conf configuration in you control wallet to start the masternodes, please change 'tx' & 'idx' with your collateral tx info"
echo ""

ls $HOME/.${BASENAME}*/${CONFIGFILE} | sort | while read FILE; do
    LN=${#FILE}
    ADDR=$(grep "masternodeaddr\=" $FILE|awk -F '=' '{print $2}')
    MNKEY=$(grep "masternodeprivkey\=" $FILE|awk -F '=' '{print $2}')

    echo "MN ${ADDR} ${MNKEY} <tx> <id>"
done

NP=$(ps -efH|grep $SERVER|grep "\-conf\="|wc -l)

echo ""
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo ""
echo "concrete processes is running... to start/stop your nodes you can use the following commands:"
echo ""
echo "    ~/startNodes.sh"
echo "    ~/stopNodes.sh"
echo ""
echo "Now you can logoff & logon again to this vps to activate the 'aliases' commands mentioned above,"
echo "or you can execute this command to activate on-the-fly:"
echo ""
echo "    source $HOME/.bashrc"

popd 1>/dev/null 2>&1

rm -rf $TMPDIR
