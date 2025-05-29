#!/bin/bash

# Deploy script específico para k3s
# Ejecutar: bash deploy-k3s.sh

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

echo "🚀 Horoscope WhatsApp Bot - k3s Deployment"
echo "==========================================="
echo ""

NAMESPACE="horoscope-bot"
APP_NAME="horoscope-bot"
IMAGE_NAME="horoscope-whatsapp:latest"

check_k3s() {
    echo "🔍 Verificando k3s..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl no está disponible. Instala k3s correctamente."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "No se puede conectar al cluster k3s."
        exit 1
    fi
    
    print_success "k3s está funcionando"
    
    echo "📊 Info del cluster:"
    kubectl get nodes
    echo ""
}

check_storage() {
    echo "💾 Verificando storage classes..."
    
    if kubectl get storageclass local-path &> /dev/null; then
        print_success "StorageClass 'local-path' encontrado (k3s default)"
        kubectl get storageclass local-path
    else
        print_warning "StorageClass 'local-path' no encontrado"
        print_info "k3s debería tener local-path por defecto. Verificando..."
        kubectl get storageclass
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
    
    docker build -t $IMAGE_NAME .
    
    print_info "Importando imagen a k3s..."
    docker save $IMAGE_NAME | sudo k3s ctr images import -
    
    print_success "Imagen construida e importada a k3s"
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
    
    source .env
    
    if [ -z "$RECIPIENT_PHONE" ] || [ "$RECIPIENT_PHONE" = "CHANGE_ME@c.us" ]; then
        print_error "RECIPIENT_PHONE no está configurado en .env"
        print_info "Formato: 5491123456789@c.us (código país + número + @c.us)"
        exit 1
    fi
    
    print_success "Configuración validada"
    echo ""
}

deploy_with_pvc() {
    echo "📦 Desplegando con Persistent Volume Claims..."
    
    kubectl apply -f k3s-deployment.yaml
    
    print_success "Deployment aplicado con PVCs"
}

deploy_with_hostpath() {
    echo "📁 Desplegando con hostPath volumes..."
    
    NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    print_info "Usando nodo: $NODE_NAME"
    
    print_info "Creando directorios en el nodo..."
    sudo mkdir -p /opt/horoscope-bot/{wwebjs_auth,logs}
    sudo chmod 755 /opt/horoscope-bot/{wwebjs_auth,logs}
    
    sed "s/NODE_NAME/$NODE_NAME/g" k3s-hostpath-deployment.yaml | kubectl apply -f -
    
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
    
    CLUSTER_IP=$(kubectl get service horoscope-bot-service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
    
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
    echo "  kubectl port-forward service/horoscope-bot-service 3000:3000 -n $NAMESPACE"
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
    
    print_success "¡Tu bot de horóscopos está corriendo en k3s! 🌟"
}

main() {
    DEPLOYMENT_TYPE="${1:-pvc}"
    
    if [ "$DEPLOYMENT_TYPE" != "pvc" ] && [ "$DEPLOYMENT_TYPE" != "hostpath" ]; then
        print_error "Uso: $0 [pvc|hostpath]"
        print_info "pvc: Usar Persistent Volume Claims (recomendado)"
        print_info "hostpath: Usar hostPath volumes (alternativo)"
        exit 1
    fi
    
    check_k3s
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
    echo "Deploy script para k3s"
    echo ""
    echo "Uso: $0 [pvc|hostpath]"
    echo ""
    echo "Opciones:"
    echo "  pvc      - Usar Persistent Volume Claims (por defecto)"
    echo "  hostpath - Usar hostPath volumes"
    echo ""
    echo "Ejemplos:"
    echo "  $0           # Deploy con PVCs"
    echo "  $0 pvc       # Deploy con PVCs"
    echo "  $0 hostpath  # Deploy con hostPath"
    exit 0
fi

main "$@"