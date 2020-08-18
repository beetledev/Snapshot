#!/bin/sh

ls /root/.beet*/debug.log|sort >/etc/logrotate.d/beetlecoin

cat <<EOF >>/etc/logrotate.d/beetlecoin
{
        rotate 5
        copytruncate
        daily
        missingok
        notifempty
        compress
        sharedscripts
}
EOF
