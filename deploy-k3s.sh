#!/bin/bash

# Script de despliegue para Kubernetes
# Ejecutar: bash deploy-k8s.sh

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

echo "🚀 Horoscope WhatsApp Bot - Kubernetes Deployment"
echo "==========================================="
echo ""

# Configuración por defecto - EDITAR ESTOS VALORES
DEFAULT_NAMESPACE="horoscope-bot"
DEFAULT_APP_NAME="horoscope-bot"
DEFAULT_IMAGE_NAME="your-registry/horoscope-bot:latest"
REQUIRED_ARCH="linux/amd64"  # Arquitectura requerida

# Verificar si se proporcionaron valores personalizados
NAMESPACE="${K8S_NAMESPACE:-$DEFAULT_NAMESPACE}"
APP_NAME="${K8S_APP_NAME:-$DEFAULT_APP_NAME}"
IMAGE_NAME="${DOCKER_IMAGE:-$DEFAULT_IMAGE_NAME}"

check_requirements() {
    echo "🔍 Verificando requisitos..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl no está disponible. Por favor, instala kubectl."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "docker no está disponible. Por favor, instala Docker."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "No se puede conectar al cluster Kubernetes."
        exit 1
    fi
    
    # Verificar arquitectura del nodo
    NODE_ARCH=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}')
    if [ "$NODE_ARCH" != "amd64" ]; then
        print_warning "⚠️  El nodo está ejecutando en $NODE_ARCH, pero $REQUIRED_ARCH es requerido"
        print_info "Se recomienda usar un nodo AMD64 para mejor compatibilidad"
        read -p "¿Deseas continuar de todos modos? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_success "Requisitos verificados"
    
    echo "📊 Info del cluster:"
    kubectl get nodes
    echo ""
    
    print_warning "IMPORTANTE: Verifica que los siguientes valores sean correctos:"
    echo "  Namespace: $NAMESPACE"
    echo "  App Name: $APP_NAME"
    echo "  Docker Image: $IMAGE_NAME"
    echo "  Arquitectura requerida: $REQUIRED_ARCH"
    echo ""
    read -p "¿Los valores son correctos? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Puedes configurar los valores usando variables de entorno:"
        echo "  K8S_NAMESPACE=mi-namespace"
        echo "  K8S_APP_NAME=mi-app"
        echo "  DOCKER_IMAGE=mi-registry/mi-imagen:tag"
        exit 1
    fi
}

check_storage() {
    echo "💾 Verificando storage classes..."
    
    if kubectl get storageclass &> /dev/null; then
        print_success "StorageClasses disponibles:"
        kubectl get storageclass
    else
        print_warning "No se encontraron StorageClasses"
    fi
    echo ""
}

build_image() {
    echo "🐳 Construyendo imagen Docker..."
    
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile no encontrado"
        exit 1
    fi
    
    if [ ! -f "package.json" ]; then
        print_error "package.json no encontrado"
        exit 1
    fi
    
    print_info "Construyendo imagen para plataforma $REQUIRED_ARCH..."
    print_warning "⚠️  IMPORTANTE: Esta imagen debe ser construida para $REQUIRED_ARCH"
    print_info "Usando BuildKit para asegurar la arquitectura correcta..."
    
    DOCKER_BUILDKIT=1 docker build \
        --platform $REQUIRED_ARCH \
        --build-arg TARGETPLATFORM=$REQUIRED_ARCH \
        -t $IMAGE_NAME .
    
    print_info "Imagen construida: $IMAGE_NAME"
    print_warning "IMPORTANTE: Debes subir la imagen a tu registry antes de continuar"
    print_info "Ejemplo: docker push $IMAGE_NAME"
    read -p "¿Has subido la imagen a tu registry? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        read -p "¿Quieres subir la imagen a tu registry? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker push $IMAGE_NAME
            print_success "Imagen subida a tu registry"
        else
            print_error "No se puede continuar sin subir la imagen"
            exit 1
        fi
    fi
    
    print_success "Imagen verificada"
    echo ""
}

