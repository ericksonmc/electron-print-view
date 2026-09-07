const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  sendToWebSocket: (data) => {
    ipcRenderer.send('send-to-websocket', data);
  },
});