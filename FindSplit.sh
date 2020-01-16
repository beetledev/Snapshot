#!/bin/bash
#!/bin/bash

min() {
    printf "%s\n" "${@:2}" | sort "$1" | head -n1
}

CLIOK="/usr/local/bin/beetlecoin-cli -conf=${HOME}/.beetlecoin${1}/beetlecoin.conf"
CLIOK_GETBLOCKHASH="${CLIOK} getblockhash"
CLIOK_GETBLOCKCOUNT="${CLIOK} getblockcount"

CLIKO="/usr/local/bin/beetlecoin-cli -conf=${HOME}/.beetlecoin${2}/beetlecoin.conf"
CLIKO_GETBLOCKHASH="${CLIKO} getblockhash"
CLIKO_GETBLOCKCOUNT="${CLIKO} getblockcount"

CLIOK_COUNT=$( $CLIOK_GETBLOCKCOUNT )
CLIKO_COUNT=$( $CLIKO_GETBLOCKCOUNT )

START_BLOCK=$( min -g $CLIOK_COUNT $CLIKO_COUNT )
BLOCK=$START_BLOCK
END_BLOCK=1

#echo "CLIOK Count = ${CLIOK_COUNT}"
#echo "CLIKO Count = ${CLIKO_COUNT}"
#echo "Start Block = ${START_BLOCK}"
#echo ""

SPLITTED=0

while [ $BLOCK -gt $END_BLOCK ]
do
        CLIOK_HASH=$( ${CLIOK_GETBLOCKHASH} ${BLOCK} )
        CLIKO_HASH=$( ${CLIKO_GETBLOCKHASH} ${BLOCK} )

        echo "#${BLOCK} ${CLIOK_HASH} ${CLIKO_HASH}"

        if [ $CLIOK_HASH == $CLIKO_HASH ]
        then
                break
        fi

        SPLITTED=1

        ((BLOCK--))
done

echo ""

if [ $SPLITTED == 1 ]
then
        BAD_BLOCK=$(($BLOCK + 1))
        BAD_HASH=$( ${CLIKO_GETBLOCKHASH} ${BAD_BLOCK} )

        echo "SPLIT CHAIN FOUND AT BLOCK # ${BAD_BLOCK} = ${BAD_HASH}"
        exit 1
else
        echo "No split chain found"
        exit 0
fi

