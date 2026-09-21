# 🔄 Keepalived — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**Keepalived** implementa el protocolo **VRRP (Virtual Router Redundancy Protocol, RFC 5798)** en Linux, permitiendo que dos o más nodos compartan una **IP Virtual (VIP)** con conmutación automática por fallo (failover). Es la solución estándar para eliminar el punto único de fallo de balanceadores de carga (HAProxy/Nginx) y routers/gateways redundantes.

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/keepalived/keepalived.conf` | Configuración principal (instancias VRRP, scripts de verificación). |
| `/etc/keepalived/scripts/` | Ubicación recomendada para scripts de `vrrp_script` personalizados. |
| `/var/log/syslog` (facility daemon) | Registro de transiciones de estado MASTER/BACKUP/FAULT. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Gestión del servicio" linenums="1"
systemctl restart keepalived
journalctl -u keepalived -f                      # Seguimiento en vivo de transiciones de estado
ip addr show eth0 | grep <VIP>                    # Verificar si el nodo local posee la VIP actualmente
```

```bash title="Diagnóstico de tráfico VRRP" linenums="1"
tcpdump -i eth1 vrrp -n                           # Capturar anuncios VRRP en la interfaz de heartbeat
tcpdump -i eth1 host 224.0.0.18 -n                # Si se usa multicast (por defecto) en lugar de unicast
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- Habilitar siempre `authentication` con `auth_pass` robusta para mitigar inyección de anuncios VRRP falsos.
- Usar `unicast_src_ip`/`unicast_peer` en entornos cloud donde el multicast puede no estar soportado.
- Aislar el tráfico VRRP en una interfaz/VLAN de heartbeat dedicada, separada del tráfico de producción, para reducir riesgo de split-brain por saturación de red.
- Configurar `vrrp_script` que valide el **estado funcional real** del servicio protegido, no solo la existencia del proceso.
- Definir `notify_master`/`notify_backup`/`notify_fault` para integrar alertas automáticas al SIEM (UD8) en cada transición de estado.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Ambos nodos se creen MASTER (split-brain) | `journalctl -u keepalived` en ambos nodos + `tcpdump vrrp` | Pérdida de conectividad en el canal de heartbeat. |
| Failover no ocurre pese a fallo del servicio | Revisar vinculación `track_script` ↔ `vrrp_script` | Script de verificación no detecta el fallo real del servicio. |
| VIP no responde en ningún nodo | `ip addr show` en ambos nodos | Ambos en estado `FAULT`; revisar script de verificación y logs. |
| Conmutaciones frecuentes sin causa aparente (flapping) | Revisar `interval`/`fall`/`rise` del `vrrp_script` | Umbrales de verificación demasiado sensibles a fallos transitorios. |

Escalar como incidente cualquier transición a estado `FAULT` en ambos nodos simultáneamente, o cualquier anuncio VRRP detectado desde una IP de origen no perteneciente al clúster autorizado (indicativo de suplantación).
