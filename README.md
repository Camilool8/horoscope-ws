# 🌟 Horoscope Scrapping to WhatsApp Web

Un bot automatizado que envía horóscopos personalizados en español a través de WhatsApp Web. Hace scraping de horóscopos de alta calidad de la página [Lecturas.com](https://www.lecturas.com/horoscopo/) y los envía diariamente a tu pareja o persona especial.

## ✨ Características

- 📱 **WhatsApp Web Integration**: Envía mensajes directamente desde tu WhatsApp personal
- 🔍 **Web Scraping**: Obtiene horóscopos de alta calidad en español de Lecturas.com
- 🏠 **Sesión Persistente**: Mantiene la sesión de WhatsApp activa entre reinicios
- ⏰ **Envío Programado**: Envía horóscopos automáticamente a la hora configurada
- 🎯 **Signos Específicos**: Configurado para Cáncer ♋ y Acuario ♒
- 🐳 **Containerizado**: Fácil deployment con Docker y Kubernetes
- 📊 **Health Monitoring**: Endpoints de salud para monitoreo
- 💾 **Logs Persistentes**: Guarda registro de mensajes enviados
- 🌍 **Timezone Support**: Configurable para cualquier zona horaria

## 🚀 Inicio Rápido

### Prerrequisitos

- Docker y Docker Compose
- Una cuenta de WhatsApp activa
- Node.js 18+ (para desarrollo local)

### 1. Clona el Repositorio

```bash
git clone https://github.com/tu-usuario/horoscope-scrapping-to-whatsapp-web.git
cd horoscope-scrapping-to-whatsapp-web
```

### 2. Configuración

```bash
# Copia el template de variables de entorno
cp .env.template .env

# Edita la configuración
nano .env
```

**Configuración esencial en `.env`:**

```bash
# Número de WhatsApp del destinatario (¡IMPORTANTE!)
RECIPIENT_PHONE=5491123456789@c.us

# Hora de envío (formato 24h)
SEND_TIME=08:00

# Zona horaria
TZ=America/Mexico_City
```

### 3. Preparar Directorios

```bash
# Crear directorios para datos persistentes
mkdir -p data/wwebjs_auth data/logs
```

### 4. Ejecutar con Docker Compose

```bash
# Construir e iniciar el contenedor
docker-compose up -d

# Ver logs para obtener el código QR
docker-compose logs -f horoscope-bot
```

### 5. Escanear Código QR

1. Observa los logs del contenedor
2. Aparecerá un código QR en la consola
3. Abre WhatsApp en tu teléfono
4. Ve a **Configuración > Dispositivos vinculados > Vincular dispositivo**
5. Escanea el código QR mostrado en los logs

### 6. ¡Listo!

Una vez vinculado, el bot:

- Enviará un mensaje de prueba (si `SEND_ON_STARTUP=true`)
- Programará el envío diario automático
- Mantendrá la sesión activa entre reinicios

## 📁 Estructura Completa del Proyecto

### 🌳 Árbol de Directorios

```
horoscope-scrapping-to-whatsapp-web/
├── 📄 README.md                          # Documentación principal
├── 📄 K3S-DEPLOYMENT.md                  # Guía específica para k3s
├── 📄 package.json                       # Dependencias Node.js
├── 📄 .gitignore                         # Archivos a ignorar en Git
│
├── 🚀 APLICACIÓN PRINCIPAL
├── 📄 index.js                           # Bot principal - Punto de entrada
├── 📄 healthcheck.js                     # Servidor de health checks
├── 📄 test-scraper.js                    # Script de pruebas de scraping
│
├── ⚙️ CONFIGURACIÓN
├── 📄 .env.template                      # Template de variables de entorno
├── 📄 .env                              # Variables de entorno (NO en Git)
│
├── 🐳 DOCKER
├── 📄 Dockerfile                         # Imagen Docker principal
├── 📄 docker-compose.yml                 # Orquestación Docker Compose
│
├── ☸️ KUBERNETES - ESTÁNDAR
├── 📄 k8s-deployment.yaml                # Deployment para K8s estándar
│
├── ☸️ KUBERNETES - K3S
├── 📄 k3s-deployment.yaml                # Deployment para k3s con PVCs
│
├── 🔧 SCRIPTS DE AUTOMATIZACIÓN
├── 📄 quick-start.sh                     # Setup inicial automático
├── 📄 deploy-k3s.sh                      # Deploy automático en k3s
├── 📄 check-k3s-storage.sh               # Verificar storage k3s
│
├── 📂 data/                              # Datos persistentes (Docker)
│   ├── 📂 wwebjs_auth/                   # Sesión WhatsApp (automático)
│   └── 📂 logs/                          # Logs de mensajes (automático)
│
├── 📂 .wwebjs_auth/                      # Sesión WhatsApp (local)
├── 📂 logs/                              # Logs locales
└── 📂 node_modules/                      # Dependencias (automático)
```

## 📊 **Archivos por Propósito**

| Propósito       | Archivos                                              |
| --------------- | ----------------------------------------------------- |
| **Core App**    | `index.js`, `package.json`                            |
| **Config**      | `.env.template`, `.env`                               |
| **Testing**     | `test-scraper.js`, `healthcheck.js`                   |
| **Docker**      | `Dockerfile`, `docker-compose.yml`                    |
| **k3s**         | `k3s-*.yaml`, `deploy-k3s.sh`, `check-k3s-storage.sh` |
| **K8s**         | `k8s-deployment.yaml`                                 |
| **Setup**       | `quick-start.sh`, `README.md`                         |
| **Maintenance** | `.gitignore`, `K3S-DEPLOYMENT.md`                     |

## 🎯 **Puntos de Entrada**

| Escenario        | Comando                                |
| ---------------- | -------------------------------------- |
| **Docker Local** | `bash quick-start.sh`                  |
| **k3s**          | `bash deploy-k3s.sh`                   |
| **Desarrollo**   | `node index.js`                        |
| **Testing**      | `node test-scraper.js`                 |
| **K8s Estándar** | `kubectl apply -f k8s-deployment.yaml` |

## 🔄 **Ciclo de Vida de Archivos**

### Automáticos (Se crean solos)

- `node_modules/` - npm install
- `.wwebjs_auth/` - Primera ejecución
- `data/wwebjs_auth/` - Docker
- `logs/` - Cuando se envía primer mensaje

### Manuales (Debes crear)

- `.env` - Desde `.env.template`
- Imágenes Docker - `docker build`
- Deployments K8s - `kubectl apply`

### Persistentes (Importantes)

- `.wwebjs_auth/` - **Sesión WhatsApp**
- `data/` - **Datos Docker**
- `logs/` - **Historial mensajes**

## 🛡️ **Archivos Sensibles (.gitignore)**

```
.env                    # Tu configuración real
.wwebjs_auth/          # Sesión WhatsApp
data/                  # Datos Docker
logs/                  # Logs con números de teléfono
node_modules/          # Dependencias
```

## 📱 Formato del Número de WhatsApp

El formato del número de destinatario debe ser: `[código_país][número]@c.us`

**Ejemplos:**

- México: `5212345678901@c.us`
- España: `34612345678@c.us`
- Colombia: `573001234567@c.us`
- Argentina: `5491123456789@c.us`
- Rep. Dominicana: `18291234567@c.us`

## 🐳 Comandos Docker

```bash
# Ver logs en tiempo real
docker-compose logs -f

# Reiniciar el bot
docker-compose restart horoscope-bot

# Parar el servicio
docker-compose down

# Construir y reiniciar
docker-compose up -d --build

# Enviar horóscopo de prueba
docker-compose exec horoscope-bot node index.js --send-now
```

## 🔧 Configuración Avanzada

### Variables de Entorno

| Variable          | Descripción                     | Ejemplo               | Requerido |
| ----------------- | ------------------------------- | --------------------- | --------- |
| `RECIPIENT_PHONE` | Número de WhatsApp destinatario | `5491123456789@c.us`  | ✅        |
| `SEND_TIME`       | Hora de envío diario (24h)      | `08:00`               | ✅        |
| `TZ`              | Zona horaria                    | `America/Mexico_City` | ✅        |
| `SEND_ON_STARTUP` | Enviar al iniciar               | `false`               | ❌        |
| `WEEKLY_ENABLED`  | Resumen semanal                 | `false`               | ❌        |
| `LOG_MESSAGES`    | Guardar logs                    | `true`                | ❌        |
| `HEALTH_PORT`     | Puerto health check             | `3000`                | ❌        |
| `NODE_ENV`        | Ambiente                        | `production`          | ❌        |

### Personalización de Signos

Para cambiar los signos astrológicos, edita el array en `index.js`:

```javascript
this.signs = ["cancer", "acuario"]; // Cambiar según necesidad
```

Signos disponibles: `aries`, `tauro`, `geminis`, `cancer`, `leo`, `virgo`, `libra`, `escorpio`, `sagitario`, `capricornio`, `acuario`, `piscis`

### Cambiar Horario de Envío

```bash
# En .env
SEND_TIME=20:30  # Enviar a las 8:30 PM
```

## 📊 Monitoreo y Salud

### Endpoints de Health Check

```bash
# Salud básica
curl http://localhost:3000/health

# Estado de preparación
curl http://localhost:3000/ready

# Estado detallado
curl http://localhost:3000/status

# Métricas de performance
curl http://localhost:3000/metrics
```

### Logs

```bash
# Ver logs del contenedor
docker-compose logs horoscope-bot

# Logs de mensajes enviados
cat data/logs/horoscope-messages.log
```

## ☸️ Deployment en Kubernetes

### k3s (Recomendado para Single Node)

Si estás usando k3s, usa el deployment específico optimizado:

```bash
# Verificar storage de k3s
bash check-k3s-storage.sh

# Deploy automático en k3s
bash deploy-k3s.sh

# O deploy manual
kubectl apply -f k3s-deployment.yaml
```

Ver [K3S-DEPLOYMENT.md](./K3S-DEPLOYMENT.md) para instrucciones detalladas.

### Kubernetes Estándar

```bash
# 1. Crear Namespace
kubectl create namespace horoscope-bot

# 2. Configurar Secrets
kubectl create secret generic horoscope-config \
  --from-literal=RECIPIENT_PHONE=5491123456789@c.us \
  --from-literal=SEND_TIME=08:00 \
  --from-literal=TZ=America/Mexico_City \
  -n horoscope-bot

# 3. Aplicar Manifests
kubectl apply -f k8s-deployment.yaml

# 4. Obtener Código QR
kubectl logs -f deployment/horoscope-bot -n horoscope-bot
```

## 🔍 Troubleshooting

### Problemas Comunes

**1. No aparece el código QR**

```bash
# Verificar logs
docker-compose logs horoscope-bot

# Reiniciar el contenedor
docker-compose restart horoscope-bot
```

**2. Sesión perdida después de reinicio**

```bash
# Verificar que el volumen existe
ls -la data/wwebjs_auth/

# Verificar permisos
sudo chown -R 1000:1000 data/
```

**3. Error de formato de número**

```bash
# Verificar formato correcto
RECIPIENT_PHONE=5491123456789@c.us  # ✅ Correcto
RECIPIENT_PHONE=+5491123456789      # ❌ Incorrecto
```

**4. Puppeteer no funciona en Docker**

```bash
# Verificar que el contenedor tenga las dependencias
docker-compose exec horoscope-bot node -e "console.log('Puppeteer OK')"
```

### Debugging

```bash
# Modo debug con logs detallados
NODE_ENV=development docker-compose up

# Ejecutar comandos dentro del contenedor
docker-compose exec horoscope-bot bash

# Probar scraping manual
docker-compose exec horoscope-bot node -e "
const bot = require('./index.js');
// Código de prueba
"
```

## 🔐 Seguridad

### Mejores Prácticas

1. **Nunca compartir la sesión de WhatsApp**
2. **Usar volúmenes seguros para datos persistentes**
3. **Limitar acceso de red del contenedor**
4. **Rotar credenciales regularmente**
5. **Monitorear logs por actividad sospechosa**

### Configuración de Firewall

```bash
# Permitir solo puerto de health check
sudo ufw allow 3000/tcp
```

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Por favor:

1. Fork el repositorio
2. Crea una feature branch
3. Commit tus cambios
4. Push a la branch
5. Abre un Pull Request

### Desarrollo Local

```bash
# Instalar dependencias
npm install

# Ejecutar en modo desarrollo
npm run dev

# Ejecutar pruebas
npm test
```

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 💖 Agradecimientos

- [whatsapp-web.js](https://github.com/pedroslopez/whatsapp-web.js) - Biblioteca principal de WhatsApp Web
- [Lecturas.com](https://www.lecturas.com/horoscopo/) - Fuente de horóscopos de calidad
- [Puppeteer](https://github.com/puppeteer/puppeteer) - Web scraping automation

---

_Hecho con ❤️ para enviar amor diario a través de las estrellas_ ✨

**¿Problemas o sugerencias?** Abre un issue en GitHub o contacta al mantenedor.

### Enlaces Útiles

- [Documentación de WhatsApp Web.js](https://wwebjs.dev/)
- [Guía de Docker](https://docs.docker.com/)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)
