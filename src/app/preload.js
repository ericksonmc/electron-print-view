const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  checkForUpdates: () => {
    ipcRenderer.send('check-for-updates');
  },

  onUpdateMessage: (callback) => {
    ipcRenderer.on('update-message', (_, message) => callback(message));
  },

  // Apaga el equipo (fin de jornada en el kiosko). Solo existe dentro del
  // contenedor Electron; en un navegador normal window.api es undefined.
  shutdownMachine: () => {
    ipcRenderer.send('shutdown-machine');
  },
});
