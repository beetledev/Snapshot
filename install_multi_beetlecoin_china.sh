#!/bin/bash
#!/bin/bash

# Check if I am root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root." 1>&2
    exit 1
fi

NM=$1
LOOP=1
while [[ $LOOP -eq 1 ]]; do
    read -p "How many BeetleCoin masternode do you want install? [1-64]: " -e NM

    re='^[0-9]+$'
    if [[ $NM =~ $re ]]; then
        if [[ $NM -ge 1 && $NM -le 64 ]]; then
            LOOP=0
        fi
    fi
done

echo ">>>>>> Installing $NM Masternodes..."

NUMMN=`expr $NM + 0`

echo ">>>>>> Installing required components..."

apt-get -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y install \
 aptitude \
 software-properties-common \
 build-essential \
 libtool \
 autotools-dev \
 autoconf \
 automake \
 wget \
 htop \
 unzip \
 curl \
 git

if [[ $? -ne 0 ]]; then
    echo "error found" 1>&2
    exit 1
fi

add-apt-repository -y ppa:bitcoin/bitcoin  1>/dev/null 2>&1

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

BASENAME="beetlecoin"
BASEPORT=42300
BASERPCPORT=43300
DFTPORT=3133
CONFIGFILE="${BASENAME}.conf"
PIDFILE="${BASENAME}d.pid"
CLIENT="${BASENAME}-cli"
SERVER="${BASENAME}d"
TX="${BASENAME}-tx"
TMPDIR="${HOME}/beettmp"
IP=`dig +short ANY myip.opendns.com @resolver1.opendns.com`

for i in $(seq -f '%02g'  1  $NUMMN); do
    if [ -d $HOME/.${BASENAME}$i ]; then
        echo "MultiMasternode $i is already installed, if you want to reinstall you must remove it before" 1>&2
        exit 1
    fi
done

echo ">>>>>> Locating latest BeetleCoin version..."

