const os = require('os');
const config = require('../config');
const { printUsb } = require('./usb');
const { printSpooler } = require('./spooler');
const { printHexdump } = require('./hexdump');
const { debugLog } = require('../debugLog');

// Resuelve qué transporte usar para mandar un buffer ESC/POS ya formateado:
// - 'auto' (default): spooler (RAW) en Windows, USB/libusb en Linux.
//   No requiere Zadig/WinUSB en Windows porque usa la impresora ya instalada.
// - 'usb' / 'spooler' / 'null': fuerza uno específico (útil para pruebas).
async function send(buffer) {
  const transport = config.printerTransport;

  if (transport === 'null') {
    return printHexdump(buffer);
  }
  if (transport === 'usb') {
    return printUsb(buffer);
  }
  if (transport === 'spooler') {
    return printSpooler(buffer);
  }

  const primary = os.platform() === 'win32' ? printSpooler : printUsb;
  const fallback = os.platform() === 'win32' ? printUsb : printSpooler;
  const primaryName = os.platform() === 'win32' ? 'spooler' : 'usb';
  const fallbackName = os.platform() === 'win32' ? 'usb' : 'spooler';

  try {
    await primary(buffer);
  } catch (err) {
    console.error(`[transporte:${primaryName}] falló (${err.message}), probando ${fallbackName}...`);
    debugLog(`[auto] transporte "${primaryName}" falló (${err.message}), probando "${fallbackName}"...`);
    await fallback(buffer);
  }
}

module.exports = { send };
