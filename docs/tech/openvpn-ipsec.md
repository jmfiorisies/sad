# 🔒 OpenVPN & IPsec (strongSwan) — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**OpenVPN** implementa una VPN en espacio de usuario sobre **TLS** (usa la librería OpenSSL, ver UD1), operando típicamente sobre UDP/1194 y soportando modo *tun* (capa 3) o *tap* (capa 2, bridging). **IPsec** (RFC 4301) es un conjunto de protocolos de capa de red que opera directamente en el kernel, con **IKEv2** (RFC 7296) como protocolo de negociación de claves moderno, implementado en Linux mediante **strongSwan** o **Libreswan**.

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/openvpn/server/server.conf` | Configuración del servidor OpenVPN. |
| `/etc/openvpn/server/ccd/` | Configuración por cliente (Client Config Directory, IPs fijas). |
| `/etc/openvpn/easy-rsa/` | PKI dedicada para certificados de cliente OpenVPN. |
| `/etc/ipsec.conf` | Definición de conexiones IPsec (strongSwan). |
| `/etc/ipsec.secrets` | Claves precompartidas o rutas a claves privadas RSA. |
| `/var/log/syslog` (facility daemon) | Logs de negociación IKE y eventos de OpenVPN. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="OpenVPN" linenums="1"
openvpn --config /etc/openvpn/client/client.ovpn      # Conexión manual en primer plano (debug)
systemctl start openvpn-server@server                 # Arranque como servicio systemd
cat /etc/openvpn/server/openvpn-status.log             # Ver clientes conectados
```

```bash title="strongSwan / IPsec" linenums="1"
ipsec statusall              # Estado detallado de todas las SAs (Security Associations)
ipsec up <nombre_conexion>   # Levantar túnel manualmente
ipsec down <nombre_conexion> # Bajar túnel
ipsec rereadsecrets          # Recargar ipsec.secrets sin reiniciar el servicio
ipsec listcerts              # Listar certificados cargados
swanctl --list-sas           # Alternativa moderna (vici) a ipsec statusall
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- OpenVPN: forzar `tls-crypt` (cifra también el canal de control TLS, no solo los datos) y `tls-version-min 1.2`.
- OpenVPN: usar certificados individuales por cliente (Easy-RSA/PKI propia, ver UD1) en lugar de una clave estática compartida.
- IPsec: preferir `authby=pubkey` con certificados X.509 sobre PSK en producción de categoría ALTA.
- IPsec: restringir `ike=`/`esp=` a suites AEAD modernas (`aes256gcm16-sha384-ecp384`), excluyendo Diffie-Hellman de grupos débiles (MODP < 2048 bits).
- Ambos: habilitar Dead Peer Detection (`dpdaction=restart` en IPsec, `keepalive` en OpenVPN) para detección y recuperación automática de caídas.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| Cliente OpenVPN no conecta | `openvpn --config cliente.ovpn` en foreground (ver error TLS) | Certificado caducado o CA no coincide. |
| Túnel IPsec en estado `CONNECTING` indefinido | `journalctl -u strongswan-starter -f` | Firewall bloqueando UDP 500/4500 (NAT-T) en el camino. |
| Negociación IKE falla en fase 1 | `ipsec statusall`, revisar propuestas `ike=` | Suites criptográficas no coincidentes entre extremos. |
| Tráfico no cruza el túnel pese a SA establecida | `ip xfrm policy`, `ip xfrm state` | Política de enrutado (`leftsubnet`/`rightsubnet`) mal definida. |

Escalar como incidente cualquier intento de negociación IKE desde IPs no reconocidas en el inventario de gateways autorizados, visible en los logs de `strongSwan` como intentos de fase 1 fallidos repetidos.
