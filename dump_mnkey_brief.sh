#!/bin/bash
#!/bin/bash

ls ~/.beetlecoin??/beetlecoin.conf | sort | while read FILE; do
    LN=${#FILE}
    MN=${FILE:$LN - 18:2}
    ADDR=$(grep "masternodeaddr\=" $FILE|awk -F '=' '{print $2}')
    MNKEY=$(grep "masternodeprivkey\=" $FILE|awk -F '=' '{print $2}')

    echo "MN${MN} ${ADDR} ${MNKEY} <tx> <id>"
done

echo ""
