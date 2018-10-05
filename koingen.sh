#!/bin/bash -e
# This script is an experiment to clone litecoin into a 
# brand new coin + blockchain.
# The script will perform the following steps:
# 1) create first a docker image with ubuntu ready to build and run the new coin daemon
# 2) clone GenesisH0 and mine the genesis blocks of main, test and regtest networks in the container (this may take a lot of time)
# 3) clone litecoin
# 4) replace variables (keys, merkle tree hashes, timestamps..)
# 5) build new coin
# 6) run 4 docker nodes and connect to each other
# 
# By default the script uses the regtest network, which can mine blocks
# instantly. If you wish to switch to the main network, simply change the 
# CHAIN variable below
# In line 266,267 are the logo folders of the coin you want to create
# just download it first, change the logo's and put the icons and pixmaps folders in the
# folder where the script is going to run!

# change the following variables to match your new coin
COIN_NAME="Zenbitex"
COIN_UNIT="ZBX"
# Name of the new coin github page or location
NEW_COIN_GIT="zenbitex"
NEW_COIN_WEBSITE="zenbitex.com"
# 42 million coins at total (litecoin total supply is 84000000)
TOTAL_SUPPLY=20000000
MAINNET_PORT="66569"
TESTNET_PORT="66568"
REGTEST_PORT="66567"
PHRASE="Dutch anti-Islam lawmaker cancels Prophet Muhammad cartoon contest"
# First letter of the wallet address. Check https://en.bitcoin.it/wiki/Base58Check_encoding
PUBKEY_CHAR="80"
# number of blocks to wait to be able to spend coinbase UTXO's
COINBASE_MATURITY=4
# leave CHAIN empty for main network, -regtest for regression network and -testnet for test network
CHAIN=""
# this is the amount of coins to get as a reward of mining the block of height 1. if not set this will default to 50
PREMINED_AMOUNT=500000
BLOCK_REWARD=100

# Change the Subsidy block halving intervan in blocks
SUBSIDY_HALVING_BLOCK_INTERVAL="200000"
# Change Proof of work target time span (time that diff wil change)
# Where TARGET_TIME_SPAN is in days!
TARGET_TIME_SPAN="1"
# Change how fast blocks are found in minutes ( x * 60 secs)
TARGET_BLOCK_SPACING="1"

# Change the pchMessageStart[x] HEX Main net from original to
#        pchMessageStart[0] = 0xfb;
#        pchMessageStart[1] = 0xc0;
#        pchMessageStart[2] = 0xb6;
#        pchMessageStart[3] = 0xdb;

MESS_START_0_MAIN="0xfe"	 
MESS_START_1_MAIN="0xa2"	 
MESS_START_2_MAIN="0xde"	 
MESS_START_3_MAIN="0xcd"	 
# Change the pchMessageStart[x] HEX Test net from original to
#        pchMessageStart[0] = 0xfd;
#        pchMessageStart[1] = 0xd2;
#        pchMessageStart[2] = 0xc8;
#        pchMessageStart[3] = 0xf1;
MESS_START_0_TEST="0xd2"
MESS_START_1_TEST="0xf4"	 
MESS_START_2_TEST="0xaa"	 
MESS_START_3_TEST="0xa0"
# Change the pchMessageStart[x] HEX Test net from original to
#        pchMessageStart[0] = 0xfa;
#        pchMessageStart[1] = 0xbf;
#        pchMessageStart[2] = 0xb5;
#        pchMessageStart[3] = 0xda;

MESS_START_0_REG_TEST="0xd5"	 
MESS_START_1_REG_TEST="0xb7"	 
MESS_START_2_REG_TEST="0x3a"	 
MESS_START_3_REG_TEST="0x4e"

# Your nodes for the chainparamsseeds.h file

# mainnet nodes
ADDM1="192.168.8.101"
ADDM2="109.88.53.67"
ADDM3=""
# Testnet nodes
ADDT1=""
ADDT2=""
ADDT3=""





# warning: change this to your own pubkey to get the genesis block mining reward
GENESIS_REWARD_PUBKEY=044e0d4bc823e20e14d66396a64960c993585400c53f1e6decb273f249bfeba0e71f140ffa7316f2cdaaae574e7d72620538c3e7791ae9861dfe84dd2955fc85e8

