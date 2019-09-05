#!/bin/bash

echo "# you can use this masternode.conf configuration in you control wallet to start the masternodes, please change 'tx' & 'idx' with your collateral tx info"
echo ""

ls ~/.beetlecoin*/beetlecoin.conf | sort | while read FILE; do
    LN=${#FILE}
    MN=${FILE:$LN - 18:2}
    ADDR=$(grep "masternodeaddr\=" $FILE|awk -F '=' '{print $2}')
    MNKEY=$(grep "masternodeprivkey\=" $FILE|awk -F '=' '{print $2}')

    echo "MN${MN} ${ADDR} ${MNKEY} <tx> <id>"
done

