# 🔐 OpenSSL / Infraestructura PKI — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**OpenSSL** es la implementación de referencia (toolkit + librería `libssl`/`libcrypto`) de los protocolos **TLS/SSL** y de las primitivas criptográficas (cifrado simétrico, asimétrico, hashing, gestión de certificados X.509). Es el motor criptográfico subyacente de Nginx, Apache, HAProxy, OpenVPN, Postfix y la práctica totalidad de servicios TLS en Linux.

**Estándares y RFCs aplicables:**

- **RFC 5280** — Perfil de certificados y CRL X.509 v3 (estructura, extensiones, validación de cadena).
- **RFC 8446** — TLS 1.3 (handshake simplificado, eliminación de cifrados inseguros por diseño).
- **RFC 6960** — OCSP (Online Certificate Status Protocol).
- **RFC 2986 (PKCS#10)** — Formato de las Certificate Signing Requests (CSR).
- **PKCS#12** — Formato contenedor (`.p12`/`.pfx`) para empaquetar clave privada + certificado + cadena.

**Vector de funcionamiento resumido:** OpenSSL opera en dos roles diferenciados — como **Autoridad de Certificación** (`openssl ca`, `openssl req -x509`) para emitir y gestionar certificados, y como **motor TLS de librería** (`libssl`) consumido por servicios de terceros para establecer canales cifrados en tiempo real.

---

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/ssl/openssl.cnf` | Configuración global del sistema OpenSSL (políticas por defecto, `MinProtocol`, `CipherString`). |
| `/etc/ssl/certs/` | Almacén de certificados de CA confiables del sistema (formato PEM, gestionado por `update-ca-certificates`). |
| `/etc/ssl/private/` | Ubicación estándar (root-only, `chmod 700`) para claves privadas de servicios del sistema. |
| `/usr/lib/ssl/certs/ca-certificates.crt` | Bundle consolidado de CAs raíz públicas de confianza del SO. |
| `/opt/ca/<nombre-ca>/openssl-*.cnf` | Configuraciones personalizadas de CA (root/intermedia) definidas por el administrador. |
| `/opt/ca/<nombre-ca>/index.txt` | Base de datos plana de certificados emitidos/revocados (formato OpenSSL `ca`). |
| `/opt/ca/<nombre-ca>/serial` | Contador del próximo número de serie a emitir. |
| `/opt/ca/<nombre-ca>/crlnumber` | Contador de versión de la CRL. |
| `/etc/update-ca-certificates.d/` | Certificados adicionales a incorporar al almacén de confianza del sistema tras `update-ca-certificates`. |

---

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Generación de claves y CSR" linenums="1"
# Clave privada RSA moderna (mínimo recomendado 3072 bits, CCN-STIC 807)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out clave.key.pem

# Clave privada ECDSA (más eficiente, equivalente en seguridad, preferida para TLS de alto rendimiento)
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out clave-ec.key.pem

# Generar un CSR a partir de una clave existente
openssl req -new -key clave.key.pem -out solicitud.csr.pem \
  -subj "/C=ES/ST=Sevilla/O=ASIR-CORP/CN=host.dominio.local"

# Certificado autofirmado rápido (solo para laboratorio/desarrollo, nunca producción)
openssl req -x509 -newkey rsa:3072 -keyout dev.key.pem -out dev.cert.pem -days 365 -nodes
```

```bash title="Inspección y verificación de certificados" linenums="1"
# Ver el contenido completo de un certificado
openssl x509 -in cert.pem -noout -text

# Ver solo fechas de validez
openssl x509 -in cert.pem -noout -dates

# Ver huella digital (fingerprint) SHA-256
openssl x509 -in cert.pem -noout -fingerprint -sha256

# Verificar que una clave privada corresponde a un certificado (deben coincidir los módulos)
openssl x509 -noout -modulus -in cert.pem | openssl sha256
openssl rsa -noout -modulus -in clave.key.pem | openssl sha256

# Verificar la cadena de confianza completa contra la CA
openssl verify -CAfile ca-chain.cert.pem cert.pem

# Comprobar un CSR antes de enviarlo a firmar
openssl req -text -noout -verify -in solicitud.csr.pem
```

```bash title="Diagnóstico de conexiones TLS remotas" linenums="1"
# Conectar a un servicio TLS remoto y mostrar el certificado presentado
openssl s_client -connect host.dominio.local:443 -servername host.dominio.local

# Forzar una versión específica de protocolo (para pruebas de downgrade)
openssl s_client -connect host.dominio.local:443 -tls1_2

# Comprobar el estado OCSP en vivo (stapling)
openssl s_client -connect host.dominio.local:443 -status

# Listar los cifrados soportados por la librería instalada
openssl ciphers -v 'DEFAULT@SECLEVEL=2'
```

```bash title="Empaquetado y conversión de formatos" linenums="1"
# Convertir PEM a PKCS#12 (para importar en clientes Windows/navegadores)
openssl pkcs12 -export -out bundle.p12 -inkey clave.key.pem -in cert.pem -certfile ca-chain.cert.pem

# Convertir DER a PEM
openssl x509 -inform der -in cert.der -out cert.pem

# Extraer clave pública de una clave privada
openssl rsa -in clave.key.pem -pubout -out clave.pub.pem
```

---

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- **Forzar `SECLEVEL=2` como mínimo** en `/etc/ssl/openssl.cnf` (`CipherString = DEFAULT@SECLEVEL=2`), lo que descarta automáticamente claves RSA < 2048 bits, DSA y cifrados de 112 bits o inferiores.
- **Prohibir TLS 1.0/1.1** a nivel de sistema con `MinProtocol = TLSv1.2` en la sección `[system_default_sect]`; esto afecta a todo servicio que use la librería del sistema sin configuración explícita propia.
- **Permisos de clave privada**: siempre `chmod 400` y propietario exclusivo del servicio (`chown www-data:www-data` en el caso de Nginx), nunca legible por grupo ni otros. Verificar con CIS Benchmark control de "Ensure permissions on private key files are configured".
- **No almacenar claves privadas sin cifrar en repositorios de configuración gestionada** (Ansible/Puppet); usar Vault (ver UD12) o `ansible-vault` como mínimo.
- **Rotación forzosa de certificados de hoja** a 90-398 días máximo, alineado con CA/Browser Forum, incluso en PKI interna, para limitar la ventana de exposición ante robo de clave.
- **Auditar aleatoriedad del sistema** (`/dev/urandom`) en máquinas virtuales recién clonadas antes de generar claves de CA, para evitar el problema documentado de reutilización de entropía en clonado de imágenes.

---

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando de diagnóstico | Causa habitual |
|---|---|---|
| `certificate has expired` | `openssl x509 -enddate -noout -in cert.pem` | Certificado de hoja o de CA caducado; revisar automatización de renovación. |
| `unable to get local issuer certificate` | `openssl verify -CAfile ca-chain.cert.pem cert.pem` | Falta el certificado intermedio en la cadena servida por el servicio (bundle incompleto). |
| Handshake TLS falla con cifrado *weak* | `nmap --script ssl-enum-ciphers -p 443 host` | Configuración `ssl_ciphers`/`CipherString` demasiado permisiva en el servicio. |
| `key values mismatch` al desplegar | Comparar módulos con `openssl x509 -noout -modulus` vs `openssl rsa -noout -modulus` | Se ha desplegado una clave privada que no corresponde al certificado emitido. |
| Cliente rechaza el certificado por revocación | `openssl ocsp -CAfile ca-chain.cert.pem -url http://ocsp.asir-corp.local -issuer intermediate-ca.cert.pem -cert cert.pem` | Certificado revocado o responder OCSP inaccesible; escalar a SecOps si es inesperado. |

**Escalado:** cualquier hallazgo de una clave privada de CA (root o intermedia) fuera de su ubicación de custodia, o un acceso no auditado a `/opt/ca/*/private/`, debe escalarse inmediatamente como incidente de seguridad crítico (P1) conforme al procedimiento de respuesta a incidentes de UD8, dado que compromete la cadena de confianza de toda la organización.
