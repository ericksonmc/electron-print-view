# Decisiones técnicas – CD Apuestas Kiosk

## Objetivo

Preparar máquinas Ubuntu para operar CD Apuestas de forma estable, automática y controlada, reduciendo al mínimo la intervención del usuario final y evitando cierres, minimizaciones o usos indebidos del sistema.

---

## 1. Formato de distribución: `.deb`

### Decisión

Distribuir `cdapuestas-webview` como paquete Debian:

```text
cdapuestas-webview-setup-1.0.0.deb
```

### Motivo

El `.deb` se adapta mejor a una máquina kiosk administrada porque instala la aplicación formalmente dentro del sistema.

Permite mantener rutas conocidas y estables como:

```text
/usr/bin/cdapuestas-webview
/opt/cdapuestas_webview/
/usr/share/applications/
```

También facilita:

- instalar dependencias;
- manejar permisos;
- registrar la aplicación en Ubuntu;
- automatizar futuras instalaciones;
- mantener una estructura estándar entre todas las máquinas.

### Por qué no AppImage

AppImage es mejor para aplicaciones portátiles que se ejecutan como un archivo independiente.

Para este proyecto presenta desventajas:

- el archivo puede ser movido o eliminado;
- la ruta puede cambiar;
- complica el autoarranque;
- complica la administración centralizada;
- la integración con permisos especiales de Electron es menos conveniente;
- no es ideal para una máquina que debe comportarse como un appliance dedicado.

Por estas razones, `.deb` queda como el formato oficial para las instalaciones Ubuntu de CD Apuestas.

---

## 2. Ubicación de la aplicación

### Decisión

Mantener el ejecutable principal dentro de:

```text
/opt/cdapuestas_webview/cdapuestas-webview
```

y utilizar como comando público:

```text
/usr/bin/cdapuestas-webview
```

### Motivo

Esto separa correctamente los archivos propios de la aplicación del resto del sistema y proporciona un comando estable para scripts y automatizaciones.

---

## 3. Corrección de `chrome-sandbox`

### Problema detectado

Electron no iniciaba y mostraba un error relacionado con:

```text
/opt/cdapuestas_webview/chrome-sandbox
```

### Decisión

Configurar:

```bash
sudo chown root:root /opt/cdapuestas_webview/chrome-sandbox
sudo chmod 4755 /opt/cdapuestas_webview/chrome-sandbox
```

### Motivo

Electron necesita que `chrome-sandbox` pertenezca a `root` y tenga activo el bit `setuid`.

El estado esperado es:

```text
-rwsr-xr-x root root
```

Además, el instalador debe volver a aplicar esta corrección para evitar problemas después de reinstalaciones o actualizaciones.

---

## 4. Sesión GNOME Kiosk

### Decisión

Utilizar:

```text
gnome-kiosk-script-wayland
```

en lugar de una sesión normal de Ubuntu para las máquinas definitivas.

### Motivo

La sesión normal de Ubuntu permite:

- mostrar la barra superior;
- abrir el dock;
- minimizar aplicaciones;
- cerrar la aplicación;
- acceder a otras aplicaciones;
- interactuar con el escritorio.

En una máquina pública esto aumenta el riesgo de mal uso.

GNOME Kiosk permite que la máquina funcione como un terminal dedicado, mostrando únicamente CD Apuestas.

### Resultado

El flujo de inicio queda:

```text
Ubuntu
→ inicio automático del usuario
→ GNOME Kiosk
→ supervisor
→ espera de red
→ CD Apuestas WebView
```

---

## 5. Script de GNOME Kiosk

### Decisión

Utilizar:

```text
~/.local/bin/gnome-kiosk-script
```

como punto de entrada de la sesión.

### Motivo

La sesión `gnome-kiosk-script-wayland` espera específicamente este archivo.

El script inicia el supervisor encargado de mantener CD Apuestas funcionando.

---

## 6. Supervisor del WebView

### Decisión

Crear:

```text
~/bin/start-cdapuestas-webview.sh
```

### Funciones principales

El supervisor:

- espera conectividad;
- inicia el WebView;
- evita múltiples supervisores mediante `flock`;
- espera al proceso de Electron;
- vuelve a iniciar la aplicación si el proceso termina.

### Motivo

No se puede depender únicamente del autoarranque de GNOME.

Si Electron falla o termina inesperadamente, la aplicación debe recuperarse automáticamente.

