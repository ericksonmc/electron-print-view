const { format } = require('./formatter');
const transports = require('./transports');

// Punto de entrada de impresión: formatea el texto con tags a bytes ESC/POS
// y lo manda al transporte resuelto (ver transports/index.js).
async function print(input) {
  try {
    const buffer = await format(input);
    await transports.send(buffer);
  } catch (error) {
    console.error('Error printing:', error.message);
  }
}

module.exports = { print };
