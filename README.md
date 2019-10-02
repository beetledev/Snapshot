# Snapshot

## Multi Masternode Installation Script

To install multiple masternode on a Ubuntu 16.04 VPS run this command:

    bash <(curl -s https://raw.githubusercontent.com/beetledev/Snapshot/master/install_multi_beetlecoin.sh)

If you are in China please use this one:

    bash <(curl -s https://raw.githubusercontent.com/beetledev/Snapshot/master/install_multi_beetlecoin_china.sh)

If curl isn't installed run this command before:

    apt-get -y install curl

If you want to dump the masternode key after the install:

    bash <(curl -s https://raw.githubusercontent.com/beetledev/Snapshot/master/dump_mnkey.sh)

To update to the latest version:

    bash <(curl -s https://raw.githubusercontent.com/beetledev/Snapshot/master/update_multi_beetlecoin.sh)

For China community:

    bash <(curl -s https://raw.githubusercontent.com/beetledev/Snapshot/master/update_multi_beetlecoin_china.sh)
