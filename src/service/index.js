const server = require('../core/server');
const config = require('../core/config');

server.start();

console.log(`cdapuestas-print-service escuchando en ws://${config.wsHost}:${config.wsPort}`);
console.log(`Transporte de impresión: ${config.printerTransport}`);

function shutdown(signal) {
  console.log(`Recibido ${signal}, cerrando...`);
  server.stop();
  process.exit(0);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
