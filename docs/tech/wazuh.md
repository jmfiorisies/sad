# 🦉 Wazuh — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**Wazuh** es una plataforma SIEM/XDR de código abierto, evolución de OSSEC HIDS, compuesta por tres componentes: el **Manager** (recepción, correlación y generación de alertas), el **Indexer** (basado en OpenSearch, almacenamiento y búsqueda de eventos) y el **Dashboard** (visualización). Incluye capacidades de **File Integrity Monitoring (FIM)**, detección de rootkits, análisis de logs, y cumplimiento normativo (CIS, PCI-DSS).

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/var/ossec/etc/ossec.conf` | Configuración principal (manager y agente). |
| `/var/ossec/etc/rules/local_rules.xml` | Reglas de correlación personalizadas. |
| `/var/ossec/etc/decoders/local_decoder.xml` | Decodificadores personalizados para logs no estándar. |
| `/var/ossec/logs/alerts/alerts.json` | Alertas generadas en formato JSON. |
| `/var/ossec/logs/ossec.log` | Log operativo del propio Wazuh. |
| `/var/ossec/queue/syscheck/` | Base de datos de estado del FIM. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Gestión de agentes (desde el manager)" linenums="1"
/var/ossec/bin/agent_control -l                     # Listar agentes y su estado de conexion
/var/ossec/bin/manage_agents                        # Añadir/eliminar agentes, generar claves
/var/ossec/bin/agent_control -R -u <ID_AGENTE>       # Reiniciar un agente remotamente
```

```bash title="Gestión y validación local" linenums="1"
/var/ossec/bin/wazuh-control status                 # Estado de los procesos internos
/var/ossec/bin/wazuh-logtest                         # Probar reglas contra un log de ejemplo manualmente
systemctl restart wazuh-manager                      # Aplicar cambios de reglas/configuracion
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- Habilitar FIM (`<syscheck>`) sobre todos los directorios críticos de configuración de seguridad (firewall, SSH, PKI, WAF).
- Definir reglas de correlación específicas para los TTPs relevantes de la organización, no depender solo del ruleset por defecto.
- Cifrar la comunicación agente-manager (`protocol tcp` con autenticación por clave/certificado, no dejar el puerto 1514 sin cifrar en redes no confiables).
- Monitorizar activamente el estado de conexión de los agentes; un agente desconectado sin justificación es un IOC.
- Ajustar niveles de alerta (`level`) y agrupar eventos relacionados para evitar fatiga de alertas del equipo SOC.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Agente no conecta con el manager | `/var/ossec/bin/agent_control -l`, revisar firewall puerto 1514 | Firewall bloqueando el puerto o clave de registro incorrecta. |
| Regla personalizada no dispara | `/var/ossec/bin/wazuh-logtest` con el log de ejemplo | Error de sintaxis XML o condición de la regla mal definida. |
| FIM no detecta cambios | Revisar `<frequency>` en `<syscheck>` | Intervalo de escaneo demasiado largo para el caso de uso. |
| Dashboard sin datos recientes | Revisar estado del Indexer (`systemctl status wazuh-indexer`) | Servicio OpenSearch caído o disco lleno. |

Escalar como incidente prioritario cualquier desconexión no planificada de agentes en servidores críticos (PKI, firewall, KDC), dado que puede indicar un intento deliberado de evadir la monitorización antes de una acción maliciosa.