setup_secrets() {
    echo "🔐 Configurando secretos..."
    
    if [ ! -f ".env" ]; then
        print_warning "Archivo .env no encontrado, creando desde template..."
        if [ -f ".env.template" ]; then
            cp .env.template .env
            print_warning "IMPORTANTE: Edita .env con tu configuración antes de continuar"
            read -p "¿Quieres editar .env ahora? (y/n): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} .env
            fi
        else
            print_error "Template .env.template no encontrado"
            exit 1
        fi
    fi
    
    # Cargar todas las variables de .env
    set -a
    source .env
    set +a
    
    # Verificar variables requeridas
    if [ -z "$RECIPIENT_PHONE" ] || [ "$RECIPIENT_PHONE" = "CHANGE_ME@c.us" ]; then
        print_error "RECIPIENT_PHONE no está configurado en .env"
        print_info "Formato: 5491123456789@c.us (código país + número + @c.us)"
        exit 1
    fi
    
    # Exportar variables para uso en sed
    export SECRET_RECIPIENT_PHONE="$RECIPIENT_PHONE"
    export SECRET_HOROSCOPES_SIGNS="${HOROSCOPES_SIGNS:-sign1,sign2}"
    export SECRET_SEND_TIME="${SEND_TIME:-08:00}"
    export SECRET_TZ="${TZ:-America/Santo_Domingo}"
    export SECRET_SEND_ON_STARTUP="${SEND_ON_STARTUP:-false}"
    export SECRET_WEEKLY_ENABLED="${WEEKLY_ENABLED:-false}"
    export SECRET_LOG_MESSAGES="${LOG_MESSAGES:-true}"
    
    print_success "Configuración validada"
    echo ""
}

deploy_with_pvc() {
    echo "📦 Desplegando con Persistent Volume Claims..."
    
    sed -e "s|image: .*|image: $IMAGE_NAME|g" \
        -e "s/namespace: .*/namespace: $NAMESPACE/g" \
        -e "s/name: .*-bot/name: $APP_NAME/g" \
        -e "s/app: .*-bot/app: $APP_NAME/g" \
        -e "s/matchLabels:\n.*app: .*-bot/matchLabels:\n      app: $APP_NAME/g" \
        -e "s/selector:\n.*app: .*-bot/selector:\n    app: $APP_NAME/g" \
        -e "s|RECIPIENT_PHONE: .*|RECIPIENT_PHONE: \"$SECRET_RECIPIENT_PHONE\"|g" \
        -e "s|HOROSCOPES_SIGNS: .*|HOROSCOPES_SIGNS: \"$SECRET_HOROSCOPES_SIGNS\"|g" \
        -e "s|SEND_TIME: .*|SEND_TIME: \"$SECRET_SEND_TIME\"|g" \
        -e "s|TZ: .*|TZ: \"$SECRET_TZ\"|g" \
        -e "s|SEND_ON_STARTUP: .*|SEND_ON_STARTUP: \"$SECRET_SEND_ON_STARTUP\"|g" \
        -e "s|WEEKLY_ENABLED: .*|WEEKLY_ENABLED: \"$SECRET_WEEKLY_ENABLED\"|g" \
        -e "s|LOG_MESSAGES: .*|LOG_MESSAGES: \"$SECRET_LOG_MESSAGES\"|g" \
        k3s-deployment.yaml | kubectl apply -f -
    
    print_success "Deployment aplicado con PVCs"
}

deploy_with_hostpath() {
    echo "📁 Desplegando con hostPath volumes..."
    
    NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    print_info "Usando nodo: $NODE_NAME"
    
    print_info "Creando directorios en el nodo..."
    sudo mkdir -p /opt/$APP_NAME/{wwebjs_auth,logs}
    sudo chmod 755 /opt/$APP_NAME/{wwebjs_auth,logs}
    
    sed -e "s|image: .*|image: $IMAGE_NAME|g" \
        -e "s/namespace: .*/namespace: $NAMESPACE/g" \
        -e "s/name: .*-bot/name: $APP_NAME/g" \
        -e "s/app: .*-bot/app: $APP_NAME/g" \
        -e "s/matchLabels:\n.*app: .*-bot/matchLabels:\n      app: $APP_NAME/g" \
        -e "s/selector:\n.*app: .*-bot/selector:\n    app: $APP_NAME/g" \
        -e "s|RECIPIENT_PHONE: .*|RECIPIENT_PHONE: \"$SECRET_RECIPIENT_PHONE\"|g" \
        -e "s|HOROSCOPES_SIGNS: .*|HOROSCOPES_SIGNS: \"$SECRET_HOROSCOPES_SIGNS\"|g" \
        -e "s|SEND_TIME: .*|SEND_TIME: \"$SECRET_SEND_TIME\"|g" \
        -e "s|TZ: .*|TZ: \"$SECRET_TZ\"|g" \
        -e "s|SEND_ON_STARTUP: .*|SEND_ON_STARTUP: \"$SECRET_SEND_ON_STARTUP\"|g" \
        -e "s|WEEKLY_ENABLED: .*|WEEKLY_ENABLED: \"$SECRET_WEEKLY_ENABLED\"|g" \
        -e "s|LOG_MESSAGES: .*|LOG_MESSAGES: \"$SECRET_LOG_MESSAGES\"|g" \
        -e "s/NODE_NAME/$NODE_NAME/g" \
        -e "s|/opt/horoscope-bot|/opt/$APP_NAME|g" \
        k3s-hostpath-deployment.yaml | kubectl apply -f -
    
    print_success "Deployment aplicado con hostPath"
}

