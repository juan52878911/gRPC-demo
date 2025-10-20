# Ansible Configuration for Rancher Cluster

Este directorio contiene los playbooks y roles de Ansible para configurar automáticamente el cluster de Rancher.

## Estructura

```
ansible/
├── ansible.cfg                 # Configuración de Ansible
├── inventory.ini              # Generado automáticamente por Terraform
├── inventory.ini.template     # Template para el inventario
├── requirements.yml           # Dependencias de Ansible
├── site.yml                   # Playbook principal
├── setup-cluster.yml         # Playbook simplificado
├── deploy-workers.sh         # Script para registrar workers
└── roles/
    ├── master/               # Rol para el nodo master
    │   ├── tasks/
    │   │   └── main.yml     # Tareas de instalación de Rancher
    │   └── defaults/
    │       └── main.yml     # Variables por defecto
    └── worker/               # Rol para nodos worker
        ├── tasks/
        │   └── main.yml     # Tareas de registro en el cluster
        └── defaults/
            └── main.yml     # Variables por defecto
```

## Prerequisitos

Antes de ejecutar los playbooks, asegúrate de tener instaladas las colecciones necesarias:

```bash
ansible-galaxy collection install -r requirements.yml
```

## Uso

### 1. Instalación completa (automática con setup.sh)

El script `setup.sh` en el directorio raíz ejecuta automáticamente:
1. Terraform para crear las VMs
2. Ansible para instalar Rancher en el master

```bash
cd ..
./setup.sh
```

### 2. Solo instalar Rancher en el master

```bash
ansible-playbook -i inventory.ini site.yml --tags master
```

### 3. Registrar workers en el cluster

Primero, crea el cluster en la UI de Rancher y guarda el comando de registro:

```bash
# Crear archivo con el comando de registro
echo "sudo docker run -d --privileged..." > registration_cmd.sh

# Ejecutar el script de deployment
./deploy-workers.sh
```

O manualmente:

```bash
ansible-playbook -i inventory.ini site.yml --tags workers
```

## Roles

### Master Role

Instala y configura Rancher en el nodo master:
- Crea directorios necesarios
- Despliega el contenedor de Rancher
- Espera a que Rancher esté disponible
- Obtiene y guarda la contraseña de bootstrap
- Verifica que la API esté funcionando

### Worker Role

Registra los nodos worker en el cluster de Rancher:
- Verifica si el nodo ya está registrado
- Espera el comando de registro
- Ejecuta el comando de registro
- Verifica que el agente esté corriendo

## Variables

### Master Role Variables (roles/master/defaults/main.yml)

- `rancher_version`: Versión de Rancher (default: "latest")
- `rancher_container_name`: Nombre del contenedor (default: "rancher")
- `rancher_data_dir`: Directorio de datos (default: "/opt/rancher")
- `rancher_http_port`: Puerto HTTP (default: 80)
- `rancher_https_port`: Puerto HTTPS (default: 443)

### Worker Role Variables (roles/worker/defaults/main.yml)

- `rancher_registration_wait_timeout`: Timeout para esperar el comando (default: 600)
- `registration_check_interval`: Intervalo de verificación (default: 10)

## Troubleshooting

### Ver logs de Ansible en detalle

```bash
ansible-playbook -i inventory.ini site.yml --tags master -vvv
```

### Verificar conectividad

```bash
ansible all -i inventory.ini -m ping
```

### Ver estado de Docker en los nodos

```bash
ansible all -i inventory.ini -m shell -a "systemctl status docker"
```

### Verificar contenedores de Rancher

```bash
ansible master -i inventory.ini -m shell -a "docker ps"
```
