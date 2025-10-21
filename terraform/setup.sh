#!/bin/bash

set -e

echo "=== Configuración de Rancher con Multipass, Terraform y Ansible ==="

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Verificar dependencias
echo -e "${YELLOW}Verificando dependencias...${NC}"
command -v multipass >/dev/null 2>&1 || { echo -e "${RED}Multipass no está instalado. Instálalo con: brew install multipass${NC}"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform no está instalado. Instálalo con: brew install terraform${NC}"; exit 1; }
command -v ansible >/dev/null 2>&1 || { echo -e "${RED}Ansible no está instalado. Instálalo con: brew install ansible${NC}"; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { echo -e "${RED}Ansible-playbook no está disponible${NC}"; exit 1; }

echo -e "${GREEN}✓ Todas las dependencias están instaladas${NC}"

# Configurar clave SSH
echo -e "${BLUE}Configurando clave SSH...${NC}"
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo -e "${YELLOW}Generando nueva clave SSH...${NC}"
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
fi

echo -e "${GREEN}✓ Clave SSH configurada${NC}"

# Paso 1: Terraform - Provisionar VMs
echo ""
echo -e "${GREEN}Paso 1: Provisionando VMs con Terraform...${NC}"
echo -e "${YELLOW}Esto tomará unos minutos mientras cloud-init instala las dependencias...${NC}"
terraform init
terraform apply -auto-approve

# Paso 2: Esperar a que cloud-init termine en todos los nodos
echo ""
echo -e "${GREEN}Paso 2: Esperando a que cloud-init termine en todos los nodos...${NC}"
echo -e "${YELLOW}Esperando 30 segundos para que las VMs inicien completamente...${NC}"
sleep 30

echo -e "${YELLOW}Verificando que Docker esté instalado y corriendo en el master...${NC}"

MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    # Verificar si el comando se ejecuta sin error - sin redirección para evitar timeout
    DOCKER_STATUS=$(multipass exec rancher-master -- systemctl is-active docker 2>&1 || echo "inactive")
    if [ "$DOCKER_STATUS" = "active" ]; then
        echo ""
        echo -e "${GREEN}✓ Master node está listo (Docker: $DOCKER_STATUS)${NC}"
        break
    fi
    echo -n "."
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo ""
    echo -e "${RED}Error: Timeout esperando que el master esté listo${NC}"
    echo -e "${YELLOW}Verificando estado del master...${NC}"
    multipass exec rancher-master -- systemctl status docker || true
    exit 1
fi

# Verificar workers también estén listos
echo -e "${YELLOW}Verificando que los workers estén listos...${NC}"
WORKER_COUNT=$(terraform output -json worker_names | jq -r 'length')

for i in $(seq 1 "$WORKER_COUNT"); do
    WORKER_NAME="worker-$i"
    ATTEMPT=0
    while [ $ATTEMPT -lt 30 ]; do
        DOCKER_STATUS=$(multipass exec "$WORKER_NAME" -- systemctl is-active docker 2>&1 || echo "inactive")
        if [ "$DOCKER_STATUS" = "active" ]; then
            echo -e "${GREEN}✓ $WORKER_NAME está listo (Docker: $DOCKER_STATUS)${NC}"
            break
        fi
        sleep 2
        ATTEMPT=$((ATTEMPT + 1))
    done

    if [ $ATTEMPT -eq 30 ]; then
        echo -e "${YELLOW}⚠ $WORKER_NAME tardó más de lo esperado, pero continuaremos${NC}"
    fi
done

# Obtener IP del master después de verificar que esté listo
MASTER_IP=$(terraform output -raw master_ip)

# Paso 3: Ejecutar Ansible para configurar Rancher
echo ""
echo -e "${GREEN}Paso 3: Configurando Rancher con Ansible...${NC}"
cd ansible

# Verificar que el inventario se haya generado
if [ ! -f inventory.ini ]; then
    echo -e "${RED}Error: El inventario de Ansible no se generó correctamente${NC}"
    exit 1
fi

echo -e "${BLUE}Ejecutando playbook de Ansible para instalar Rancher y crear cluster...${NC}"
ansible-playbook -i inventory.ini site.yml --tags master

if [ $? -ne 0 ]; then
    echo -e "${RED}Error al configurar Rancher Master${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Rancher Master configurado exitosamente${NC}"
echo ""
echo -e "${BLUE}Paso 4: Registrando workers al cluster...${NC}"
ansible-playbook -i inventory.ini site.yml --tags workers

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠ Algunos workers pueden haber fallado. Verifica los logs arriba.${NC}"
fi

cd ..

# Información final
echo ""
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}=== Instalación Completa y Automatizada ===${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""

echo -e "${GREEN}🎉 ¡Rancher Cluster está listo!${NC}"
echo ""
echo -e "📍 Accede a Rancher en: ${BLUE}https://$MASTER_IP${NC}"
echo -e "👤 Usuario: ${BLUE}admin${NC}"
echo -e "🔑 Contraseña: ${BLUE}AdminPassword123${NC}"
echo ""

echo -e "${GREEN}📊 Cluster Info:${NC}"
echo -e "  Cluster Name: local-cluster"
echo -e "  Nodes: 2 workers (+ master if joined)"
echo -e "  Status: Provisioning (espera 3-5 minutos para que K8s se instale)"
echo ""

echo -e "📋 Recursos creados:"
terraform output
echo ""

echo -e "${YELLOW}💡 Comandos útiles:${NC}"
echo "  Ver estado VMs: ${BLUE}multipass list${NC}"
echo "  Conectar al master: ${BLUE}multipass shell rancher-master${NC}"
echo "  Ver logs de Rancher: ${BLUE}multipass exec rancher-master -- docker logs -f rancher${NC}"
echo "  Ver logs de system-agent: ${BLUE}multipass exec worker-1 -- journalctl -u rancher-system-agent -f${NC}"
echo "  Destruir todo: ${BLUE}terraform destroy -auto-approve${NC}"
echo ""

echo -e "${GREEN}✨ El cluster se está configurando automáticamente. En unos minutos verás los nodos activos en el dashboard.${NC}"
echo ""