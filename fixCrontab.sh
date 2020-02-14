#!/bin/bash
#!/bin/bash

# Check if I am root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root." 1>&2
    exit 1
fi

TMPDIR="${HOME}/beettmp"
mkdir -p $TMPDIR

if [ `/usr/bin/crontab -l |grep -v "startNode\.sh"|wc -l` -gt 1 ]; then
    /usr/bin/crontab -l |grep -v "startNode\.sh" >$TMPDIR/crontab.last
    echo "*/5 * * * * ${HOME}/startNodes.sh 1>/dev/null 2>&1" >>$TMPDIR/crontab.last
    crontab $TMPDIR/crontab.last
fi

rm -rf $TMPDIR
