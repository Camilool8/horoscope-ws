#!/bin/bash

# Quick Start Script para Horoscope WhatsApp Bot
# Ejecutar: bash quick-start.sh

set -e

echo "🌟 Horoscope WhatsApp Bot - Quick Start Setup"
echo "============================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Verificar prerrequisitos
check_prerequisites() {
    echo "🔍 Verificando prerrequisitos..."
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker no está instalado. Por favor instala Docker y vuelve a ejecutar."
        exit 1
    fi
    print_success "Docker encontrado"
    
    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose no está instalado. Por favor instala Docker Compose."
        exit 1
    fi
    print_success "Docker Compose encontrado"
    
    # Verificar que Docker esté corriendo
    if ! docker info &> /dev/null; then
        print_error "Docker no está corriendo. Por favor inicia Docker."
        exit 1
    fi
    print_success "Docker está corriendo"
    
    echo ""
}

# Configurar archivos de entorno
setup_environment() {
    echo "⚙️  Configurando entorno..."
    
    # Copiar .env si no existe
    if [ ! -f .env ]; then
        cp .env.template .env
        print_success "Archivo .env creado desde template"
        
        print_warning "IMPORTANTE: Debes editar el archivo .env con tu configuración"
        print_info "Especialmente el número de WhatsApp: RECIPIENT_PHONE"
        echo ""
        
        read -p "¿Quieres editar el archivo .env ahora? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} .env
        fi
    else
        print_info "Archivo .env ya existe"
    fi
    
    # Crear directorios de datos
    echo "📁 Creando directorios de datos..."
    mkdir -p data/wwebjs_auth data/logs
    
    # Configurar permisos
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo chown -R 1000:1000 data/
        print_success "Permisos configurados para Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "En macOS, los permisos se configurarán automáticamente"
    fi
    
    print_success "Entorno configurado"
    echo ""
}

# Construir imagen Docker
build_image() {
    echo "🐳 Construyendo imagen Docker..."
    
    if docker-compose build; then
        print_success "Imagen construida exitosamente"
    else
        print_error "Error construyendo la imagen"
        exit 1
    fi
    echo ""
}

# Probar scraping
test_scraping() {
    echo "🧪 Probando scraping (opcional)..."
    
    read -p "¿Quieres probar el scraping antes de iniciar? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v node &> /dev/null; then
            npm install
            node test-scrapper.js
        else
            print_warning "Node.js no encontrado localmente, usando Docker..."
            docker-compose run --rm horoscope-bot node test-scrapper.js
        fi
    fi
    echo ""
}

# Iniciar servicios
start_services() {
    echo "🚀 Iniciando servicios..."
    
    if docker-compose up -d; then
        print_success "Servicios iniciados"
        print_info "Los contenedores están corriendo en segundo plano"
    else
        print_error "Error iniciando servicios"
        exit 1
    fi
    echo ""
}

# Mostrar logs y código QR
show_qr_code() {
    echo "📱 Preparando código QR de WhatsApp..."
    print_info "Los logs se mostrarán a continuación"
    print_warning "Busca el código QR y escanealo con tu WhatsApp"
    echo ""
    
    echo "Presiona Ctrl+C para detener la visualización de logs cuando hayas escaneado el QR"
    echo ""
    
    sleep 3
    docker-compose logs -f horoscope-bot
}

# Mostrar información final
show_final_info() {
    echo ""
    echo "🎉 ¡Setup completado!"
    echo "===================="
    echo ""
    print_info "Comandos útiles:"
    echo "  docker-compose logs -f           # Ver logs en tiempo real"
    echo "  docker-compose restart horoscope-bot  # Reiniciar bot"
    echo "  docker-compose down              # Detener servicios"
    echo "  docker-compose up -d             # Reiniciar servicios"
    echo ""
    print_info "Endpoints de monitoreo:"
    echo "  http://localhost:3000/health     # Health check"
    echo "  http://localhost:3000/status     # Estado detallado"
    echo ""
    print_warning "Recuerda:"
    echo "  - El código QR se debe escanear solo una vez"
    echo "  - La sesión se mantiene entre reinicios"
    echo "  - Los horóscopos se envían automáticamente a la hora configurada"
    echo ""
    print_success "¡Tu bot de horóscopos está corriendo! 💕"
}

# Función principal
main() {
    check_prerequisites
    setup_environment
    build_image
    test_scraping
    start_services
    show_qr_code
    show_final_info
}

# Manejar interrupción de Ctrl+C
trap 'echo -e "\n\n🛑 Setup interrumpido por el usuario"; exit 0' INT

# Verificar si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi