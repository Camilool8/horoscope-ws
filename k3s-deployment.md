# 🚀 Deployment en k3s

Guía específica para desplegar el Horoscope WhatsApp Bot en k3s con storage local.

## 📋 Prerrequisitos

- k3s instalado y funcionando
- Docker instalado
- kubectl configurado para tu cluster k3s

## 🔧 Verificar k3s Storage

k3s viene con un `local-path` provisioner por defecto que es perfecto para este caso:

```bash
# Verificar storage classes disponibles
kubectl get storageclass

# Deberías ver algo como:
# NAME                   PROVISIONER             RECLAIMPOLICY
# local-path (default)   rancher.io/local-path   Delete
```

## 🚀 Deploy Rápido

### Opción 1: Usando el Script Automático (Recomendado)

```bash
# Deploy con Persistent Volume Claims (recomendado)
bash deploy-k3s.sh

# O deploy con hostPath (alternativo)
bash deploy-k3s.sh hostpath
```

### Opción 2: Deploy Manual

#### 1. Preparar Configuración

```bash
# Copiar template de configuración
cp .env.template .env

# Editar configuración (¡IMPORTANTE!)
nano .env
```

**Configuración mínima en `.env`:**

```bash
RECIPIENT_PHONE=5491123456789@c.us  # Tu número destino
SEND_TIME=08:00
TZ=America/Santo_Domingo
```

#### 2. Construir e Importar Imagen

```bash
# Construir imagen Docker
docker build -t horoscope-whatsapp:latest .

# Importar imagen a k3s (importante para k3s)
docker save horoscope-whatsapp:latest | sudo k3s ctr images import -
```

#### 3. Configurar Secrets

```bash
# Crear namespace
kubectl create namespace horoscope-bot

# Crear secret con configuración
kubectl create secret generic horoscope-config \
  --from-literal=RECIPIENT_PHONE="TU_NUMERO@c.us" \
  --from-literal=SEND_TIME="08:00" \
  --from-literal=TZ="America/Santo_Domingo" \
  --from-literal=SEND_ON_STARTUP="false" \
  --from-literal=WEEKLY_ENABLED="false" \
  --from-literal=LOG_MESSAGES="true" \
  -n horoscope-bot
```

#### 4. Deploy Application

**Con PVCs (Recomendado):**

```bash
kubectl apply -f k3s-deployment.yaml
```

**Con hostPath (Alternativo):**

```bash
# Crear directorios en el nodo
sudo mkdir -p /opt/horoscope-bot/{wwebjs_auth,logs}
sudo chmod 755 /opt/horoscope-bot/{wwebjs_auth,logs}

# Obtener nombre del nodo y aplicar
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
sed "s/NODE_NAME/$NODE_NAME/g" k3s-hostpath-deployment.yaml | kubectl apply -f -
```

## 📱 Obtener Código QR

```bash
# Ver logs del pod para obtener el QR
kubectl logs -f deployment/horoscope-bot -n horoscope-bot

# Busca líneas como:
# 🔗 CÓDIGO QR GENERADO:
# 📱 Escanea este código QR con tu WhatsApp:
# [CÓDIGO QR AQUÍ]
```

## 🔍 Monitoreo y Troubleshooting

### Comandos Útiles

```bash
# Ver estado general
kubectl get all -n horoscope-bot

# Ver logs en tiempo real
kubectl logs -f deployment/horoscope-bot -n horoscope-bot

# Ver eventos del namespace
kubectl get events -n horoscope-bot --sort-by='.lastTimestamp'

# Descripción detallada del pod
kubectl describe pod -l app=horoscope-bot -n horoscope-bot

# Ver PVCs y su estado
kubectl get pvc -n horoscope-bot

# Health check usando port-forward
kubectl port-forward service/horoscope-bot-service 3000:3000 -n horoscope-bot
curl http://localhost:3000/health
```

### Health Checks

```bash
# Health check básico
kubectl run test-pod --rm -i --tty --image=curlimages/curl -- \
  curl http://horoscope-bot-service.horoscope-bot:3000/health

# Estado detallado
kubectl run test-pod --rm -i --tty --image=curlimages/curl -- \
  curl http://horoscope-bot-service.horoscope-bot:3000/status
```