---

## 7. No usar `exec` directamente para Electron

### Decisión

El supervisor no debe reemplazarse a sí mismo mediante:

```bash
exec /usr/bin/cdapuestas-webview
```

### Motivo

`exec` reemplaza completamente el proceso del supervisor por Electron.

Si Electron termina, ya no queda ningún proceso encargado de volver a abrirlo.

Por eso el supervisor mantiene su propio proceso y ejecuta Electron como proceso hijo.

---

## 8. Evitar múltiples instancias

### Problema detectado

Durante las pruebas llegaron a abrirse múltiples procesos principales de Electron.

### Decisión

Utilizar un bloqueo con:

```bash
flock
```

y esperar correctamente al proceso activo antes de lanzar otro.

### Motivo

Electron genera normalmente varios subprocesos:

```text
renderer
zygote
gpu-process
utility
```

Eso es normal.

Lo que debe evitarse es tener múltiples procesos principales de:

```text
/opt/cdapuestas_webview/cdapuestas-webview
```

---

## 9. Esperar conectividad antes de abrir CD Apuestas

### Decisión

No abrir el WebView inmediatamente después del inicio de sesión.

El supervisor espera:

- IPv4;
- ruta por defecto;
- resolución DNS;
- respuesta HTTPS.

### Motivo

Durante el arranque, NetworkManager puede tardar en establecer completamente la conexión.

Abrir Electron demasiado pronto puede provocar que CD Apuestas cargue sin Internet.

---

## 10. No usar `ping` como prueba principal

### Problema detectado

Inicialmente se esperaba conectividad usando:

```bash
ping cdapuestas.com
```

### Decisión

Eliminar esa dependencia.

### Motivo

Un servidor puede funcionar perfectamente por HTTPS y no responder a ICMP/ping.

Por eso se decidió validar:

```text
IP
ruta
DNS
HTTPS
```

en lugar de depender de ping.

---

## 11. Uso de `curl`

### Decisión

Instalar `curl` como dependencia del setup.

### Motivo

Se utiliza para comprobar que existe comunicación HTTPS real antes de abrir el WebView.

Sin `curl`, la validación anterior quedaba incompleta.

---

## 12. NetworkManager

### Decisión

Configurar las conexiones para reconectarse automáticamente.

### Parámetros principales

```text
connection.autoconnect = yes
connection.autoconnect-retries = 0
```

### Motivo

El kiosk debe recuperarse por sí solo aunque el primer intento de conexión falle.

`0` permite reintentos continuos.

---

## 13. Problema físico de red detectado

### Hallazgo

Durante las pruebas la interfaz Ethernet negociaba inicialmente a:

```text
10 Mb/s Full Duplex
```

y perdía repetidamente el `carrier`.

Después de liberar y enderezar el cable Ethernet, negoció a:

```text
100 Mb/s Full Duplex
```

### Conclusión

El problema no era causado por el supervisor ni por NetworkManager.

El cable Ethernet conectado al kiosk estaba prensado y generaba inestabilidad física del enlace.

### Decisión

Mantener el script de espera de conectividad igualmente, ya que protege el arranque ante retrasos reales de red.

---

## 14. Escalado de Electron

### Decisión final

Ejecutar el WebView con:

```bash
--force-device-scale-factor=2.00

# COmentario de erickson MUY IMPORTANTE SOBRE ESTE SETTING: Esto creo que finalmente quedo en 1 o 1.25, tengo que confirmarlo con los scripts, mejor no tocar porque se jode la configuracion y ya no tengo las maquinas a mano para revisar.
```


### Motivo

La pantalla vertical del kiosk hacía que la interfaz se percibiera demasiado pequeña con el escalado predeterminado.

Después de varias pruebas se determinó que `2.00` ofrece el tamaño más adecuado para uso táctil.

---

## 15. Opciones de energía

### Decisión

Configurar GNOME para que el kiosk no se suspenda, bloquee ni reduzca brillo por inactividad.

Configuración:

```ini
[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/screensaver]
lock-enabled=false

[org/gnome/settings-daemon/plugins/power]
idle-dim=false
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
```

### Motivo

Una máquina kiosk debe permanecer disponible continuamente.

No debe:

- suspenderse;
- bloquear la sesión;
- pedir contraseña;
- apagar la pantalla por inactividad;
- dejar de mostrar CD Apuestas por falta de interacción.

