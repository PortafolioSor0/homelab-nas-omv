# Formación profesional: competencias demostradas

Este documento relaciona las competencias técnicas que demuestra el proyecto con evidencia
concreta dentro del repositorio. Los espacios marcados con `[ ]` son para completar con datos
reales; aquí no se inventan métricas.

## Competencias técnicas

| Competencia | Evidencia en el repo |
|---|---|
| Administración de Linux (Debian 13 / OMV 8) | [CHANGELOG.md](../CHANGELOG.md), fases 1–8: cuentas, `sudo`, servicios, actualizaciones, NTP y kernel backports; inventario en [phase-0-discovery.md](phase-0-discovery.md) |
| Seguridad de servidores (hardening) | Fase 1 en [roadmap.md](roadmap.md): administrador con llave ed25519, SSH sin root ni contraseña, X11 desactivado con un bloque `Match` (porque OMV genera `sshd_config`), interfaz solo por HTTPS y tiempo de sesión |
| Modelado de amenazas | [security.md](security.md): amenazas T1–T14 con probabilidad e impacto, objetivos de seguridad y controles vinculados a cada amenaza y fase |
| Almacenamiento y gestión de discos | [storage.md](storage.md) (ext4 por disco + mergerfs + SnapRAID frente a RAID), [hardware.md](hardware.md) (identificar discos por serial/by-id/UUID), formateo controlado de la fase 3 |
| Monitoreo de salud de hardware | Fase 2: SMART, autopruebas programadas, umbrales de temperatura y alertas por correo verificadas |
| Control de acceso (usuarios, grupos, ACLs POSIX) | [users-and-permissions.md](users-and-permissions.md) y fase 5: cuentas sin shell, modos `2700`/`2770`, ACLs por defecto y prueba de acceso cruzado con `sudo -u … test` |
| Servicios de archivos en red (Samba/SMB3) | Fase 6: SMB3 como mínimo, sin invitados, NetBIOS desactivado, enumeración basada en acceso y pruebas desde cada cliente |
| Contenedores (Docker / Compose) con mínimo privilegio | [compose/jellyfin/compose.yaml](../compose/jellyfin/compose.yaml): UID de servicio, `cap_drop: ALL`, `no-new-privileges`, media en solo lectura, solo `renderD128`, puerto ligado a la IP LAN, imagen fijada y `create_host_path: false` |
| Redes | [network.md](network.md): IP estática, análisis de CGNAT con `tracert` para comprobar que no hay exposición entrante, IPv6 ULA |
| Scripting seguro en Bash | [scripts/discovery-readonly.sh](../scripts/discovery-readonly.sh): inventario estrictamente de solo lectura con contrato en [specs/](../specs/001-phase0-discovery/contracts/discovery-script.md) |
| Gestión de cambios y documentación técnica | Plantilla de registro de cambios (objetivo, estado previo, cambio, rollback, verificación); más de 30 entradas fechadas en el CHANGELOG |
| Decisiones de arquitectura (ADR) | [decisions.md](decisions.md): D-01…D-18 con alternativas, justificación y fase que bloquea cada una |
| Planificación guiada por especificaciones | [specs/001-phase0-discovery/](../specs/001-phase0-discovery/): especificación, plan, tareas, modelo de datos y contratos (Spec Kit) |
| Trabajo con asistentes de IA bajo controles | Las reglas de operación exigen una compuerta de aprobación para operaciones destructivas, prohíben secretos en Git e identifican el error asistido por IA como amenaza (T2) |

## Retos y aprendizajes

| Reto | Cómo se resolvió | Aprendizaje |
|---|---|---|
| El disco del sistema aparece como `sdb`, no `sda`, y los nombres cambian entre arranques | Todos los discos se identifican por modelo + serial + `/dev/disk/by-id` + UUID antes de cualquier operación | Nunca confiar en `/dev/sdX` para operaciones destructivas |
| OMV genera `sshd_config` y escribe `X11Forwarding yes` primero; una opción extra `X11Forwarding no` se ignoraba porque sshd usa el primer valor que lee | En las opciones extra de OMV se puso un bloque `Match all` con `X11Forwarding no` (los valores dentro de `Match` reemplazan al global), y se verificó con `sshd -T -C …`, porque `sshd -T` a secas ignora los bloques `Match` | Entender cómo se interpreta la configuración y respetar la fuente de verdad del sistema de gestión |
| La aplicación necesita la GPU pero no debe correr como root | UID de servicio dedicado, solo el nodo `renderD128` y `group_add` con el GID de `render` | El mínimo privilegio es compatible con la aceleración por hardware |
| Si el HDD no está montado, un contenedor puede crear una biblioteca vacía en el SSD | `create_host_path: false`: el contenedor no arranca si falta la ruta | Diseñar para que el fallo sea visible y seguro |
| ¿El NAS está expuesto a internet? | `tracert` mostró que el ISP usa CGNAT (`100.64.0.0/10`) y no hay IPv6 global: no hay ruta entrante | Verificar la exposición con evidencia, sin suponerla |
| No hay backups todavía | La política D-10 prohíbe que el NAS sea la única copia de los datos de nivel 1 hasta la fase 13 | Paridad y RAID no son backup; el orden de las fases protege los datos |
| La SSD del sistema es usada (30 % de desgaste, F-10) y va a guardar el estado de las aplicaciones | La decisión D-11 aceptó el riesgo explícitamente: backups de nivel 2 obligatorios antes de que Immich tenga datos reales, y revisar una segunda SSD según el desgaste | Un inventario honesto antes de diseñar convierte los riesgos en decisiones documentadas |

## Impacto (por completar)

- Horas invertidas: `[ ]`
- Tiempo para reconstruir el servidor desde el repo (si se prueba): `[ ]`
- Número de usuarios o dispositivos atendidos: `[ ]`
- Datos gestionados (TB): `[ ]`
- Otros resultados medibles: `[ ]`
