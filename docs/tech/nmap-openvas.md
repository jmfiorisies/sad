# 🔍 Nmap & OpenVAS/Greenbone — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**Nmap** (Network Mapper) es la herramienta de referencia para descubrimiento de hosts, escaneo de puertos y fingerprinting de servicios/sistema operativo, extensible mediante el **NSE (Nmap Scripting Engine)** para detección de vulnerabilidades específicas. **OpenVAS/Greenbone** es un escáner de vulnerabilidades de propósito general que mantiene una base de datos de **NVTs (Network Vulnerability Tests)** actualizada, capaz de realizar escaneos autenticados y correlacionar hallazgos con CVEs y puntuación CVSS.

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/usr/share/nmap/scripts/` | Repositorio de scripts NSE instalados. |
| `/etc/nmap/nmap-services` | Base de datos de servicios/puertos conocidos usada por Nmap. |
| `~/.msf4/` | Directorio de configuración y workspaces de Metasploit Framework. |
| Interfaz web Greenbone (`https://<host>/`) | Gestión de Targets, Tasks, Scan Configs e informes de OpenVAS. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Nmap - escaneos de referencia" linenums="1"
nmap -sn 10.10.10.0/24                       # Descubrimiento de hosts (ping scan)
nmap -sS -Pn -p- 10.10.10.50                  # Escaneo SYN completo, sin ping previo
nmap -sV --version-intensity 5 10.10.10.50    # Deteccion de version con maxima precision
nmap -O 10.10.10.50                           # Fingerprinting de sistema operativo
nmap --script "default,safe" 10.10.10.50      # Scripts NSE seguros por defecto
nmap --script vuln 10.10.10.50                # Scripts orientados a deteccion de vulnerabilidades
nmap -A -T4 10.10.10.50                       # Modo agresivo: OS, version, scripts, traceroute
```

```bash title="OpenVAS/GVM via CLI (gvm-tools)" linenums="1"
gvm-cli socket --xml "<get_version/>"                     # Verificar version del feed
gvm-cli socket --xml "<get_tasks/>"                       # Listar tareas de escaneo
gvm-cli socket --xml "<start_task task_id='<ID>'/>"       # Lanzar una tarea programaticamente
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- Ejecutar siempre bajo autorización explícita (RoE firmado); registrar origen, alcance y ventana horaria de cada escaneo.
- Ajustar la plantilla de temporización (`-T2`/`-T3`) en sistemas de producción para evitar denegación de servicio accidental.
- Preferir escaneos **autenticados** en OpenVAS cuando sea posible, para reducir falsos positivos y falsos negativos.
- Mantener el feed de NVTs/CVEs actualizado (`greenbone-feed-sync`) — un feed desactualizado invalida la fiabilidad del escaneo frente a vulnerabilidades recientes.
- Almacenar los informes de auditoría cifrados y con acceso restringido: contienen un mapa detallado de las debilidades de la organización.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Escaneo Nmap devuelve todos los puertos `filtered` | `nmap -Pn ...` (omitir descubrimiento previo) | Firewall bloqueando ICMP/discovery; usar `-Pn` para forzar escaneo directo. |
| OpenVAS no detecta vulnerabilidades conocidas | Verificar fecha del feed (`greenbone-feed-sync --type SCAP`) | Feed de NVTs desactualizado. |
| Falso positivo por versión de servicio backport | Verificar changelog del paquete/distribución manualmente | Escáner basado en número de versión sin considerar backports de seguridad. |
| Tarea OpenVAS se queda en "Requested" indefinidamente | Revisar logs del contenedor/servicio `gvmd`/`ospd-openvas` | Recursos insuficientes o feed aún sincronizando. |

Escalar como incidente cualquier ejecución de escaneo detectada que no figure en el calendario de auditorías autorizadas — puede tratarse de reconocimiento activo por parte de un atacante real, no de una prueba planificada.