---

## 16. Inicio de sesión automático

### Decisión

Configurar GDM para iniciar automáticamente el usuario destinado al kiosk.

### Motivo

Después de un reinicio o pérdida de energía, la máquina debe recuperarse sin intervención humana.

---

## 17. Registro de eventos

### Decisión

Guardar eventos del supervisor en:

```text
~/cdapuestas-webview.log
```

y eventos de instalación en:

```text
/var/log/cdapuestas-kiosk-setup.log
```

### Motivo

Permite diagnosticar remotamente problemas de red, fallos de Electron, reinicios y errores de instalación.

---

## 18. Acceso SSH

### Decisión

Mantener SSH disponible para administración técnica.

### Motivo

Aunque el usuario local quede limitado al modo kiosk, el personal técnico necesita revisar logs, reiniciar servicios, verificar red, actualizar configuraciones y mantener el WebView.

---

## 19. Filosofía final del despliegue

Se decidió priorizar la prevención sobre la mitigación.

En lugar de mantener un escritorio normal y tratar de impedir individualmente que un usuario minimice, cierre, abra aplicaciones o acceda a configuraciones, se utiliza directamente una sesión GNOME Kiosk dedicada.

---

## 20. Script de instalación seleccionado

### Decisión final

Se conserva como versión oficial la **primera versión estable del script de instalación que configura la máquina en modo GNOME Kiosk**.

Las versiones posteriores creadas para mantener el escritorio normal de Ubuntu quedan descartadas para el despliegue final.

### Motivo

Durante las pruebas se evaluaron dos enfoques:

1. Mantener el escritorio normal de Ubuntu y tratar de impedir o corregir acciones del usuario.
2. Utilizar directamente una sesión GNOME Kiosk dedicada.

Se decidió utilizar el segundo enfoque porque previene el mal uso desde el diseño, en lugar de intentar mitigarlo después.

La decisión final es:

```text
Prevenir el acceso al escritorio
antes que
mitigar cierres, minimizaciones o uso indebido
```

### Script de referencia

El script oficial de instalación es el que realiza este flujo:

```text
Instalación del .deb
→ corrección de chrome-sandbox
→ instalación/configuración de GNOME Kiosk
→ auto login
→ sesión gnome-kiosk-script-wayland
→ supervisor Bash
→ espera de red
→ CD Apuestas WebView
→ --force-device-scale-factor=2.00
```

Las variantes de instalación denominadas posteriormente como instalación normal, normal-v2 o normal-v3, diseñadas para conservar el escritorio tradicional de Ubuntu, **no forman parte de la configuración final aprobada**.

---

## Arquitectura final

```text
┌──────────────────────────────┐
│ Ubuntu                       │
├──────────────────────────────┤
│ Auto Login                   │
├──────────────────────────────┤
│ GNOME Kiosk / Wayland        │
├──────────────────────────────┤
│ Supervisor Bash              │
├──────────────────────────────┤
│ Verificación de red          │
├──────────────────────────────┤
│ CD Apuestas WebView          │
│ Electron Scale = 2.00        │
├──────────────────────────────┤
│ https://cdapuestas.com       │
└──────────────────────────────┘
```

---

## Resumen de decisiones

| Componente | Decisión |
|---|---|
| Sistema operativo | Ubuntu |
| Distribución del WebView | `.deb` |
| Aplicación | Electron WebView |
| Ruta | `/opt/cdapuestas_webview/` |
| Comando | `/usr/bin/cdapuestas-webview` |
| Interfaz | GNOME Kiosk |
| Sesión | `gnome-kiosk-script-wayland` |
| Auto login | Sí |
| Supervisor | Bash + `flock` |
| Espera de red | Sí |
| Verificación HTTPS | `curl` |
| Reconexión de red | NetworkManager |
| Escala | `2.00` |
| Suspensión | Desactivada |
| Bloqueo de pantalla | Desactivado |
| Administración | SSH |
| Recuperación automática | Sí |
| Formato AppImage | Descartado para este proyecto |
| Script final | Primera versión estable con GNOME Kiosk |
| Scripts con escritorio normal | Descartados para producción |

---

## Criterio general

La máquina no se está tratando como una computadora de escritorio convencional.

Se está configurando como un **terminal dedicado de CD Apuestas**.

Ese criterio guía todas las decisiones de instalación, seguridad, recuperación automática y experiencia de usuario.
