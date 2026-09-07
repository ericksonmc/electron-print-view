const WebSocket = require('ws');
const { print } = require('./printer');
const config = require('./config');

let wss = null;

function start({ port = config.wsPort, host = config.wsHost } = {}) {
  if (wss) return wss;

  wss = new WebSocket.Server({ port, host });

  wss.on('connection', (ws) => {
    log('Cliente WebSocket conectado.');

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
        log(`Error procesando el mensaje: ${error.message}`);
        ws.send(JSON.stringify({ status: 'error', message: 'Error interno del servidor.' }));
      }
    });

    ws.on('close', () => {
      log('Cliente WebSocket desconectado.');
    });
  });

  log(`WebSocket de impresión escuchando en ${host}:${port}`);
  return wss;
}

function stop() {
  if (!wss) return;
  wss.close();
  wss = null;
}

function log(message) {
  console.log(`[${new Date().toISOString()}] ${message}`);
}

module.exports = { start, stop };
