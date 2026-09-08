const WebSocket = require('ws');
const { print } = require('./printer');
const config = require('./config');
const { debugLog } = require('./debugLog');

let wss = null;

function start({ port = config.wsPort, host = config.wsHost } = {}) {
  if (wss) return wss;

  wss = new WebSocket.Server({ port, host });

  wss.on('connection', (ws) => {
    log('Cliente WebSocket conectado.');
    debugLog('Cliente WebSocket conectado.');

    ws.on('message', async (message) => {
      let data;
      try {
        data = JSON.parse(message);
      } catch (error) {
        log(`Error procesando el mensaje: ${error.message}`);
        debugLog(`Mensaje inválido (no es JSON): ${error.message}`);
        ws.send(JSON.stringify({ status: 'error', message: 'Error interno del servidor.' }));
        return;
      }

      if (!data.text) {
        ws.send(JSON.stringify({ status: 'error', message: 'Datos inválidos.' }));
        return;
      }

      debugLog(
        `Trabajo recibido (${data.text.length} caracteres). ` +
          `PRINTER_TRANSPORT=${config.printerTransport} PRINTER_NAME=${config.printerName || '(vacío, usa la predeterminada del sistema)'}`
      );

      try {
        await print(data.text);
        debugLog('Impresión completada con éxito.');
        ws.send(JSON.stringify({ status: 'success', message: 'Impresión completada.' }));
      } catch (error) {
        log(`Error imprimiendo: ${error.stack || error.message}`);
        debugLog(`ERROR imprimiendo: ${error.stack || error.message}`);
        ws.send(JSON.stringify({ status: 'error', message: error.message }));
      }
    });

    ws.on('close', () => {
      log('Cliente WebSocket desconectado.');
      debugLog('Cliente WebSocket desconectado.');
    });
  });

  log(`WebSocket de impresión escuchando en ${host}:${port}`);
  debugLog(
    `Servicio iniciado en ${host}:${port}. PRINTER_TRANSPORT=${config.printerTransport} ` +
      `PRINTER_NAME=${config.printerName || '(vacío, usa la predeterminada del sistema)'}`
  );
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
