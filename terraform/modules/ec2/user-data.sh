#!/bin/bash
set -euo pipefail

# Update and install Docker + Docker Compose
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release unzip

# Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# AWS CLI v2 (for ECR login)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create app directory
mkdir -p /opt/bankapp
cd /opt/bankapp

# Simple docker-compose for production (images from ECR + public MySQL/Ollama)
cat > docker-compose.yml << 'EOF'
services:
  mysql:
    image: mysql:8.0
    container_name: bank-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ChangeMeRoot123!
      MYSQL_DATABASE: bankdb
      MYSQL_USER: bankuser
      MYSQL_PASSWORD: ChangeMeBank123!
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - bank-net

  ollama:
    image: ollama/ollama:latest
    container_name: bank-ollama
    restart: unless-stopped
    volumes:
      - ollama-data:/root/.ollama
    networks:
      - bank-net

  bankapp:
    image: ${ECR_REPO}:latest
    container_name: bankapp
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy
      ollama:
        condition: service_started
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/bankdb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
      SPRING_DATASOURCE_USERNAME: bankuser
      SPRING_DATASOURCE_PASSWORD: ChangeMeBank123!
      SPRING_AI_OLLAMA_BASE_URL: http://ollama:11434
      SPRING_AI_OLLAMA_CHAT_OPTIONS_MODEL: tinyllama
    ports:
      - "8080:8080"
    networks:
      - bank-net

volumes:
  mysql-data:
  ollama-data:

networks:
  bank-net:
    driver: bridge
EOF

# Login to ECR and pull (instance profile provides credentials)
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repository_url}

# Export for compose
export ECR_REPO=${ecr_repository_url}

# Pull and start (bankapp image must already be pushed by CI)
docker compose pull || true
docker compose up -d

# Pull TinyLlama model (runs in background; may take time on t3.micro)
docker exec bank-ollama ollama pull tinyllama || true

echo "User-data completed at $(date)" >> /var/log/user-data.log
