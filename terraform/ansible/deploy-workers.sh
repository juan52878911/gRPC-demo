#!/bin/bash

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REGISTRATION_CMD_FILE="registration_cmd.sh"

echo -e "${YELLOW}=== Deploying Workers to Rancher Cluster ===${NC}"
echo ""

# Verificar que existe el archivo de comando de registro
if [ ! -f "$REGISTRATION_CMD_FILE" ]; then
    echo -e "${RED}Error: Registration command file not found!${NC}"
    echo ""
    echo "Please create the file '$REGISTRATION_CMD_FILE' with the registration command from Rancher UI:"
    echo ""
    echo "1. Go to Rancher UI"
    echo "2. Create or select your cluster"
    echo "3. Click 'Registration' tab"
    echo "4. Copy the command that starts with: sudo docker run -d --privileged..."
    echo "5. Save it to: $REGISTRATION_CMD_FILE"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Registration command file found${NC}"
echo ""

# Copiar el comando de registro a todos los workers
echo -e "${YELLOW}Copying registration command to all worker nodes...${NC}"
for host in $(grep -A 100 '\[workers\]' inventory.ini | grep ansible_host | awk '{print $2}' | cut -d= -f2); do
    echo "  → Copying to $host"
    scp -o StrictHostKeyChecking=no "$REGISTRATION_CMD_FILE" ubuntu@$host:/tmp/rancher_registration_cmd.sh
done

echo ""
echo -e "${GREEN}✓ Registration command distributed to all workers${NC}"
echo ""

# Ejecutar el playbook de workers
echo -e "${YELLOW}Running Ansible playbook to register workers...${NC}"
ansible-playbook -i inventory.ini site.yml --tags workers

echo ""
echo -e "${GREEN}=== Workers deployment completed! ===${NC}"
echo ""
echo "Check your Rancher UI to verify all nodes are registered and active."
echo ""
