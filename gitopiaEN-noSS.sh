#!/bin/bash
echo -e "\033[0;35m"
echo "  _     ___  ____ ____  _   _  ___  ____  _____ ";
echo " | |   / _ \/ ___/ ___|| \ | |/ _ \|  _ \| ____|";
echo " | |  | | | \___ \___ \|  \| | | | | | | |  _|  ";
echo " | |__| |_| |___) |__) | |\  | |_| | |_| | |___ ";
echo " |_____\___/|____/____/|_| \_|\___/|____/|_____|";
echo -e "\e[0m"

sleep 3

if [ ! $NODENAME ]; then
	read -p "Enter your moniker name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi

echo -e "\e[1m\e[32m1. Updating server.. \e[0m"
echo "======================================================"
sleep 1
sudo apt update && sudo apt upgrade -y

echo -e "\e[1m\e[32m2. Installing other necessary things.. \e[0m"
echo "======================================================"
sleep 1
sudo apt install curl build-essential git wget jq make gcc tmux chrony -y

echo "export GITOPIA_CHAIN_ID=gitopia-janus-testnet-2" >> $HOME/.bash_profile
echo "export GITOPIA_PORT=${GITOPIA_PORT}" >> $HOME/.bash_profile
source $HOME/.bash_profile


echo -e "\e[1m\e[32m2. Installing Go.. \e[0m"
echo "======================================================"
sleep 1

if ! [ -x "$(command -v go)" ]; then
  cd
  ver="1.18.3"
  wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
  rm "go$ver.linux-amd64.tar.gz"
  echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
  source $HOME/.bash_profile
fi

echo -e "\e[1m\e[32m3. Installing binaries.. \e[0m"
echo "======================================================"
sleep 1

cd $HOME 
rm -rf gitopia
curl https://get.gitopia.com | bash
git clone -b v1.2.0 gitopia://gitopia/gitopia
cd gitopia 
make install


gitopiad config chain-id $GITOPIA_CHAIN_ID
gitopiad config keyring-backend test
gitopiad config node tcp://localhost:${GITOPIA_PORT}657

gitopiad init $NODENAME --chain-id $GITOPIA_CHAIN_ID

echo -e "\e[1m\e[32m3. Downloading genesis file and addrbook, setting seed/peer.. \e[0m"
echo "======================================================"
sleep 1

wget -O $HOME/.gitopia/config/addrbook.json "http://65.108.6.45:8000/gitopia/addrbook.json"
wget https://server.gitopia.com/raw/gitopia/testnets/master/gitopia-janus-testnet-2/genesis.json.gz
gunzip genesis.json.gz
mv genesis.json $HOME/.gitopia/config/genesis.json

SEEDS="399d4e19186577b04c23296c4f7ecc53e61080cb@seed.gitopia.com:26656"
PEERS=""
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.gitopia/config/config.toml

sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:${GITOPIA_PORT}658\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:${GITOPIA_PORT}657\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:${GITOPIA_PORT}060\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${GITOPIA_PORT}656\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":${GITOPIA_PORT}660\"%" $HOME/.gitopia/config/config.toml
sed -i.bak -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:${GITOPIA_PORT}317\"%; s%^address = \":8080\"%address = \":${GITOPIA_PORT}080\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:${GITOPIA_PORT}090\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:${GITOPIA_PORT}091\"%; s%^address = \"0.0.0.0:8545\"%address = \"0.0.0.0:${GITOPIA_PORT}545\"%; s%^ws-address = \"0.0.0.0:8546\"%ws-address = \"0.0.0.0:${GITOPIA_PORT}546\"%" $HOME/.gitopia/config/app.toml


pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="50"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.gitopia/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.gitopia/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.gitopia/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.gitopia/config/app.toml

sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0utlore\"/" $HOME/.gitopia/config/app.toml

sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.gitopia/config/config.toml

gitopiad tendermint unsafe-reset-all --home $HOME/.gitopia

echo -e "\e[1m\e[32m4. Creating service file.. \e[0m"
echo "======================================================"
sleep 1

sudo tee /etc/systemd/system/gitopiad.service > /dev/null <<EOF
[Unit]
Description=gitopia
After=network-online.target
[Service]
User=$USER
ExecStart=$(which gitopiad) start --home $HOME/.gitopia
Restart=on-failure
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

echo -e "\e[1m\e[32m4. Starting service.. \e[0m"
echo "======================================================"
sleep 1

sudo systemctl daemon-reload
systemctl restart systemd-journald.service
sudo systemctl enable gitopiad
sudo systemctl restart gitopiad
source $HOME/.bash_profile
journalctl -u gitopiad -f -o cat