TARBALLNAME=$(curl -s http://129.211.7.77/file/|grep href|grep linux.tar.gz|awk 'match($0, /href=\"([^\"]+)/,arr) {print arr[1]}'|sort|tail -1)
TARBALLURL="http://129.211.7.77/file/${TARBALLNAME}"

if [[ ${#TARBALLNAME} -eq 0 ]]; then
    echo "TARBALL not found" 1>&2
    exit 1
fi

echo ">>>>>> Locating latest snapshot..."

SNAPSHOTNAME=$(curl -s http://129.211.7.77/file/|grep href|grep snapshot|awk 'match($0, /href=\"([^\"]+)/,arr) {print arr[1]}'|sort|tail -1)
SNAPSHOTURL="http://129.211.7.77/file/${SNAPSHOTNAME}"

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

echo ">>>>>> Donwloading BettleCoin..."
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
    NUM=$1
    SNAP=$2
    MN=$3
    PKEY=$4
    DIR=${HOME}/.${BASENAME}${NUM}
    CFG=${DIR}/${CONFIGFILE}
    if [[ `expr $NUM + 0` -eq 1 ]]; then
        PORT=$DFTPORT
        MAXCONN=256
    else
        PORT=`expr $BASEPORT + $NUM`
        MAXCONN=128
    fi
    RPCPORT=`expr $BASERPCPORT + $NUM`

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
rpcuser=beetlecoin${NUM}
rpcpassword=_${NUM}_bca14a12gh8sg1
listen=1
daemon=1
server=1
staking=0
logintimestamps=1
logips=1
port=${PORT}
onlynet=ipv4
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
    NUM=$1
    CFG=${HOME}/.${BASENAME}${NUM}/${CONFIGFILE}

    echo "Starting node $NUM..."
    /usr/local/bin/$SERVER -conf=${CFG}
}

stopNode()
{
    NUM=$1
    CFG=${HOME}/.${BASENAME}${NUM}/${CONFIGFILE}
    PID=${HOME}/.${BASENAME}${NUM}/${PIDFILE}

    echo "Stopping node..."
    /usr/local/bin/${CLIENT} -conf=${CFG} stop
    while [ -f ${PID} ]; do
        sleep 2s
    done
}

# ------------------------------------------------------------------------------------------------

echo ">>>>>> Starting the 1st node to generate the masternode keys..."

configureNode '01' 0 0 ''
startNode '01'

CFG=${HOME}/.${BASENAME}01/${CONFIGFILE}

echo "Waiting 5 seconds..."
sleep 5s

echo "Generating keys..."
for i in $(seq -f '%02g'  1  $NUMMN); do
    p=`expr $i - 1`
    MNKEY[$p]=`/usr/local/bin/${CLIENT} -conf=${CFG} masternode genkey`
    echo "Key $i: ${MNKEY[$p]}"
done

stopNode '01'
sleep 2s

rm -rf ${HOME}/.${BASENAME}01

# ------------------------------------------------------------------------------------------------

for i in $(seq -f '%02g'  1  $NUMMN); do
    echo ">>>>>> Creating masterndoes $i..."
    p=`expr $i - 1`
    
    configureNode $i 1 1 ${MNKEY[$p]}
    startNode $i
    sleep 2s
done

# ------------------------------------------------------------------------------------------------

echo ">>>>>> Generating Alias..."

if [ -f ${HOME}/.bash_aliases ]; then
    grep -v $BASENAME ${HOME}/.bash_aliases >${HOME}/.bash_aliases
fi

for i in $(seq -f '%02g'  1  $NUMMN); do
    p=`expr $i - 1`
    CFG=${HOME}/.${BASENAME}${i}/${CONFIGFILE}
    echo "alias b${i}cli='/usr/local/bin/${CLIENT} -conf=${CFG}'" >>${HOME}/.bash_aliases
done

# ------------------------------------------------------------------------------------------------

echo ">>>>>> Generating Script..."

echo "#!/bin/bash" >$HOME/startNodes.sh
for i in $(seq -f '%02g'  1  $NUMMN); do
    CFG=${HOME}/.${BASENAME}${i}/${CONFIGFILE}
    PID=${HOME}/.${BASENAME}${i}/${PIDFILE}
    echo "if [ \$(ps -efH|grep $SERVER|grep \"\\.${BASENAME}${i}\"|wc -l) -eq 0 ]; then /usr/local/bin/$SERVER -conf=$CFG; fi" >>$HOME/startNodes.sh
done
chmod +x $HOME/startNodes.sh

echo "#!/bin/bash" >$HOME/stopNodes.sh
for i in $(seq -f '%02g'  1  $NUMMN); do
    CFG=${HOME}/.${BASENAME}${i}/${CONFIGFILE}
    PID=${HOME}/.${BASENAME}${i}/${PIDFILE}
    echo "if [ -f ${PID} ]; then /usr/local/bin/$CLIENT -conf=$CFG stop; fi" >>$HOME/stopNodes.sh
done
chmod +x $HOME/stopNodes.sh

echo "#!/bin/bash" >$HOME/allcli.sh
for i in $(seq -f '%02g'  1  $NUMMN); do
    CFG=${HOME}/.${BASENAME}${i}/${CONFIGFILE}
    echo "/usr/local/bin/$CLIENT -conf=$CFG \$@" >>$HOME/allcli.sh
done
chmod +x $HOME/allcli.sh

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
    MN=${FILE:$LN - 18:2}
    ADDR=$(grep "masternodeaddr\=" $FILE|awk -F '=' '{print $2}')
    MNKEY=$(grep "masternodeprivkey\=" $FILE|awk -F '=' '{print $2}')

    echo "MN${MN} ${ADDR} ${MNKEY} <tx> <id>"
done

NP=$(ps -efH|grep $SERVER|grep "\-conf\="|wc -l)

echo ""
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo ""
echo "$NP beetlecoin processes are running... to start/stop your nodes you can use the following commands:"
echo ""
echo "    ~/startNodes.sh"
echo "    ~/stopNodes.sh"
echo ""
echo "To run a cli command you must use the aliases command:"
echo ""
echo "    bXXcli command      where XX is the masternode number"
echo ""
echo "Examples:"
echo ""
echo "    b01cli getinfo      (run getinfo command on the node 01)"
echo "    b04cli stop         (run stop    command on the node 04)"
echo ""
echo "To run the same cli command on all the masternodes you can use the following command:"
echo ""
echo "    ~/allcli.sh command"
echo ""
echo "Examples:"
echo ""
echo "    ~/allcli.sh getblockcount"
echo "    ~/allcli.sh stop"
echo ""
echo "Now you can logoff & logon again to this vps to activate the 'aliases' commands mentioned above,"
echo "or you can execute this command to activate on-the-fly:"
echo ""
echo "    source $HOME/.bashrc"

popd 1>/dev/null 2>&1

rm -rf $TMPDIR