# dont change the following variables unless you know what you are doing
LITECOIN_BRANCH=0.16
GENESISHZERO_REPOS=https://github.com/lhartikk/GenesisH0
LITECOIN_REPOS=https://github.com/litecoin-project/litecoin.git
LITECOIN_PUB_KEY=040184710fa689ad5023690c80f3a49c8f13f8d45b8c857fbcbc8bc4a8e4d3eb4b10f4d4604fa08dce601aaf0f470216fe1b51850b4acf21b179c45070ac7b03a9
LITECOIN_MERKLE_HASH=97ddfbbae6be97fd6cdf3e7ca13232a3afff2353e29badfab7f73011edd4ced9
LITECOIN_MAIN_GENESIS_HASH=12a765e31ffd4059bada1e25190f6e98c99d9714d334efa41a195a7e7e04bfe2
LITECOIN_TEST_GENESIS_HASH=4966625a4b2851d9fdee139e56211a0d88575f59ed816ff5e6a63deb4e3e29a0
LITECOIN_REGTEST_GENESIS_HASH=530827f38f93b43ed12af0b3ad25a288dc02ed74d6d7857862df51fc56c416f9
MINIMUM_CHAIN_WORK_MAIN=0x000000000000000000000000000000000000000000000006805c7318ce2736c0
MINIMUM_CHAIN_WORK_TEST=0x000000000000000000000000000000000000000000000000000000054cb9e7a0
COIN_NAME_LOWER=$(echo $COIN_NAME | tr '[:upper:]' '[:lower:]')
COIN_NAME_UPPER=$(echo $COIN_NAME | tr '[:lower:]' '[:upper:]')
DIRNAME=$(dirname $0)
DOCKER_NETWORK="172.18.0"
DOCKER_IMAGE_LABEL="newcoin-env"
OSVERSION="$(uname -s)"

docker_build_image()
{
    IMAGE=$(docker images -q $DOCKER_IMAGE_LABEL)
    if [ -z $IMAGE ]; then
        echo Building docker image
        if [ ! -f $DOCKER_IMAGE_LABEL/Dockerfile ]; then
            mkdir -p $DOCKER_IMAGE_LABEL
            cat <<EOF > $DOCKER_IMAGE_LABEL/Dockerfile
FROM ubuntu:18.04
RUN echo deb http://ppa.launchpad.net/bitcoin/bitcoin/ubuntu bionic main >> /etc/apt/sources.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv D46F45428842CE5E
RUN apt-get update
RUN apt-get -y install ccache git libboost-system1.58.0 libboost-filesystem1.58.0 libboost-program-options1.58.0 libboost-thread1.58.0 libboost-chrono1.58.0 libssl1.0.0 libevent-pthreads-2.0-5 libevent-2.0-5 build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libzmq3-dev libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler libqrencode-dev python-pip
RUN pip install construct==2.5.2 scrypt
EOF
        fi 
        docker build --label $DOCKER_IMAGE_LABEL --tag $DOCKER_IMAGE_LABEL $DIRNAME/$DOCKER_IMAGE_LABEL/
    else
        echo Docker image already built
    fi
}

docker_run_genesis()
{
    mkdir -p $DIRNAME/.ccache
    docker run -v $DIRNAME/GenesisH0:/GenesisH0 $DOCKER_IMAGE_LABEL /bin/bash -c "$1"
}

docker_run()
{
    mkdir -p $DIRNAME/.ccache
    docker run -v $DIRNAME/GenesisH0:/GenesisH0 -v $DIRNAME/.ccache:/root/.ccache -v $DIRNAME/$COIN_NAME_LOWER:/$COIN_NAME_LOWER $DOCKER_IMAGE_LABEL /bin/bash -c "$1"
}

docker_stop_nodes()
{
    echo "Stopping all docker nodes"
    for id in $(docker ps -q -a  -f ancestor=$DOCKER_IMAGE_LABEL); do
        docker stop $id
    done
}

docker_remove_nodes()
{
    echo "Removing all docker nodes"
    for id in $(docker ps -q -a  -f ancestor=$DOCKER_IMAGE_LABEL); do
        docker rm $id
    done
}

