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

echo -e "${BLUE}Ejecutando playbook de Ansible para instalar Rancher...${NC}"
ansible-playbook -i inventory.ini site.yml --tags master

cd ..

# Información final
echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}=== Instalación Completada ===${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

echo -e "${GREEN}🎉 Rancher Master está listo!${NC}"
echo ""
echo -e "📍 Accede a Rancher en: ${BLUE}https://$MASTER_IP${NC}"
echo ""

# Obtener la contraseña
echo -e "${YELLOW}Contraseña de Bootstrap:${NC}"
if multipass exec rancher-master -- cat /home/ubuntu/rancher-password.txt 2>/dev/null; then
    echo ""
else
    echo -e "${YELLOW}Ejecuta este comando para obtener la contraseña:${NC}"
    echo -e "${BLUE}multipass exec rancher-master -- cat /home/ubuntu/rancher-password.txt${NC}"
    echo ""
fi

echo -e "📋 Recursos creados:"
terraform output
echo ""

echo -e "${GREEN}📝 Próximos pasos para configurar el cluster:${NC}"
echo ""
echo "1. Abre tu navegador en https://$MASTER_IP"
echo "2. Acepta el certificado autofirmado"
echo "3. Usa la contraseña de bootstrap mostrada arriba"
echo "4. Configura la contraseña de admin y la URL del servidor"
echo "5. Crea un nuevo cluster Custom:"
echo "   - Cluster Management → Create"
echo "   - Selecciona 'Custom'"
echo "   - Marca las opciones: etcd, Control Plane, Worker"
echo "   - Copia el comando de registro que aparece"
echo "6. Guarda el comando en: ansible/registration_cmd.sh"
echo "7. Ejecuta: cd ansible && ./deploy-workers.sh"
echo ""

echo -e "${YELLOW}💡 Comandos útiles:${NC}"
echo "  Ver estado VMs: multipass list"
echo "  Conectar al master: multipass shell rancher-master"
echo "  Ver logs de Rancher: multipass exec rancher-master -- docker logs -f rancher"
echo "  Deploy workers: cd ansible && ./deploy-workers.sh"
echo "  Destruir todo: terraform destroy -auto-approve"
echo ""