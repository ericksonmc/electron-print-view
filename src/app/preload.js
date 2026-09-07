const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  checkForUpdates: () => {
    ipcRenderer.send('check-for-updates');
  },

  onUpdateMessage: (callback) => {
    ipcRenderer.on('update-message', (_, message) => callback(message));
  },
});
