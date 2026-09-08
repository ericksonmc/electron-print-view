const path = require('path');
const os = require('os');
require('dotenv').config();

// Default del log de debug: en Windows, %ProgramData%\cda-print-view\logs
// (la misma carpeta donde WinSW ya escribe su propio log, comprobado
// escribible por el servicio) — NO el escritorio: "Acceso a carpetas
// controlado" de Windows Defender protege el escritorio (de todos los
// usuarios) por default y bloquea silenciosamente la escritura de apps no
// reconocidas como este binario, lo que dejaría el log de debug vacío justo
// en las máquinas donde más se necesita. El instalador debug deja un acceso
// directo en el escritorio que apunta a este archivo (ver
// installer-socket-debug.nsi) para que siga siendo fácil de encontrar. En
// plataformas que no son Windows, usa el directorio temporal.
function defaultDebugLogPath() {
  if (process.platform === 'win32') {
    const programData = process.env.PROGRAMDATA || 'C:\\ProgramData';
    return path.join(programData, 'cda-print-view', 'logs', 'cda-print-view-debug.log');
  }
  return path.join(os.tmpdir(), 'cda-print-view-debug.log');
}

const config = {
  appUrl: process.env.APP_URL || 'https://cdapuestas.com',
  wsHost: process.env.WS_HOST || '127.0.0.1',
  wsPort: Number(process.env.WS_PORT) || 1315,
  printerTransport: process.env.PRINTER_TRANSPORT || 'auto', // auto | usb | spooler | null
  printerName: process.env.PRINTER_NAME || '',
  debugLog: process.env.DEBUG_LOG === 'true',
  debugLogPath: process.env.DEBUG_LOG_PATH || defaultDebugLogPath(),
};

module.exports = config;
module.exports.rootDir = path.join(__dirname, '..', '..');
