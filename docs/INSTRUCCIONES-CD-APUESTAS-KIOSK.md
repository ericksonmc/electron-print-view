# Instalación de CD Apuestas Kiosk

## Archivos requeridos

Coloque los siguientes dos archivos en el escritorio de Ubuntu:

```text
cdapuestas-kiosk-setup.sh
cdapuestas-webview-setup-1.0.0.deb
```

> Ambos archivos deben conservar exactamente esos nombres.

## Ejecutar la instalación

Abra una terminal presionando:

```text
Ctrl + Alt + T
```

Luego ejecute:

```bash
cd "$(xdg-user-dir DESKTOP)"
chmod +x cdapuestas-kiosk-setup.sh
./cdapuestas-kiosk-setup.sh --reboot
```

El instalador solicitará la contraseña del usuario de Ubuntu.

Durante el proceso se instalarán las dependencias necesarias, se configurará el modo kiosk y se instalará CD Apuestas WebView. La computadora debe permanecer conectada a Internet.

Al finalizar, la máquina se reiniciará automáticamente.

## Indicar manualmente el usuario

Normalmente el instalador detecta automáticamente el usuario de Ubuntu.

En caso de necesitar indicarlo manualmente, ejecute:

```bash
./cdapuestas-kiosk-setup.sh --user=nombre_usuario --reboot
```

Reemplace `nombre_usuario` por el nombre real del usuario de Ubuntu.

Para conocer el usuario actual puede ejecutar:

```bash
whoami
```

## Registro de instalación

El registro completo del proceso se almacena en:

```text
/var/log/cdapuestas-kiosk-setup.log
```

Para consultarlo:

```bash
sudo cat /var/log/cdapuestas-kiosk-setup.log
```

## Respaldo de la configuración

Antes de modificar el sistema, el instalador crea un respaldo en una carpeta con el siguiente formato:

```text
/var/backups/cdapuestas-kiosk-FECHA-HORA
```

Por ejemplo:

```text
/var/backups/cdapuestas-kiosk-20260724-143000
```

## Resultado esperado

Después del reinicio, la computadora realizará automáticamente este proceso:

```text
Iniciar Ubuntu
→ Iniciar sesión automáticamente
→ Esperar la conexión a Internet
→ Abrir CD Apuestas WebView
→ Volver a abrirlo si se cierra
```

La máquina quedará funcionando en modo kiosk, sin acceso normal al escritorio, la barra superior ni la barra de aplicaciones.
