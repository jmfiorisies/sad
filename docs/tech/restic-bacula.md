# 💾 Restic & Bacula — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**Restic** es una herramienta de backup moderna de código abierto, cifrado extremo a extremo (AES-256), deduplicación de bloques y soporte nativo para múltiples backends (local, SFTP, S3-compatible, Azure, Backblaze B2). **Bacula** es una solución de backup empresarial cliente-servidor (Director, Storage Daemon, File Daemon) orientada a entornos con múltiples clientes, gestión de cintas (LTO) y políticas de retención complejas mediante Pools y Schedules.

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/restic/password.txt` | Fichero con la contraseña de cifrado del repositorio (permisos `600`). |
| `~/.cache/restic/` | Caché local de metadatos del repositorio. |
| `/etc/bacula/bacula-dir.conf` | Configuración del Director (Jobs, Schedules, Pools, Clients). |
| `/etc/bacula/bacula-sd.conf` | Configuración del Storage Daemon (dispositivos de almacenamiento/cinta). |
| `/etc/bacula/bacula-fd.conf` | Configuración del File Daemon (agente en cada cliente respaldado). |
| `/var/lib/bacula/` | Catálogo y bootstraps de Bacula. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Restic" linenums="1"
restic init                                          # Inicializar repositorio nuevo
restic backup /ruta/a/respaldar                      # Ejecutar backup
restic snapshots                                     # Listar snapshots disponibles
restic restore <ID_SNAPSHOT> --target /ruta/destino  # Restaurar un snapshot completo
restic restore latest --target /tmp/r --path /etc    # Restaurar solo una ruta especifica del ultimo snapshot
restic forget --keep-daily 7 --keep-weekly 4 --prune # Aplicar politica de retencion y purgar datos obsoletos
restic check                                          # Verificar integridad criptografica del repositorio
restic check --read-data                              # Verificacion exhaustiva (lee todos los bloques, mas lento)
restic diff <ID_A> <ID_B>                             # Comparar dos snapshots
```

```bash title="Bacula (consola bconsole)" linenums="1"
bconsole
# Dentro de la consola:
status director
run job="Backup-Servidor-Web"
list jobs
restore
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- Almacenar `RESTIC_PASSWORD_FILE` con permisos `600`, nunca la contraseña en variables de entorno visibles en el historial de shell o en scripts sin protección.
- Habilitar Object Lock/WORM (immutable storage) en el backend S3-compatible para al menos una copia, como defensa específica frente a ransomware (regla 3-2-1-1).
- Ejecutar `restic check` (o el equivalente de verificación de catálogo en Bacula) tras cada ciclo completo de backup, no solo confiar en la ausencia de errores durante la ejecución.
- Cifrar el canal de comunicación entre File Daemon y Storage Daemon en Bacula (TLS-PSK) cuando el tráfico de backup cruce redes no confiables.
- Programar pruebas de restauración periódicas documentadas, no solo backups.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| `restic backup` falla con error de repositorio bloqueado | `restic unlock` | Proceso anterior interrumpido dejó un lock huérfano. |
| Repositorio restic crece sin control | `restic forget --prune` no ejecutado regularmente | Política de retención no aplicada tras cada backup. |
| Job de Bacula falla en estado "Error" | `list jobs`, revisar log del Job específico en `bconsole` | Cliente (File Daemon) inaccesible o credenciales/certificado caducado. |
| Restauración incompleta | `restic check --read-data` | Corrupción de bloques no detectada por verificación estándar (rápida). |

Escalar como incidente cualquier fallo sostenido de verificación de integridad (`restic check` o catálogo de Bacula) durante más de un ciclo, dado que compromete la fiabilidad real de la estrategia de recuperación ante desastres de toda la organización.
