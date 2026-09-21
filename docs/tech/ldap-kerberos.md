# 🔑 OpenLDAP & Kerberos — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**OpenLDAP** implementa el protocolo **LDAPv3 (RFC 4511)** como servicio de directorio jerárquico para almacenar identidades, grupos y atributos organizacionales. **Kerberos v5 (RFC 4120)** es un protocolo de autenticación de terceros de confianza (*trusted third party*) basado en tickets cifrados con clave simétrica, diseñado para evitar la transmisión de contraseñas por la red y habilitar **Single Sign-On (SSO)**.

Ambos servicios se combinan habitualmente: Kerberos autentica, LDAP autoriza/almacena. Active Directory de Microsoft es, de hecho, una implementación integrada de ambos protocolos.

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/ldap/slapd.d/` | Configuración dinámica (cn=config) de OpenLDAP moderno. |
| `/etc/default/slapd` | Variables de arranque del demonio (`SLAPD_SERVICES`, puertos). |
| `/var/lib/ldap/` | Base de datos del directorio (backend `mdb`). |
| `/etc/krb5.conf` | Configuración cliente Kerberos (realm, KDC, cifrados soportados). |
| `/etc/krb5kdc/kdc.conf` | Configuración del KDC (Key Distribution Center). |
| `/etc/krb5kdc/kadm5.acl` | Control de acceso administrativo sobre principals. |
| `/etc/sssd/sssd.conf` | Integración cliente unificada LDAP+Kerberos (`sssd`). |
| `/var/log/krb5kdc.log` | Log de emisión de tickets TGT/TGS. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="OpenLDAP" linenums="1"
# Búsqueda autenticada
ldapsearch -x -H ldaps://kdc-ldap-server -D "cn=admin,dc=asir-corp,dc=local" -W -b "dc=asir-corp,dc=local"

# Modificar una entrada
ldapmodify -x -D "cn=admin,dc=asir-corp,dc=local" -W -f cambio.ldif

# Comprobar sintaxis de configuración cn=config
slaptest -u

# Ver estado de replicación (contextCSN)
ldapsearch -x -H ldaps://kdc-ldap-server -s base -b "dc=asir-corp,dc=local" contextCSN
```

```bash title="Kerberos" linenums="1"
kinit usuario                  # Solicitar TGT
klist                          # Listar tickets en caché
kdestroy                       # Destruir tickets locales
kadmin.local -q "listprincs"   # Listar principals (en el KDC)
kadmin.local -q "getprinc usuario"   # Ver políticas de un principal
kvno host/servidor.dominio     # Consultar número de versión de clave de un servicio
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- Deshabilitar `ldap://` en claro; solo `ldaps://` o `StartTLS`.
- ACLs `olcAccess` restrictivas: denegar `bind` anónimo salvo lo estrictamente necesario.
- `supported_enctypes` de Kerberos limitado a AES-256/AES-128; eliminar RC4 y DES.
- Rotar `kadm5.keytab` y keytabs de servicio periódicamente; permisos `600` root-only.
- Habilitar auditoría de `bind` fallidos en `slapd` vía `olcLogLevel: stats`.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| `kinit` falla con `KDC_ERR_PREAUTH_FAILED` | `klist -k /etc/krb5.keytab` | Contraseña incorrecta o keytab desincronizado. |
| SSSD no resuelve usuarios | `sss_cache -E && systemctl restart sssd` | Caché corrupta o cambio de esquema LDAP. |
| Réplica LDAP desfasada | `ldapsearch ... contextCSN` en ambos nodos | Fallo de red durante `syncrepl`. |
| Ticket expira prematuramente | `klist` (revisar `renew until`) | `max_life`/`ticket_lifetime` mal configurado. |

Escalar como incidente crítico cualquier modificación no auditada del `kadm5.acl` o de las ACLs `olcAccess` de OpenLDAP, dado que otorgan control administrativo sobre toda la identidad corporativa.