## 🗂️ Ubicación de Datos

### Con PVCs (local-path)

Los datos se almacenan en:

```
/var/lib/rancher/k3s/storage/pvc-[UUID]/
```

### Con hostPath

Los datos se almacenan en:

```
/opt/horoscope-bot/wwebjs_auth/  # Sesión WhatsApp
/opt/horoscope-bot/logs/         # Logs de mensajes
```

## 🔄 Operaciones Comunes

### Reiniciar Bot

```bash
kubectl rollout restart deployment/horoscope-bot -n horoscope-bot
```

### Actualizar Configuración

```bash
# Editar secret
kubectl edit secret horoscope-config -n horoscope-bot

# Reiniciar para aplicar cambios
kubectl rollout restart deployment/horoscope-bot -n horoscope-bot
```

### Actualizar Imagen

```bash
# Construir nueva imagen
docker build -t horoscope-whatsapp:latest .

# Importar a k3s
docker save horoscope-whatsapp:latest | sudo k3s ctr images import -

# Forzar recreación del pod
kubectl rollout restart deployment/horoscope-bot -n horoscope-bot
```

### Backup de Sesión WhatsApp

```bash
# Con PVCs
sudo cp -r /var/lib/rancher/k3s/storage/pvc-*/wwebjs_auth ./backup-wwebjs-auth

# Con hostPath
sudo cp -r /opt/horoscope-bot/wwebjs_auth ./backup-wwebjs-auth
```

## ⚠️ Troubleshooting

### Pod no inicia

```bash
# Ver eventos y logs
kubectl describe pod -l app=horoscope-bot -n horoscope-bot
kubectl logs deployment/horoscope-bot -n horoscope-bot
```

### Problemas de Storage

```bash
# Verificar storage class
kubectl get storageclass

# Ver estado de PVCs
kubectl get pvc -n horoscope-bot

# Verificar permisos (si usas hostPath)
ls -la /opt/horoscope-bot/
```

### Imagen no encontrada

```bash
# Verificar que la imagen esté importada en k3s
sudo k3s ctr images list | grep horoscope

# Re-importar si es necesario
docker save horoscope-whatsapp:latest | sudo k3s ctr images import -
```

### Problemas de Red/Conectividad

```bash
# Verificar conectividad desde el pod
kubectl exec -it deployment/horoscope-bot -n horoscope-bot -- /bin/sh
# Dentro del pod:
curl https://www.lecturas.com/horoscopo/cancer
```

## 🧹 Cleanup

### Eliminar todo

```bash
kubectl delete namespace horoscope-bot
```

### Eliminar datos de storage

```bash
# Si usaste hostPath
sudo rm -rf /opt/horoscope-bot/

# Los PVCs se eliminan automáticamente con el namespace
```

## 📊 Diferencias entre PVC y hostPath

| Aspecto         | PVCs (local-path) | hostPath          |
| --------------- | ----------------- | ----------------- |
| **Setup**       | Automático        | Manual            |
| **Gestión**     | Kubernetes        | Manual            |
| **Backup**      | Más complejo      | Directo           |
| **Migración**   | Limitada          | No aplica         |
| **Limpieza**    | Automática        | Manual            |
| **Recomendado** | ✅ Sí             | Solo para testing |

## 🔐 Consideraciones de Seguridad

- Los volúmenes locales no están encriptados por defecto
- Considera encriptar el storage del nodo si manejas datos sensibles
- Los secrets de Kubernetes están en base64, no encriptados
- Limita el acceso al cluster k3s

## 📈 Monitoreo con Prometheus (Opcional)

Si tienes Prometheus instalado:

```bash
# El ServiceMonitor ya está incluido en k3s-hostpath-deployment.yaml
kubectl get servicemonitor -n horoscope-bot
```

Los endpoints de métricas disponibles:

- `/health` - Health check básico
- `/metrics` - Métricas para Prometheus
- `/status` - Estado detallado

---

¿Problemas? Revisa los logs y verifica la configuración paso a paso. La mayoría de problemas están relacionados con la importación de la imagen Docker o la configuración del número de WhatsApp.