show_status() {
    echo "📊 Estado del deployment..."
    
    echo "Namespace:"
    kubectl get namespace $NAMESPACE
    echo ""
    
    echo "Pods:"
    kubectl get pods -n $NAMESPACE
    echo ""
    
    echo "Services:"
    kubectl get services -n $NAMESPACE
    echo ""
    
    echo "PVCs (si aplica):"
    kubectl get pvc -n $NAMESPACE 2>/dev/null || echo "No PVCs found"
    echo ""
}

show_logs_for_qr() {
    echo "📱 Obteniendo código QR..."
    print_info "Esperando que el pod esté listo..."
    
    kubectl wait --for=condition=Ready pod -l app=$APP_NAME -n $NAMESPACE --timeout=300s
    
    print_success "Pod está listo. Mostrando logs para obtener código QR..."
    print_warning "Busca el código QR en los logs y escanealo con WhatsApp"
    print_info "Presiona Ctrl+C cuando hayas escaneado el QR"
    echo ""
    
    sleep 2
    kubectl logs -f deployment/$APP_NAME -n $NAMESPACE
}

show_final_info() {
    echo ""
    echo "🎉 ¡Deployment completado!"
    echo "========================="
    echo ""
    
    CLUSTER_IP=$(kubectl get service $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
    
    print_info "Comandos útiles:"
    echo "  # Ver logs"
    echo "  kubectl logs -f deployment/$APP_NAME -n $NAMESPACE"
    echo ""
    echo "  # Ver estado"
    echo "  kubectl get all -n $NAMESPACE"
    echo ""
    echo "  # Health check (desde dentro del cluster)"
    echo "  kubectl run test-pod --rm -i --tty --image=curlimages/curl -- curl http://$CLUSTER_IP:3000/health"
    echo ""
    echo "  # Port forward para health check local"
    echo "  kubectl port-forward service/$APP_NAME 3000:3000 -n $NAMESPACE"
    echo "  # Luego: curl http://localhost:3000/health"
    echo ""
    echo "  # Reiniciar deployment"
    echo "  kubectl rollout restart deployment/$APP_NAME -n $NAMESPACE"
    echo ""
    echo "  # Ver secretos"
    echo "  kubectl get secrets -n $NAMESPACE"
    echo ""
    
    print_info "Para eliminar todo:"
    echo "  kubectl delete namespace $NAMESPACE"
    echo ""
    
    print_success "¡Tu bot de horóscopos está corriendo en Kubernetes! 🌟"
}

main() {
    DEPLOYMENT_TYPE="${1:-pvc}"
    
    if [ "$DEPLOYMENT_TYPE" != "pvc" ] && [ "$DEPLOYMENT_TYPE" != "hostpath" ]; then
        print_error "Uso: $0 [pvc|hostpath]"
        print_info "pvc: Usar Persistent Volume Claims (recomendado)"
        print_info "hostpath: Usar hostPath volumes (alternativo)"
        exit 1
    fi
    
    check_requirements
    check_storage
    setup_secrets
    build_image
    
    if [ "$DEPLOYMENT_TYPE" = "pvc" ]; then
        deploy_with_pvc
    else
        deploy_with_hostpath
    fi
    
    show_status
    show_logs_for_qr
    show_final_info
}

trap 'echo -e "\n\n🛑 Deployment interrumpido"; exit 0' INT

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Script de despliegue para Kubernetes"
    echo ""
    echo "Uso: $0 [pvc|hostpath]"
    echo ""
    echo "Configuración:"
    echo "  K8S_NAMESPACE    - Namespace de Kubernetes (default: horoscope-bot)"
    echo "  K8S_APP_NAME     - Nombre de la aplicación (default: horoscope-bot)"
    echo "  DOCKER_IMAGE     - Imagen Docker completa (default: your-registry/horoscope-bot:latest)"
    echo ""
    echo "Opciones:"
    echo "  pvc      - Usar Persistent Volume Claims (por defecto)"
    echo "  hostpath - Usar hostPath volumes"
    echo ""
    echo "Ejemplos:"
    echo "  K8S_NAMESPACE=mi-namespace K8S_APP_NAME=mi-app DOCKER_IMAGE=mi-registry/mi-imagen:tag $0"
    echo "  $0 pvc       # Deploy con PVCs"
    echo "  $0 hostpath  # Deploy con hostPath"
    exit 0
fi

main "$@"