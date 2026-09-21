# 🧩 Corosync & Pacemaker — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**Corosync** es la capa de mensajería y membresía de clúster (comunicación de heartbeat, gestión de quórum) sobre la que opera **Pacemaker**, el motor de gestión de recursos (Cluster Resource Manager) que decide dónde y cuándo arrancar, detener o migrar recursos (VIPs, sistemas de ficheros, bases de datos, servicios) en función de reglas de dependencia, orden y ubicación (`constraints`).

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/corosync/corosync.conf` | Configuración de membresía y transporte del clúster. |
| `/var/lib/pacemaker/cib/cib.xml` | Base de información del clúster (Cluster Information Base) — no editar directamente, usar `pcs`. |
| `/var/log/pacemaker/pacemaker.log` | Log detallado de decisiones del motor de recursos. |
| `/var/log/cluster/corosync.log` | Log de membresía y comunicación de bajo nivel. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Gestión del clúster con pcs" linenums="1"
pcs cluster start --all                          # Arrancar el clúster en todos los nodos
pcs status                                        # Estado general: nodos, recursos, fallos
pcs resource show                                 # Listar recursos gestionados
pcs resource move <recurso> <nodo_destino>        # Migrar un recurso manualmente
pcs resource cleanup <recurso>                    # Limpiar el historial de fallos de un recurso
pcs constraint list --full                        # Ver todas las restricciones de orden/ubicación
pcs stonith status                                # Verificar el estado del mecanismo de fencing
crm_mon -1                                        # Vista de estado alternativa (tiempo real con -r)
```

```bash title="Diagnóstico de quórum" linenums="1"
corosync-quorumtool -s                            # Estado del quórum del clúster
corosync-cfgtool -s                                # Estado de los anillos de comunicación (rings)
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- **STONITH/fencing siempre habilitado en producción** (`stonith-enabled=true`); deshabilitarlo solo es aceptable en laboratorio.
- Configurar `two_node: 1` en `quorum` solo en clústeres de exactamente 2 nodos, entendiendo sus implicaciones especiales de quórum (requiere fencing fiable para evitar split-brain, ya que no hay "voto de desempate" natural).
- Definir explícitamente `constraint order` y `constraint colocation` para todo recurso con dependencias, evitando arranques en secuencia incorrecta.
- Aislar la red de Corosync (`bindnetaddr`) en una VLAN de heartbeat dedicada, igual que Keepalived.
- Auditar regularmente `pcs constraint list` tras cualquier cambio de infraestructura para detectar reglas obsoletas o contradictorias.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Recurso no arranca en ningún nodo | `pcs status` (revisar "Failed Actions"), `pcs resource cleanup` | Fallo previo no limpiado bloqueando reintentos automáticos. |
| Clúster sin quórum | `corosync-quorumtool -s` | Nodos insuficientes activos o partición de red. |
| Fencing no se ejecuta ante nodo caído | `pcs stonith status`, revisar configuración del dispositivo STONITH | Dispositivo de fencing (IPMI/iLO) mal configurado o inaccesible. |
| Recurso migra constantemente entre nodos | `pcs resource show --full`, revisar `constraints` y health del recurso | Configuración de monitorización demasiado sensible o recurso realmente inestable. |

Escalar como incidente crítico cualquier pérdida de quórum en producción, dado que Pacemaker detendrá la gestión activa de recursos por diseño de seguridad ante la imposibilidad de garantizar consistencia sin mayoría de nodos.
