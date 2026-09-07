const WebSocket = require('ws');
const { print } = require('./printer');

require('dotenv').config()

const wss = new WebSocket.Server({ port: 1315 });

wss.on('connection', (ws) => {
  console.log('WebSocket server connected.');

   ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      if (data.text) {
        print(data.text);
        ws.send(JSON.stringify({ status: 'success', message: 'Impresión completada.' }));
      } else {
        ws.send(JSON.stringify({ status: 'error', message: 'Datos inválidos.' }));
      }
    } catch (error) {
      console.error('Error procesando el mensaje:', error.message);
      ws.send(JSON.stringify({ status: 'error', message: 'Error interno del servidor.' }));
    }
  });

  ws.on('close', () => {
    console.log('WebSocket server disconnected.');
  });
});

console.log('WebSocket running in port 1315');