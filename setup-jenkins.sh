#!/bin/bash

# --- Configuration ---
DOCKER_IMAGE="pjgooli/jenkins-devops:latest"
CONTAINER_NAME="jenkins-devops"
PORT=8080
VOLUME_NAME="jenkins_jenkins_home"

# --- Colors for output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting DevOps Workshop Jenkins Setup (Latest/LTS)...${NC}"

# 1. Check for Root/Sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root or with sudo.${NC}"
   exit 1
fi

# Check for --clean flag
CLEAN_START=false
if [[ "$1" == "--clean" ]]; then
    CLEAN_START=true
    echo -e "${RED}Clean start requested. Old Jenkins data will be wiped.${NC}"
fi

# 2. Update System
echo -e "${YELLOW}Updating package lists...${NC}"
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release software-properties-common lsof

# 3. Verify Git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Installing latest Git...${NC}"
    add-apt-repository -y ppa:git-core/ppa
    apt-get update -y
    apt-get install -y git
else
    echo -e "${GREEN}Git is already installed: $(git --version)${NC}"
fi

# 4. Verify Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing latest Docker Engine...${NC}"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl start docker
    systemctl enable docker
else
    echo -e "${GREEN}Docker is already installed: $(docker --version | head -n 1)${NC}"
fi

# Ensure current user can use docker (for after the script runs)
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker $SUDO_USER
fi

# 5. Verify Java (JDK 21)
if ! command -v java &> /dev/null; then
    echo -e "${YELLOW}Installing Java 21 (Latest LTS)...${NC}"
    apt-get install -y openjdk-21-jdk
else
    echo -e "${GREEN}Java is already installed: $(java -version 2>&1 | head -n 1)${NC}"
fi

# 6. Verify Maven
if ! command -v mvn &> /dev/null; then
    echo -e "${YELLOW}Installing latest Maven...${NC}"
    apt-get install -y maven
else
    echo -e "${GREEN}Maven is already installed: $(mvn -v | head -n 1)${NC}"
fi

# 7. Kill anything on Port 8080
echo -e "${YELLOW}Checking for processes on port $PORT...${NC}"
if systemctl is-active --quiet jenkins; then
    echo -e "${YELLOW}Stopping local Jenkins service...${NC}"
    systemctl stop jenkins
    systemctl disable jenkins
fi

PID=$(lsof -t -i:$PORT)
if [ -n "$PID" ]; then
    echo -e "${YELLOW}Killing process $PID on port $PORT...${NC}"
    kill -9 $PID
fi

# 8. Clean up old containers and volumes
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo -e "${YELLOW}Removing existing container: $CONTAINER_NAME...${NC}"
    docker rm -f $CONTAINER_NAME
fi

if [ "$CLEAN_START" = true ]; then
    if docker volume inspect $VOLUME_NAME &>/dev/null; then
        echo -e "${RED}Wiping Jenkins volume: $VOLUME_NAME...${NC}"
        docker volume rm $VOLUME_NAME
    fi
fi

# 10. Pull and Run the Image
echo -e "${YELLOW}Pulling image: $DOCKER_IMAGE...${NC}"
docker pull $DOCKER_IMAGE

# Ask for the Student's GitHub Fork URL
echo -e "${GREEN}--------------------------------------------------${NC}"
echo -e "${YELLOW}Final Configuration:${NC}"
read -p "Enter your GitHub Fork URL (e.g., https://github.com/student/dev-portfolio-test.git): " GITHUB_URL
echo -e "${GREEN}--------------------------------------------------${NC}"

echo -e "${GREEN}Launching Jenkins...${NC}"
# Ensure the Docker socket has the correct permissions before starting
chmod 666 /var/run/docker.sock

docker run -d \
  --name $CONTAINER_NAME \
  -p $PORT:8080 \
  -p 50000:50000 \
  -v $VOLUME_NAME:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e GITHUB_REPO_URL="$GITHUB_URL" \
  --restart unless-stopped \
  $DOCKER_IMAGE

# 11. Final Verification
echo -e "${GREEN}--------------------------------------------------${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}Jenkins is running at: http://$(hostname -I | awk '{print $1}'):$PORT${NC}"
echo -e "${GREEN}Security: DISABLED (No login required)${NC}"

# Interactive Cloning Step
echo -e "${YELLOW}--------------------------------------------------${NC}"
read -p "Do you want to clone your repository locally to start editing the code? (y/n): " CLONE_CHOICE
if [[ "$CLONE_CHOICE" == "y" || "$CLONE_CHOICE" == "Y" ]]; then
    echo -e "${YELLOW}Cloning $GITHUB_URL into 'portfolio-code' folder...${NC}"
    # Run as the regular user so they have permissions to edit the files
    if [ -n "$SUDO_USER" ]; then
        sudo -u $SUDO_USER git clone "$GITHUB_URL" portfolio-code
    else
        git clone "$GITHUB_URL" portfolio-code
    fi
    echo -e "${GREEN}Success! Your code is in the 'portfolio-code' folder.${NC}"
fi

if [ -n "$SUDO_USER" ]; then
    echo -e "${YELLOW}Reminder: Please log out and log back in (or run 'newgrp docker') to use docker without sudo.${NC}"
fi
echo -e "${GREEN}--------------------------------------------------${NC}"
