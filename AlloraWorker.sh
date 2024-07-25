#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Install Packages
sudo apt update

sudo apt install -y ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev curl git wget make jq build-essential pkg-config lsb-release libssl-dev libreadline-dev libffi-dev gcc screen unzip lz4

# Install Python3
sudo apt install -y python3
python3 --version

sudo apt install -y python3-pip
pip3 --version

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
docker version

# Install Docker-Compose
VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)

curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

# Docker Permission to user
sudo groupadd docker
sudo usermod -aG docker $USER

# Install Go
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> $HOME/.bash_profile
source $HOME/.bash_profile
go version

# Install Allora Wallet
git clone https://github.com/allora-network/allora-chain.git

cd allora-chain && make all

allorad version

# Prompt user for wallet creation or recovery
echo -e "${BLUE}Do you want to create a new wallet or recover an existing wallet with a seed phrase?${NC}"
select choice in "Create a new wallet" "Recover existing wallet"; do
    case $choice in
        "Create a new wallet" )
            allorad keys add testkey --keyring-backend file
            break
            ;;
        "Recover existing wallet" )
            allorad keys add testkey --recover --keyring-backend file
            break
            ;;
        * )
            echo -e "${RED}Invalid choice. Please select 1 or 2.${NC}"
            ;;
    esac
done

echo -e "${RED}Copy this seed phrase in a safe place, you will need it later.${NC}"

# Prompt user to connect to Allora faucet to get uAllo
read -p "Now connect to Allora faucet to get uAllo, then press Enter when it's done: "

# Install basic-coin-prediction-node
cd $HOME && git clone https://github.com/allora-network/basic-coin-prediction-node

cd basic-coin-prediction-node

mkdir worker-data
mkdir head-data

# Give certain permissions
sudo chmod -R 777 worker-data
sudo chmod -R 777 head-data

# Create head keys
sudo docker run -d --entrypoint=bash -v $PWD/head-data:/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"

# Create worker keys
sudo docker run -d --entrypoint=bash -v $PWD/worker-data:/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"

# Wait for Docker commands to complete
sleep 5

# Get the value from head-data/keys/identity
HEAD_ID=$(cat head-data/keys/identity)
if [ -z "$HEAD_ID" ]; then
    echo -e "${RED}Error: head-data/keys/identity is empty.${NC}"
    exit 1
fi

# Prompt for seed phrase until non-empty
while true; do
    read -p "Please enter the seed phrase/bip39 mnemonic from your generated wallet: " SEED_PHRASE
    if [ -n "$SEED_PHRASE" ]; then
        break
    else
        echo -e "${RED}Seed phrase cannot be empty. Please try again.${NC}"
    fi
done

# Download docker-compose.yml
curl -o docker-compose.yml https://raw.githubusercontent.com/S4SPIDEY/AlloraNode/main/docker-compose.yml

# Replace placeholders in docker-compose.yml
sed -i "s/%head_id%/$HEAD_ID/g" docker-compose.yml
sed -i "s/%seed%/$SEED_PHRASE/g" docker-compose.yml

echo -e "${GREEN}Configuration complete. Allora Chain and Basic Coin Prediction Worker are ready.${NC}"

echo -e "${GREEN}You can now run:${NC}"
echo -e "cd basic-coin-prediction-node && docker-compose build && docker-compose up"
