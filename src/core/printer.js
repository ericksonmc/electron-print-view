const { format } = require('./formatter');
const transports = require('./transports');

// Punto de entrada de impresión: formatea el texto con tags a bytes ESC/POS
// y lo manda al transporte resuelto (ver transports/index.js). Los errores
// se propagan al llamador (server.js) en vez de tragarse acá, para que el
// cliente WebSocket reciba el estado real del trabajo.
async function print(input) {
  const buffer = await format(input);
  await transports.send(buffer);
}

module.exports = { print };
