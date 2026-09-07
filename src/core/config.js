const path = require('path');
require('dotenv').config();

const config = {
  appUrl: process.env.APP_URL || 'https://cdapuestas.com',
  wsHost: process.env.WS_HOST || '127.0.0.1',
  wsPort: Number(process.env.WS_PORT) || 1315,
  printerTransport: process.env.PRINTER_TRANSPORT || 'auto', // auto | usb | spooler | null
  printerName: process.env.PRINTER_NAME || '',
};

module.exports = config;
module.exports.rootDir = path.join(__dirname, '..', '..');
