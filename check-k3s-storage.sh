#!/bin/bash

# Script para verificar y mostrar información del storage en k3s
# Ejecutar: bash check-k3s-storage.sh

echo "🔍 Verificando Storage en k3s"
echo "=============================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ No se puede conectar a k3s"
    exit 1
fi

print_success "Conexión a k3s OK"
echo ""

echo "📦 Storage Classes disponibles:"
echo "--------------------------------"
kubectl get storageclass -o wide
echo ""

if kubectl get storageclass local-path &> /dev/null; then
    print_success "local-path StorageClass encontrado (k3s default)"
    
    echo ""
    echo "🔧 Detalles del local-path provisioner:"
    kubectl get storageclass local-path -o yaml | grep -A 20 "provisioner:\|reclaimPolicy:\|volumeBindingMode:"
    echo ""
    
    echo "🏃 Estado del local-path provisioner:"
    kubectl get pods -n kube-system -l app=local-path-provisioner
    echo ""
    
    echo "⚙️  Configuración del local-path:"
    if kubectl get configmap local-path-config -n kube-system &> /dev/null; then
        kubectl get configmap local-path-config -n kube-system -o yaml | grep -A 10 "config.json"
    else
        print_info "ConfigMap local-path-config no encontrado (usando defaults)"
    fi
    echo ""
    
else
    print_warning "local-path StorageClass no encontrado"
    print_info "k3s debería incluir local-path por defecto"
    echo ""
fi

echo "💾 Persistent Volume Claims existentes:"
echo "--------------------------------------"
kubectl get pvc --all-namespaces
echo ""

echo "🗃️  Persistent Volumes existentes:"
echo "-----------------------------------"
kubectl get pv
echo ""

echo "💿 Espacio en disco de los nodos:"
echo "---------------------------------"
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.storage}{"\n"}{end}' 2>/dev/null || echo "Información de storage no disponible"

echo ""
echo "📂 Ubicación de datos con local-path:"
echo "------------------------------------"
print_info "Por defecto, k3s local-path almacena datos en:"
echo "   /var/lib/rancher/k3s/storage/pvc-[UUID]/"
echo ""
print_info "Para ver datos existentes:"
echo "   sudo ls -la /var/lib/rancher/k3s/storage/"
echo ""

if [ -d "/var/lib/rancher/k3s/storage" ]; then
    STORAGE_DIRS=$(sudo find /var/lib/rancher/k3s/storage -maxdepth 1 -type d -name "pvc-*" 2>/dev/null | wc -l)
    if [ "$STORAGE_DIRS" -gt 0 ]; then
        print_info "Encontrados $STORAGE_DIRS directorios de PVC existentes"
        sudo ls -la /var/lib/rancher/k3s/storage/pvc-* 2>/dev/null | head -5
    else
        print_info "No hay PVCs existentes"
    fi
else
    print_warning "Directorio de storage k3s no encontrado"
fi

echo ""
echo "🎯 Recomendaciones para el Horoscope Bot:"
echo "==========================================="

if kubectl get storageclass local-path &> /dev/null; then
    print_success "✅ Usar k3s-deployment.yaml (con PVCs)"
    print_info "   El local-path provisioner funcionará perfectamente"
else
    print_warning "⚠️  Considerar k3s-hostpath-deployment.yaml"
    print_info "   O instalar local-path provisioner manualmente"
fi

echo ""
print_info "Comandos útiles:"
echo "  # Ver uso de storage por PVC:"
echo "  kubectl get pvc --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,SIZE:.spec.resources.requests.storage,STATUS:.status.phase"
echo ""
echo "  # Limpiar PVCs no utilizados:"
echo "  kubectl get pvc --all-namespaces | grep -E 'Available|Released'"
echo ""
echo "  # Ver logs del local-path provisioner:"
echo "  kubectl logs -n kube-system -l app=local-path-provisioner"