docker_create_network()
{
    echo "Creating docker network"
    if ! docker network inspect newcoin &>/dev/null; then
        docker network create --subnet=$DOCKER_NETWORK.0/16 newcoin
    fi
}

docker_remove_network()
{
    echo "Removing docker network"
    docker network rm newcoin
}

docker_run_node()
{
    local NODE_NUMBER=$1
    local NODE_COMMAND=$2
    mkdir -p $DIRNAME/miner${NODE_NUMBER}
    if [ ! -f $DIRNAME/miner${NODE_NUMBER}/$COIN_NAME_LOWER.conf ]; then
        cat <<EOF > $DIRNAME/miner${NODE_NUMBER}/$COIN_NAME_LOWER.conf
rpcuser=${COIN_NAME_LOWER}rpc
rpcpassword=$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 32; echo)
EOF
    fi

    docker run --net newcoin --ip $DOCKER_NETWORK.${NODE_NUMBER} -v $DIRNAME/miner${NODE_NUMBER}:/root/.$COIN_NAME_LOWER -v $DIRNAME/$COIN_NAME_LOWER:/$COIN_NAME_LOWER $DOCKER_IMAGE_LABEL /bin/bash -c "$NODE_COMMAND"
}

generate_genesis_block()
{
    if [ ! -d GenesisH0 ]; then
        git clone $GENESISHZERO_REPOS
        pushd GenesisH0
    else
        pushd GenesisH0
        git pull
    fi

    if [ ! -f ${COIN_NAME}-main.txt ]; then
        echo "Mining genesis block... this procedure can take many hours of cpu work.."
        docker_run_genesis "python /GenesisH0/genesis.py -a X15 -z \"$PHRASE\" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee /GenesisH0/${COIN_NAME}-main.txt"
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-main.txt
    fi

    if [ ! -f ${COIN_NAME}-test.txt ]; then
        echo "Mining genesis block of test network... this procedure can take many hours of cpu work.."
        docker_run_genesis "python /GenesisH0/genesis.py  -t 1486949366 -a X15 -z \"$PHRASE\" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee /GenesisH0/${COIN_NAME}-test.txt"
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-test.txt
    fi

    if [ ! -f ${COIN_NAME}-regtest.txt ]; then
        echo "Mining genesis block of regtest network... this procedure can take many hours of cpu work.."
        docker_run_genesis "python /GenesisH0/genesis.py -t 1296688602 -b 0x207fffff -n 0 -a scrypt -z \"$PHRASE\" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee /GenesisH0/${COIN_NAME}-regtest.txt"
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-regtest.txt
    fi

    MAIN_PUB_KEY=$(cat ${COIN_NAME}-main.txt | grep "^pubkey:" | $SED 's/^pubkey: //')
    MERKLE_HASH=$(cat ${COIN_NAME}-main.txt | grep "^merkle hash:" | $SED 's/^merkle hash: //')
    TIMESTAMP=$(cat ${COIN_NAME}-main.txt | grep "^time:" | $SED 's/^time: //')
    BITS=$(cat ${COIN_NAME}-main.txt | grep "^bits:" | $SED 's/^bits: //')

    MAIN_NONCE=$(cat ${COIN_NAME}-main.txt | grep "^nonce:" | $SED 's/^nonce: //')
    TEST_NONCE=$(cat ${COIN_NAME}-test.txt | grep "^nonce:" | $SED 's/^nonce: //')
    REGTEST_NONCE=$(cat ${COIN_NAME}-regtest.txt | grep "^nonce:" | $SED 's/^nonce: //')

    MAIN_GENESIS_HASH=$(cat ${COIN_NAME}-main.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')
    TEST_GENESIS_HASH=$(cat ${COIN_NAME}-test.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')
    REGTEST_GENESIS_HASH=$(cat ${COIN_NAME}-regtest.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')

    popd
}

newcoin_replace_vars()
{
    if [ -d $COIN_NAME_LOWER ]; then
        echo "Warning: $COIN_NAME_LOWER already existing. Not replacing any values"
        return 0
    fi
    if [ ! -d "litecoin-master" ]; then
        # clone litecoin and keep local cache
        git clone -b $LITECOIN_BRANCH $LITECOIN_REPOS litecoin-master
    else
        echo "Updating master branch"
        pushd litecoin-master
        git pull
        popd
    fi

    git clone -b $LITECOIN_BRANCH litecoin-master $COIN_NAME_LOWER

    pushd $COIN_NAME_LOWER

    # first rename all directories
    for i in $(find . -type d | grep -v "^./.git" | grep litecoin); do 
        git mv $i $(echo $i| $SED "s/litecoin/$COIN_NAME_LOWER/")
    done

mv $(pwd)pixmaps $COIN_NAME_LOWER/share
mv $(pwd)icons $COIN_NAME_LOWER/src/qt/res

    # then rename all files
    for i in $(find . -type f | grep -v "^./.git" | grep litecoin); do
        git mv $i $(echo $i| $SED "s/litecoin/$COIN_NAME_LOWER/")
    done
   
    # now replace all litecoin references to the new coin name
    for i in $(find . -type f | grep -v "^./.git"); do
        $SED -i "s/Litecoin/$COIN_NAME/g" $i
        $SED -i "s/litecoin/$COIN_NAME_LOWER/g" $i
        $SED -i "s/LITECOIN/$COIN_NAME_UPPER/g" $i
        $SED -i "s/LTC/$COIN_UNIT/g" $i
	$SED -i "s/ltc/$COIN_UNIT/g" $i
	$SED -i "s/$COIN_NAME_LOWER-project/$NEW_COIN_GIT/g" $i
	$SED -i "s/$COIN_NAME_LOWER.org/$NEW_COIN_WEBSITE/g" $i
sg

    done

    $SED -i "s/84000000/$TOTAL_SUPPLY/" src/amount.h
    $SED -i "s/1,48/1,$PUBKEY_CHAR/" src/chainparams.cpp

    $SED -i "s/1317972665/$TIMESTAMP/" src/chainparams.cpp

    $SED -i "s;NY Times 05/Oct/2011 Steve Jobs, Apple’s Visionary, Dies at 56;$PHRASE;" src/chainparams.cpp

    $SED -i "s/= 9333;/= $MAINNET_PORT;/" src/chainparams.cpp
    $SED -i "s/= 19335;/= $TESTNET_PORT;/" src/chainparams.cpp
    $SED -i "s/= 19444;/= $REGTEST_PORT;/" src/chainparams.cpp	 
# Change the pchMessageStart[x] HEX Main net
    $SED -i "s/= 0xfd/= $MESS_START_0_MAIN/" src/chainparams.cpp	 
    $SED -i "s/= 0xc0/= $MESS_START_1_MAIN/" src/chainparams.cpp	 
    $SED -i "s/= 0xb6/= $MESS_START_2_MAIN/" src/chainparams.cpp	 
    $SED -i "s/= 0xdb/= $MESS_START_3_MAIN/" src/chainparams.cpp	 
# Change the pchMessageStart[x] HEX Test net
    $SED -i "s/= 0xfd/= $MESS_START_0_TEST/" src/chainparams.cpp	 
    $SED -i "s/= 0xd2/= $MESS_START_1_TEST/" src/chainparams.cpp	 
    $SED -i "s/= 0xc8/= $MESS_START_2_TEST/" src/chainparams.cpp	 
    $SED -i "s/= 0xf1/= $MESS_START_3_TEST/" src/chainparams.cpp
# Change the pchMessageStart[x] HEX Test net
    $SED -i "s/= 0xfa/= $MESS_START_0_REG_TEST/" src/chainparams.cpp	 
    $SED -i "s/= 0xbf/= $MESS_START_1_REG_TEST/" src/chainparams.cpp	 
    $SED -i "s/= 0xb5/= $MESS_START_2_REG_TEST/" src/chainparams.cpp	 
    $SED -i "s/= 0xda/= $MESS_START_3_REG_TEST/" src/chainparams.cpp
# Change Proof of work target time span (time that diff wil change)
# Where TARGET_TIME_SPAN is in days!
    $SED -i "s/nPowTargetTimespan = 3.5 */nPowTargetTimespan = $TARGET_TIME_SPAN */" src/chainparams.cpp

# Change how fast blocks are to be found in minutes
    $SED -i "s/nPowTargetSpacing = 2.5 */nPowTargetSpacing = $TARGET_BLOCK_SPACING */" src/chainparams.cpp

# Change Subsidy interval block count
    $SED -i "s/= 840000/= $SUBSIDY_HALVING_BLOCK_INTERVAL/" src/chainparams.cpp

# Change hashes
    $SED -i "s/$LITECOIN_PUB_KEY/$MAIN_PUB_KEY/" src/chainparams.cpp
    $SED -i "s/$LITECOIN_MERKLE_HASH/$MERKLE_HASH/" src/chainparams.cpp
    $SED -i "s/$LITECOIN_MERKLE_HASH/$MERKLE_HASH/" src/qt/test/rpcnestedtests.cpp

    $SED -i "0,/$LITECOIN_MAIN_GENESIS_HASH/s//$MAIN_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "0,/$LITECOIN_TEST_GENESIS_HASH/s//$TEST_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "0,/$LITECOIN_REGTEST_GENESIS_HASH/s//$REGTEST_GENESIS_HASH/" src/chainparams.cpp

    $SED -i "0,/2084524493/s//$MAIN_NONCE/" src/chainparams.cpp
    $SED -i "0,/293345/s//$TEST_NONCE/" src/chainparams.cpp
    $SED -i "0,/1296688602, 0/s//1296688602, $REGTEST_NONCE/" src/chainparams.cpp
    $SED -i "0,/0x1e0ffff0/s//$BITS/" src/chainparams.cpp

    $SED -i "s,vSeeds.push_back,//vSeeds.push_back,g" src/chainparams.cpp

    if [ -n "$PREMINED_AMOUNT" ]; then
        $SED -i "s/CAmount nSubsidy = 50 \* COIN;/if \(nHeight == 1\) return COIN \* $PREMINED_AMOUNT;\n    CAmount nSubsidy = 50 \* COIN;/" src/validation.cpp
    fi

    $SED -i "s/COINBASE_MATURITY = 100/COINBASE_MATURITY = $COINBASE_MATURITY/" src/consensus/consensus.h
    $SED -i "s/CAmount nSubsidy = 50 \* COIN/CAmount nSubsidy = $BLOCK_REWARD \* COIN/" src/validation.cpp
    # reset minimum chain work to 0
    $SED -i "s/$MINIMUM_CHAIN_WORK_MAIN/0x00/" src/chainparams.cpp
    $SED -i "s/$MINIMUM_CHAIN_WORK_TEST/0x00/" src/chainparams.cpp

    # change bip activation heights
    # bip 16
    $SED -i "s/218579/0/" src/chainparams.cpp
    # bip 34
    $SED -i "s/710000/0/" src/chainparams.cpp
    # bip 65
    $SED -i "s/918684/0/" src/chainparams.cpp
    # bip 66
    $SED -i "s/811879/0/" src/chainparams.cpp

# Create a chainparasseeds.h file for the nodes
# 
# generate.py is located in coin main dir/contrib/seeds
# move chainparamsseeds.h coinmaindir/src

rm $(pwd)/contrib/seeds/nodes_*

echo "$ADDM1" >> $(pwd)/contrib/seeds/nodes_main.txt
echo "$ADDM2" >> $(pwd)/contrib/seeds/nodes_main.txt
echo "$ADDM3" >> $(pwd)/contrib/seeds/nodes_main.txt

echo "$ADDT1" >> $(pwd)/contrib/seeds/nodes_test.txt
echo "$ADDT2" >> $(pwd)/contrib/seeds/nodes_test.txt
echo "$ADDT3" >> $(pwd)/contrib/seeds/nodes_test.txt

$(pwd)/contrib/seeds/generate-seeds.py $(pwd)/contrib/seeds/ > chainseeds.log
mv $(pwd)/chainseeds.log $(pwd)/src/chainparamsseeds.h


    # TODO: fix checkpoints MAIN
    $SED -i "s/0x841a2965955dd288cfa707a755d05a54e45f8bd476835ec9af4402a2b59a2967/$MAIN_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "s/1500,/0/" src/chainparams.cpp
    
$SED -i "s/                {  4032, uint256S("0x9ce90e427198fc0ef05e5905ce3503725b80e26afd35a987965fd7e3d9cf0846")},////" src/chainparams.cpp
$SED -i "s/                {  8064, uint256S("0xeb984353fc5190f210651f150c40b8a4bab9eeeff0b729fcb3987da694430d70")},////" src/chainparams.cpp
$SED -i "s/                { 16128, uint256S("0x602edf1859b7f9a6af809f1d9b0e6cb66fdc1d4d9dcd7a4bec03e12a1ccd153d")},////" src/chainparams.cpp
$SED -i "s/                { 23420, uint256S("0xd80fdf9ca81afd0bd2b2a90ac3a9fe547da58f2530ec874e978fce0b5101b507")},////" src/chainparams.cpp
$SED -i "s/                { 50000, uint256S("0x69dc37eb029b68f075a5012dcc0419c127672adb4f3a32882b2b3e71d07a20a6")},////" src/chainparams.cpp
$SED -i "s/                { 80000, uint256S("0x4fcb7c02f676a300503f49c764a89955a8f920b46a8cbecb4867182ecdb2e90a")},////" src/chainparams.cpp
$SED -i "s/                {120000, uint256S("0xbd9d26924f05f6daa7f0155f32828ec89e8e29cee9e7121b026a7a3552ac6131")},////" src/chainparams.cpp
$SED -i "s/                {161500, uint256S("0xdbe89880474f4bb4f75c227c77ba1cdc024991123b28b8418dbbf7798471ff43")},////" src/chainparams.cpp
$SED -i "s/                {179620, uint256S("0x2ad9c65c990ac00426d18e446e0fd7be2ffa69e9a7dcb28358a50b2b78b9f709")},////" src/chainparams.cpp
$SED -i "s/                {240000, uint256S("0x7140d1c4b4c2157ca217ee7636f24c9c73db39c4590c4e6eab2e3ea1555088aa")},////" src/chainparams.cpp
$SED -i "s/                {383640, uint256S("0x2b6809f094a9215bafc65eb3f110a35127a34be94b7d0590a096c3f126c6f364")},////" src/chainparams.cpp
$SED -i "s/                {409004, uint256S("0x487518d663d9f1fa08611d9395ad74d982b667fbdc0e77e9cf39b4f1355908a3")},////" src/chainparams.cpp
$SED -i "s/                {456000, uint256S("0xbf34f71cc6366cd487930d06be22f897e34ca6a40501ac7d401be32456372004")},////" src/chainparams.cpp
$SED -i "s/                {638902, uint256S("0x15238656e8ec63d28de29a8c75fcf3a5819afc953dcd9cc45cecc53baec74f38")},////" src/chainparams.cpp
$SED -i "s/                {721000, uint256S("0x198a7b4de1df9478e2463bd99d75b714eab235a2e63e741641dc8a759a9840e5")},////" src/chainparams.cpp

    $SED -i "s/1516406833,/$MAIN_NONCE/" src/chainparams.cpp
    $SED -i "s/19831879/0/" src/chainparams.cpp

# Checkpoint TESTNET 
$SED -i "s/2056,/0/" src/chainparams.cpp
$SED -i "s/17748a31ba97afdc9a4f86837a39d287e3e7c7290a08a1d816c5969c78a83289/$TEST_GENESIS_HASH/" src/chainparams.cpp
$SED -i "s/1516406749/$TEST_NONCE/" src/chainparams.cpp
$SED -i "s/794057/0/" src/chainparams.cpp

     popd
}

build_new_coin()
{
    # only run autogen.sh/configure if not done previously
    if [ ! -e $COIN_NAME_LOWER/Makefile ]; then
        docker_run "cd /$COIN_NAME_LOWER ; bash  /$COIN_NAME_LOWER/autogen.sh"
        docker_run "cd /$COIN_NAME_LOWER ; bash  /$COIN_NAME_LOWER/configure"
    fi
    # always build as the user could have manually changed some files
    docker_run "cd /$COIN_NAME_LOWER ; make -j2"
}


if [ $DIRNAME =  "." ]; then
    DIRNAME=$PWD
fi

cd $DIRNAME

# sanity check

case $OSVERSION in
    Linux*)
        SED=sed
    ;;
    Darwin*)
        SED=$(which gsed 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "please install gnu-sed with 'brew install gnu-sed'"
            exit 1
        fi
        SED=gsed
    ;;
    *)
        echo "This script only works on Linux and MacOS"
        exit 1
    ;;
esac


if ! which docker &>/dev/null; then
    echo Please install docker first
    exit 1
fi

if ! which git &>/dev/null; then
    echo Please install git first
    exit 1
fi

case $1 in
    stop)
        docker_stop_nodes
    ;;
    remove_nodes)
        docker_stop_nodes
        docker_remove_nodes
    ;;
    clean_up)
        docker_stop_nodes
        for i in $(seq 2 5); do
           docker_run_node $i "rm -rf /$COIN_NAME_LOWER /root/.$COIN_NAME_LOWER" &>/dev/null
        done
        docker_remove_nodes
        docker_remove_network
        rm -rf $COIN_NAME_LOWER
        if [ "$2" != "keep_genesis_block" ]; then
            rm -f GenesisH0/${COIN_NAME}-*.txt
        fi
        for i in $(seq 2 5); do
           rm -rf miner$i
        done
    ;;
    start)
        if [ -n "$(docker ps -q -f ancestor=$DOCKER_IMAGE_LABEL)" ]; then
            echo "There are nodes running. Please stop them first with: $0 stop"
            exit 1
        fi
        docker_build_image
        generate_genesis_block
        newcoin_replace_vars
        build_new_coin
        docker_create_network

        docker_run_node 2 "cd /$COIN_NAME_LOWER ; ./src/${COIN_NAME_LOWER}d $CHAIN -listen -noconnect -bind=$DOCKER_NETWORK.2 -addnode=$DOCKER_NETWORK.1 -addnode=$DOCKER_NETWORK.3 -addnode=$DOCKER_NETWORK.4 -addnode=$DOCKER_NETWORK.5" &
        docker_run_node 3 "cd /$COIN_NAME_LOWER ; ./src/${COIN_NAME_LOWER}d $CHAIN -listen -noconnect -bind=$DOCKER_NETWORK.3 -addnode=$DOCKER_NETWORK.1 -addnode=$DOCKER_NETWORK.2 -addnode=$DOCKER_NETWORK.4 -addnode=$DOCKER_NETWORK.5" &
        docker_run_node 4 "cd /$COIN_NAME_LOWER ; ./src/${COIN_NAME_LOWER}d $CHAIN -listen -noconnect -bind=$DOCKER_NETWORK.4 -addnode=$DOCKER_NETWORK.1 -addnode=$DOCKER_NETWORK.2 -addnode=$DOCKER_NETWORK.3 -addnode=$DOCKER_NETWORK.5" &
        docker_run_node 5 "cd /$COIN_NAME_LOWER ; ./src/${COIN_NAME_LOWER}d $CHAIN -listen -noconnect -bind=$DOCKER_NETWORK.5 -addnode=$DOCKER_NETWORK.1 -addnode=$DOCKER_NETWORK.2 -addnode=$DOCKER_NETWORK.3 -addnode=$DOCKER_NETWORK.4" &

        echo "Docker containers should be up and running now. You may run the following command to check the network status:
for i in \$(docker ps -q); do docker exec \$i /$COIN_NAME_LOWER/src/${COIN_NAME_LOWER}-cli $CHAIN getinfo; done"
        echo "To ask the nodes to mine some blocks simply run:
for i in \$(docker ps -q); do docker exec \$i /$COIN_NAME_LOWER/src/${COIN_NAME_LOWER}-cli $CHAIN generate 2  & done"
        exit 1
    ;;
    *)
        cat <<EOF
Usage: $0 (start|stop|remove_nodes|clean_up)
 - start: bootstrap environment, build and run your new coin
 - stop: simply stop the containers without removing them
 - remove_nodes: remove the old docker container images. This will stop them first if necessary.
 - clean_up: WARNING: this will stop and remove docker containers and network, source code, genesis block information and nodes data directory. (to start from scratch)
EOF
    ;;
esac

