# 🚫 Fail2ban — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**Fail2ban** es un framework de prevención de intrusiones que analiza logs de servicios (SSH, Nginx, Postfix, etc.) en busca de patrones de fallo repetidos (autenticación fallida, escaneo de rutas inexistentes) y aplica bloqueos temporales a nivel de firewall (integración nativa con `nftables`/`iptables`) sobre las IPs origen. Actúa como capa de mitigación reactiva complementaria al bastionado preventivo (UD6) y al filtrado perimetral (UD3).

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/fail2ban/jail.local` | Configuración local de "jails" (no modificar `jail.conf` directamente). |
| `/etc/fail2ban/filter.d/` | Expresiones regulares que definen qué constituye un "fallo" por servicio. |
| `/etc/fail2ban/action.d/` | Acciones a ejecutar al banear (integración nftables/iptables/notificación). |
| `/var/log/fail2ban.log` | Registro de baneos y desbaneos aplicados. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```ini title="/etc/fail2ban/jail.local (ejemplo de jail SSH)" linenums="1"
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 4
findtime = 600
bantime = 3600
bantime.increment = true
bantime.factor = 4
banaction = nftables-multiport

[nginx-botsearch]
enabled = true
port = http,https
filter = nginx-botsearch
logpath = /var/log/nginx/access.log
maxretry = 10
bantime = 86400
```

```bash title="Gestión operativa" linenums="1"
fail2ban-client status                      # Ver jails activas
fail2ban-client status sshd                 # Detalle de una jail: IPs baneadas, contadores
fail2ban-client set sshd unbanip 203.0.113.5   # Desbanear manualmente una IP
fail2ban-client set sshd banip 203.0.113.9     # Banear manualmente una IP
fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf   # Probar un filtro contra el log real
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- `bantime.increment = true` con `bantime.factor` progresivo: cada reincidencia de la misma IP incrementa el tiempo de baneo exponencialmente, disuadiendo ataques persistentes.
- Usar `banaction = nftables-multiport` para integración nativa con el firewall del sistema (UD3), evitando reglas duplicadas o inconsistentes entre iptables/nftables.
- Aplicar jails específicas para cada servicio expuesto (SSH, WAF/Nginx, correo), no solo SSH.
- Establecer una lista blanca (`ignoreip`) para redes de administración de confianza, evitando bloqueos accidentales del propio equipo de SecOps.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Fail2ban no banea pese a fallos evidentes | `fail2ban-regex <logpath> <filter>` | Expresión regular del filtro no coincide con el formato real del log. |
| IP legítima bloqueada accidentalmente | `fail2ban-client set <jail> unbanip <IP>` | Ausencia de `ignoreip` para redes internas de confianza. |
| Jail no arranca | `systemctl status fail2ban`, `journalctl -u fail2ban` | Error de sintaxis en `jail.local` o filtro referenciado inexistente. |
| Bloqueos no persisten tras reinicio | Revisar `banaction` y persistencia de reglas nftables | Configuración de banaction incompatible con el motor de firewall activo. |

Escalar como incidente cualquier IP que acumule baneos repetidos en múltiples jails simultáneamente (SSH + WAF + correo), indicativo de un actor realizando reconocimiento activo y sistemático contra múltiples servicios de la organización.
