# 🗝️ HashiCorp Vault — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**Vault** es una plataforma de gestión centralizada de secretos que permite almacenar, generar dinámicamente y controlar el acceso a credenciales, claves de cifrado y certificados, con auditoría completa de acceso. Se basa en el modelo de **sellado/desellado (seal/unseal)** mediante **Shamir's Secret Sharing** (la clave maestra se divide en fragmentos, requiriendo un umbral mínimo de fragmentos distintos para reconstruirla) y en **secretos dinámicos** con tiempo de vida (TTL) limitado, generados bajo demanda para cada consumidor.

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/vault.d/vault.hcl` | Configuración del servidor (storage backend, listener, TLS). |
| `/opt/vault/data/` | Almacenamiento persistente del backend `raft` (si se usa integrado). |
| `~/.vault-token` | Token de sesión de la CLI del usuario actual. |
| `/var/log/vault_audit.log` | Log de auditoría (requiere habilitar explícitamente el dispositivo de auditoría). |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Gestión del ciclo de vida del servidor" linenums="1"
vault operator init                                    # Inicializar Vault (una sola vez en su vida)
vault operator unseal <clave>                          # Desellar (requiere threshold de claves)
vault status                                            # Estado: sellado/desellado, version, HA
vault login <token>                                     # Autenticarse con la CLI
```

```bash title="Gestión de secretos" linenums="1"
vault secrets enable -path=secret kv-v2                # Habilitar motor de secretos KV version 2
vault kv put secret/app/config usuario=admin password=xxx   # Escribir un secreto estatico
vault kv get secret/app/config                          # Leer un secreto
vault kv metadata get secret/app/config                 # Ver metadatos y versiones
vault read database/creds/rol-app-web                   # Obtener credenciales dinamicas
vault lease revoke <lease_id>                            # Revocar manualmente un secreto dinamico antes de su TTL
```

```bash title="Auditoría y políticas de acceso" linenums="1"
vault audit enable file file_path=/var/log/vault_audit.log
vault policy write app-policy politica.hcl
vault token create -policy="app-policy" -ttl=1h
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- Habilitar siempre el dispositivo de auditoría (`vault audit enable`); sin él no hay trazabilidad de quién accedió a qué secreto y cuándo.
- Distribuir las claves de sellado (Shamir) entre custodios físicamente distintos e independientes, auditando periódicamente que la distribución real cumple el diseño (principio de control dual).
- Preferir **secretos dinámicos** (bases de datos, cloud providers) sobre secretos estáticos siempre que el backend lo soporte, minimizando la ventana de exposición ante filtración.
- Configurar TLS obligatorio en el listener (`tls_cert_file`/`tls_key_file` desde la PKI corporativa, UD1); nunca exponer la API de Vault sin cifrar.
- Aplicar el principio de mínimo privilegio en las políticas (`policy write`) — cada aplicación/servicio debe tener acceso exclusivamente a los secretos que necesita.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Vault permanece sellado tras reinicio | `vault status`, `vault operator unseal` | Comportamiento esperado; requiere desellado manual (o auto-unseal con KMS externo configurado). |
| Aplicación no puede leer un secreto | `vault token capabilities <token> <ruta>` | Política asociada al token no otorga permiso de lectura sobre esa ruta. |
| Credencial dinámica deja de funcionar antes de lo esperado | `vault lease revoke` reciente o `default_ttl` alcanzado | TTL expirado; la aplicación debe solicitar credenciales nuevas, no reutilizar las antiguas. |
| Auditoría no registra eventos | `vault audit list` | Dispositivo de auditoría no habilitado o mal configurado. |

Escalar como incidente crítico cualquier intento de acceso a secretos fuera del patrón habitual de la política asociada (ej. una aplicación intentando leer rutas de otro servicio), visible en el log de auditoría como un "permission denied" repetido y anómalo.
