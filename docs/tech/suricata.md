# 🚨 Suricata — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**Suricata** es un motor IDS/IPS/NSM (Network Security Monitoring) de código abierto, multihilo, compatible con reglas en formato Snort/ET (Emerging Threats). Puede operar en modo pasivo (`af-packet`, IDS) o inline (`NFQUEUE`/`AF_PACKET IPS mode`, bloqueo activo). Genera salida estructurada **EVE JSON**, el formato estándar de facto para ingesta en SIEMs modernos (ver UD8).

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/suricata/suricata.yaml` | Configuración principal (interfaces, variables de red, outputs). |
| `/var/lib/suricata/rules/` | Conjunto de reglas activas (`suricata.rules`, `local.rules`). |
| `/var/log/suricata/eve.json` | Log estructurado de alertas, flujos, DNS, TLS, HTTP. |
| `/var/log/suricata/stats.log` | Estadísticas de rendimiento del motor. |
| `/etc/suricata/threshold.config` | Umbrales y supresión de reglas ruidosas. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Gestión y validación" linenums="1"
suricata -T -c /etc/suricata/suricata.yaml -v          # Validar configuración sin arrancar
suricata-update                                          # Actualizar reglas (Emerging Threats Open)
suricata-update list-sources                             # Listar fuentes de reglas disponibles
suricatasc -c "reload-rules"                              # Recargar reglas sin reiniciar el proceso
```

```bash title="Análisis de eventos con jq" linenums="1"
jq 'select(.event_type=="alert")' /var/log/suricata/eve.json
jq 'select(.event_type=="alert") | .alert.signature' /var/log/suricata/eve.json | sort | uniq -c | sort -rn
jq 'select(.event_type=="dns")' /var/log/suricata/eve.json
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- Definir `HOME_NET`/`EXTERNAL_NET` con precisión; un `HOME_NET` mal definido invalida buena parte de la lógica direccional de las firmas.
- Validar en modo IDS puro antes de activar bloqueo inline (IPS) en producción.
- Actualizar el ruleset regularmente (`suricata-update`) — firmas desactualizadas no detectan CVEs recientes.
- Ajustar `threshold.config` para suprimir firmas ruidosas conocidas en el entorno específico, evitando fatiga de alertas (*alert fatigue*).
- Habilitar `defrag: yes` y reensamblado TCP correcto para evitar evasión por fragmentación.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Suricata no arranca | `suricata -T -c /etc/suricata/suricata.yaml -v` | Error de sintaxis YAML o regla mal formada. |
| Alto uso de CPU / paquetes descartados | `cat /var/log/suricata/stats.log \| grep drop` | Insuficientes hilos (`threads: auto`) para el volumen de tráfico. |
| No se generan alertas pese a tráfico sospechoso | Revisar `rule-files` cargados y `suricatasc -c "ruleset-stats"` | Reglas no cargadas o deshabilitadas por `threshold.config`. |
| IPS bloquea tráfico legítimo | `jq 'select(.event_type=="drop")' eve.json` | Falso positivo; requiere excepción específica documentada. |

Escalar como incidente P1 cualquier alerta EVE clasificada como `classtype:trojan-activity` o `command-and-control`, indicativa de compromiso activo con comunicación hacia infraestructura de atacante.
