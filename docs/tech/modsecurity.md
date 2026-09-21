# 🛡️ ModSecurity & OWASP CRS — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**ModSecurity** es un motor de Web Application Firewall (WAF) embebido como módulo en Nginx, Apache o IIS, que evalúa peticiones/respuestas HTTP contra un conjunto de reglas declarativas. El **OWASP Core Rule Set (CRS)** es el conjunto de reglas de referencia, mantenido por la comunidad OWASP, que cubre las categorías del **OWASP Top 10** (inyección SQL, XSS, path traversal, RCE, etc.) mediante un sistema de puntuación de anomalías configurable por niveles de "paranoia".

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/nginx/modsec/modsecurity.conf` | Configuración base del motor (motor activado, límites, logging). |
| `/etc/nginx/modsec/coreruleset/crs-setup.conf` | Parámetros globales del CRS (paranoia level, umbrales de anomalía). |
| `/etc/nginx/modsec/coreruleset/rules/*.conf` | Reglas del CRS organizadas por categoría de ataque. |
| `/var/log/modsec_audit.log` | Log de auditoría detallado de peticiones evaluadas/bloqueadas. |
| `/var/cache/modsecurity/` | Directorio de datos persistentes del motor (colecciones). |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Validación y pruebas" linenums="1"
nginx -t                                              # Validar sintaxis global (incluye directivas modsecurity)
tail -f /var/log/modsec_audit.log                     # Seguimiento en vivo del log de auditoría

# Prueba manual de deteccion de SQLi
curl "https://app.dominio.local/buscar?q=1' UNION SELECT NULL--"

# Prueba manual de deteccion de XSS
curl "https://app.dominio.local/comentario?texto=<script>alert(1)</script>"
```

```apache title="Exclusiones de reglas (tuning) por ID especifico" linenums="1"
# Excluir una regla concreta solo para un parametro determinado (NUNCA global sin justificacion)
SecRuleUpdateTargetById 942100 "!ARGS:comentarios_libres"

# Deshabilitar una regla completa (usar con extrema cautela y documentar el motivo)
SecRuleRemoveById 920350
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- `SecRuleEngine On` (nunca `DetectionOnly` en producción, salvo fase de ajuste temporal documentada).
- Empezar en Paranoia Level 1 (PL1); escalar solo tras periodo de tuning sin falsos positivos críticos.
- `SecAuditLogRelevantStatus` limitado a códigos de error (4xx/5xx salvo 404) para evitar saturar el log de auditoría.
- Revisar y actualizar el CRS periódicamente (nuevas reglas cubren CVEs y técnicas de evasión recientes).
- Documentar cada exclusión de regla (`SecRuleRemoveById`/`SecRuleUpdateTargetById`) con justificación técnica y fecha de revisión.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Petición legítima bloqueada (403) | `grep -B5 -A30 "<ID_transaccion>" /var/log/modsec_audit.log` | Falso positivo de una regla CRS específica; requiere exclusión dirigida. |
| WAF no bloquea ataques evidentes | `grep SecRuleEngine /etc/nginx/modsec/modsecurity.conf` | Motor en `DetectionOnly` u `Off`. |
| Alto consumo de CPU en el proxy | Revisar `SecRequestBodyLimit` y Paranoia Level | PL demasiado alto para el volumen de tráfico sin dimensionamiento adecuado. |
| Log de auditoría crece sin control | Revisar `SecAuditLogRelevantStatus` | Motor registrando todo el tráfico, no solo el relevante. |

Escalar como incidente cualquier patrón de peticiones bloqueadas que coincida con explotación activa de una categoría OWASP crítica (RCE, deserialización insegura) sostenida en el tiempo, ya que indica un intento de ataque dirigido y no un escaneo automatizado genérico.
