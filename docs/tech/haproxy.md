# ⚖️ HAProxy — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**HAProxy** (High Availability Proxy) es un balanceador de carga y proxy inverso de alto rendimiento, operando tanto en **capa 4** (TCP, sin inspección de contenido) como en **capa 7** (HTTP/HTTPS, con enrutado por contenido, cabeceras, cookies). Es el estándar de facto en infraestructuras de alta disponibilidad Linux por su bajo consumo de recursos y robustez event-driven.

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/haproxy/haproxy.cfg` | Configuración principal (global, defaults, frontends, backends). |
| `/run/haproxy/admin.sock` | Socket Unix de administración en caliente (Runtime API). |
| `/var/log/haproxy.log` | Log de acceso y eventos (requiere configurar `rsyslog`). |
| `/etc/rsyslog.d/49-haproxy.conf` | Redirección de logs HAProxy a fichero dedicado vía syslog local0/local1. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Validación y recarga" linenums="1"
haproxy -c -f /etc/haproxy/haproxy.cfg          # Validar sintaxis sin aplicar
systemctl reload haproxy                        # Recarga sin cortar conexiones activas (soft-reload)
```

```bash title="Runtime API vía socket de administración" linenums="1"
echo "show info" | socat stdio /run/haproxy/admin.sock
echo "show stat" | socat stdio /run/haproxy/admin.sock
echo "show servers state" | socat stdio /run/haproxy/admin.sock
echo "set server backend_web/web1 state maint" | socat stdio /run/haproxy/admin.sock   # Drenar para mantenimiento
echo "set server backend_web/web1 state ready" | socat stdio /run/haproxy/admin.sock   # Reincorporar al pool
echo "set server backend_web/web1 weight 20" | socat stdio /run/haproxy/admin.sock     # Cambiar peso en caliente
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- Restringir el panel `stats` a redes de administración mediante ACL de firewall y credenciales robustas (nunca expuesto a Internet sin control adicional).
- Forzar `ssl-min-ver TLSv1.2` y cifrados AEAD en `ssl-default-bind-options`/`ssl-default-bind-ciphers`.
- Configurar `timeout connect`/`timeout client`/`timeout server` explícitos — valores por defecto ausentes exponen a agotamiento de recursos (slow-loris).
- Health checks (`option httpchk`) que verifiquen dependencias reales del backend, no solo disponibilidad del puerto.
- Ajustar `fall`/`rise` según la variabilidad de latencia real del entorno para evitar flapping de backends sanos.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Backend marcado `DOWN` incorrectamente | `echo "show servers state" \| socat stdio /run/haproxy/admin.sock` | Health check demasiado estricto en timeout o endpoint incorrecto. |
| Código 503 al cliente | Revisar `backend` correspondiente en `show stat` | Todos los servidores del backend caídos o `maxconn` global alcanzado. |
| Recarga de configuración falla | `haproxy -c -f /etc/haproxy/haproxy.cfg` | Error de sintaxis en el fichero de configuración. |
| Sesiones de usuario inconsistentes | Revisar algoritmo `balance` configurado | Ausencia de sticky sessions con aplicación sin estado compartido. |

Escalar como incidente cualquier caída simultánea de todos los servidores de un backend crítico, dado que puede tratarse de un ataque de denegación de servicio dirigido en lugar de un fallo de infraestructura aislado.
