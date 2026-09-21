# 🌐 WireGuard — Referencia Técnica

## 📌 Arquitectura y Fundamentos

**WireGuard** es un protocolo VPN de capa 3 integrado en el kernel Linux desde la versión 5.6, basado en el **Noise Protocol Framework** (patrón `Noise_IK`). Utiliza exclusivamente primitivas criptográficas modernas fijas: **Curve25519** (intercambio de claves), **ChaCha20-Poly1305** (cifrado autenticado), **BLAKE2s** (hashing) y **HKDF** (derivación de claves), sin negociación de cifrados (*cryptographic agility* eliminada por diseño para reducir superficie de ataque).

## ⚙️ Ficheros de Configuración y Rutas Clave

| Ruta | Descripción |
|---|---|
| `/etc/wireguard/wg0.conf` | Fichero de configuración de la interfaz (claves, peers, rutas). |
| `/etc/wireguard/*.key` | Claves privadas/públicas generadas con `wg genkey`/`wg pubkey`. |
| `/sys/class/net/wg0/` | Representación de la interfaz virtual en el sistema. |

## 🛠️ Comandos de Administración / Cheat Sheet CLI

```bash title="Gestión de interfaz y claves" linenums="1"
wg genkey | tee private.key | wg pubkey > public.key   # Generar par de claves
wg-quick up wg0                                          # Levantar interfaz desde config
wg-quick down wg0                                        # Bajar interfaz
wg show wg0                                              # Estado: peers, handshakes, tráfico
wg show wg0 dump                                         # Salida parseable (scripts)
wg show wg0 latest-handshakes                            # Últimos handshakes por peer
wg set wg0 peer <PUBKEY> remove                          # Eliminar un peer en caliente
wg set wg0 peer <PUBKEY> allowed-ips 10.200.200.5/32     # Modificar AllowedIPs sin reiniciar
```

```bash title="Diagnóstico de conectividad" linenums="1"
ping -I wg0 10.200.200.1                # Probar conectividad a través del túnel
tcpdump -i wg0 -n                       # Capturar tráfico ya desencapsulado (dentro del túnel)
tcpdump -i eth0 udp port 51820 -X       # Capturar tráfico cifrado en la interfaz física
ip route show table all | grep wg0      # Verificar rutas instaladas por AllowedIPs
```

## 🛡️ Bastionado y Hardening (CCN-CERT / CIS)

- `AllowedIPs` restringido a `/32` por cliente en despliegues de acceso remoto; nunca rangos amplios innecesarios.
- Claves privadas con permisos `600`, propietario root; nunca versionadas en repositorios.
- `PersistentKeepalive` solo en clientes tras NAT/CGNAT; omitir en servidores con IP pública fija para no generar tráfico innecesario.
- Rotación periódica de pares de claves en despliegues de alta sensibilidad, pese a que WireGuard ya rota claves de sesión internamente (Perfect Forward Secrecy).
- Combinar con reglas de firewall (`PostUp`/`PostDown`) para limitar explícitamente qué subredes internas alcanza cada rango de IP virtual de VPN.

## 🩺 Diagnóstico, Logs y Escalado

| Síntoma | Comando | Causa habitual |
|---|---|---|
| `latest handshake` nunca aparece | `wg show wg0`, revisar firewall UDP/51820 | Puerto UDP bloqueado en el camino (NAT/firewall intermedio). |
| Handshake correcto pero sin tráfico | `ip route`, revisar `AllowedIPs` | AllowedIPs no cubre la subred de destino deseada. |
| Cliente móvil pierde conexión frecuentemente | Revisar `PersistentKeepalive` | Ausencia de keepalive tras cambio de NAT en redes móviles. |
| Conflicto de rutas tras levantar interfaz | `ip route show table all` | Solapamiento de `AllowedIPs` con rutas existentes del sistema. |

Escalar como incidente cualquier `[Peer]` desconocido presente en `wg show` que no figure en el inventario de claves autorizadas, indicativo de una clave pública añadida sin autorización al servidor.
