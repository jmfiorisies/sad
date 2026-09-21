# 🧱 NFTables — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**nftables** es el subsistema de filtrado de paquetes del kernel Linux (sucesor de iptables/ipset/ebtables desde el kernel 3.13, por defecto desde Debian 10/Ubuntu 18.04+). Se estructura en **tablas** (`table`), **cadenas** (`chain`) enganchadas a *hooks* del kernel (`prerouting`, `input`, `forward`, `output`, `postrouting`) y **reglas** evaluadas secuencialmente dentro de cada cadena. Su motor de **conjuntos (`sets`)** con estructuras hash permite escalar a miles de reglas sin degradación lineal de rendimiento.

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/nftables.conf` | Fichero principal de reglas, cargado al arranque por el servicio `nftables.service`. |
| `/etc/sysctl.d/*.conf` | Parámetros de kernel complementarios (forwarding, anti-spoofing). |
| `/var/log/kern.log` | Registro de paquetes marcados con `log` en las reglas. |
| `/proc/net/nf_conntrack` | Tabla de seguimiento de conexiones en tiempo real. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Gestión básica" linenums="1"
nft list ruleset                       # Ver ruleset completo activo
nft list ruleset -a                    # Con handles y contadores por regla
nft -f /etc/nftables.conf              # Cargar/recargar ruleset completo (atomico)
nft flush ruleset                      # Vaciar todo el ruleset (¡cuidado en producción!)

nft add table inet filter
nft add chain inet filter input '{ type filter hook input priority 0; policy drop; }'
nft add rule inet filter input tcp dport 22 accept

nft delete rule inet filter input handle <N>   # Borrar regla por handle
```

```bash title="Gestión de sets dinámicos" linenums="1"
nft add set inet filter blacklist '{ type ipv4_addr; flags interval; timeout 1h; }'
nft add element inet filter blacklist { 203.0.113.50 }
nft delete element inet filter blacklist { 203.0.113.50 }
nft list set inet filter blacklist
```

```bash title="Diagnóstico de conntrack" linenums="1"
conntrack -L                           # Listar conexiones activas rastreadas
conntrack -L -p tcp --dport 443        # Filtrar por puerto
conntrack -D -s 203.0.113.50           # Eliminar entradas de una IP concreta
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- Política por defecto `drop` en `input` y `forward`; nunca `accept` (principio de mínimo privilegio, *default deny*).
- Descarte explícito de `ct state invalid` antes de cualquier regla de aceptación.
- Segmentación DMZ/LAN con reglas de aislamiento explícitas en ambos sentidos, nunca solo unidireccional.
- `limit rate` en reglas de logging para evitar saturación de disco por flood de paquetes descartados.
- Combinar con `sysctl` anti-spoofing (`rp_filter`, `accept_source_route=0`) — el firewall de capa 4 no sustituye el hardening de pila TCP/IP del kernel.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Servicio inaccesible tras aplicar reglas | `nft list ruleset -a` (revisar contadores) | Regla de bloqueo evaluada antes de la de aceptación (orden importa). |
| Recarga falla con error de sintaxis | `nft -c -f /etc/nftables.conf` (modo check) | Error tipográfico o variable `define` no declarada. |
| NAT no funciona | `sysctl net.ipv4.ip_forward` | Forwarding deshabilitado a nivel de kernel. |
| Conexiones se cortan tras un tiempo | `conntrack -L \| wc -l` vs `sysctl net.netfilter.nf_conntrack_max` | Tabla de conntrack llena, se necesitan más entradas o tiempos de timeout menores. |

Escalar como incidente cualquier modificación no planificada de la política por defecto de las cadenas `input`/`forward` a `accept`, ya que anula el modelo de seguridad perimetral completo.
