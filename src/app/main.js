const net = require('net');
const path = require('path');
const { app, BrowserWindow, globalShortcut, ipcMain } = require('electron');
const { autoUpdater } = require('electron-updater');

const config = require('../core/config');
const server = require('../core/server');

let mainWindow;

function configureAutoUpdater() {
  autoUpdater.logger = require('electron-log');
  autoUpdater.logger.transports.file.level = 'info';

  autoUpdater.on('checking-for-update', () => {
    sendStatusToWindow('Checking for updates...');
  });

  autoUpdater.on('update-available', () => {
    sendStatusToWindow('Update available.');
  });

  autoUpdater.on('update-not-available', () => {
    sendStatusToWindow('Update not available.');
  });

  autoUpdater.on('error', (err) => {
    sendStatusToWindow(`Error in auto-updater: ${err.toString()}`);
  });

  autoUpdater.on('download-progress', (progressObj) => {
    sendStatusToWindow(
      `Download speed: ${progressObj.bytesPerSecond} - Downloaded ${progressObj.percent}% (${progressObj.transferred}/${progressObj.total})`
    );
  });

  autoUpdater.on('update-downloaded', () => {
    sendStatusToWindow('Update downloaded. Will install on restart.');
  });
}

function sendStatusToWindow(text) {
  if (mainWindow) {
    mainWindow.webContents.send('update-message', text);
  }
}

// Si el servicio "socket" ya está instalado y corriendo en esta máquina, no
// levantamos un segundo servidor en el mismo puerto: el modo full solo actúa
// como contenedor y deja que el servicio existente atienda la impresión.
function isPortInUse(port, host) {
  return new Promise((resolve) => {
    const tester = net.createConnection({ port, host }, () => {
      tester.end();
      resolve(true);
    });
    tester.on('error', () => resolve(false));
  });
}

async function startPrintServerIfNeeded() {
  const alreadyRunning = await isPortInUse(config.wsPort, config.wsHost);
  if (alreadyRunning) {
    console.log(`Puerto ${config.wsPort} ya en uso (servicio de impresión externo); no se levanta uno propio.`);
    return;
  }
  server.start();
}

function createWindow() {
  mainWindow = new BrowserWindow({
    fullscreen: true,
    autoHideMenuBar: true,
    frame: false,
    kiosk: false,
    resizable: false,
    movable: false,
    webPreferences: {
      devTools: true,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  mainWindow.loadURL(config.appUrl, { extraHeaders: 'pragma: no-cache\n' });

  const KEYS_DISABLED = ['F11', 'F12', 'Escape'];

  mainWindow.webContents.on('before-input-event', (event, input) => {
    if (KEYS_DISABLED.includes(input.key)) {
      event.preventDefault();
    }
  });
}

app.whenReady().then(async () => {
  await startPrintServerIfNeeded();
  createWindow();
  configureAutoUpdater();

  autoUpdater.checkForUpdatesAndNotify();

  setInterval(() => {
    autoUpdater.checkForUpdatesAndNotify();
  }, 60 * 60 * 1000);
});

app.disableHardwareAcceleration();

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
});

ipcMain.on('check-for-updates', () => {
  autoUpdater.checkForUpdatesAndNotify();
});
