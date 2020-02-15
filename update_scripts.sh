#!/bin/bash
#!/bin/bash

# Check if I am root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root." 1>&2
    exit 1
fi

LASTRUN=`ls -a|grep "\.beetlecoin"|sort|tail -1`
NM=$(expr ${LASTRUN: -2} + 0)
NUMMN=`expr $NM + 0`
BASENAME="beetlecoin"
BASEPORT=42300
BASERPCPORT=43300
CONFIGFILE="${BASENAME}.conf"
PIDFILE="${BASENAME}d.pid"
CLIENT="${BASENAME}-cli"
SERVER="${BASENAME}d"
TX="${BASENAME}-tx"
TMPDIR="${HOME}/beettmp"

if ! [ -d ${HOME}/.${BASENAME}01 ]; then
    echo "Masternodes isn't installed." 1>&2
    exit 1
fi

echo ">>>>>> Disabling Crontab..."

rm -rf $TMPDIR
mkdir -p $TMPDIR/snap

/usr/bin/crontab -l |grep -v "startNodes\.sh" >$TMPDIR/crontab.last
crontab $TMPDIR/crontab.last

pushd $TMPDIR 1>/dev/null 2>&1

# ------------------------------------------------------------------------------------------------

echo ">>>>>> Regenerating Alias..."

if [ -f ${HOME}/.bash_aliases ]; then
    grep -v $BASENAME ${HOME}/.bash_aliases >$TMPDIR/.bash_aliases.tmp
    mv -f $TMPDIR/.bash_aliases.tmp ${HOME}/.bash_aliases
fi

sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' ${HOME}/.bashrc
sed -i 's/ls \-CF/ls \-alh/g' ${HOME}/.bashrc

for i in $(seq -f '%02g'  1  $NUMMN); do
    p=`expr $i - 1`
    CFG=${HOME}/.${BASENAME}${i}/${CONFIGFILE}
    echo "alias b${i}cli='/usr/local/bin/${CLIENT} -conf=${CFG}'" >>${HOME}/.bash_aliases
done

echo "alias p='ps -efH'" >>${HOME}/.bash_aliases

# ------------------------------------------------------------------------------------------------

echo ">>>>>> Regenerating Script..."

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
    echo "echo \"#${i}: \$(/usr/local/bin/$CLIENT -conf=$CFG \$@)\"" >>$HOME/allcli.sh
done
chmod +x $HOME/allcli.sh

echo ">>>>>> Regenerating crontab..."

/usr/bin/crontab -l |grep -v "startNodes\.sh" >$TMPDIR/crontab.last
echo "*/5 * * * * ${HOME}/startNodes.sh 1>/dev/null 2>&1" >>$TMPDIR/crontab.last
crontab $TMPDIR/crontab.last

# ------------------------------------------------------------------------------------------------

echo ">>>>>> Restarting nodes..."

$HOME/startNodes.sh

# ------------------------------------------------------------------------------------------------

clear

NP=$(ps -efH|grep $SERVER|grep "\-conf\="|wc -l)

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo ""
echo "$NP beetlecoin processes are updated & running... to start/stop your nodes you can use the following commands:"
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

popd 1>/dev/null 2>&1

rm -rf $TMPDIR
