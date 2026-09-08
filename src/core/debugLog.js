const fs = require('fs');
const path = require('path');
const config = require('./config');

// Log opcional y detallado para diagnosticar máquinas remotas sin acceso
// directo: se activa con DEBUG_LOG=true (ver cda-print-view-debug.xml) y
// escribe en config.debugLogPath (por default, %ProgramData%\cda-print-view\
// logs en Windows — ver la nota en config.js sobre por qué no es el
// escritorio) además del log normal de la consola/WinSW.
function debugLog(message) {
  if (!config.debugLog) return;
  const line = `[${new Date().toISOString()}] ${message}\n`;
  try {
    fs.mkdirSync(path.dirname(config.debugLogPath), { recursive: true });
    fs.appendFileSync(config.debugLogPath, line);
  } catch (error) {
    // Si el log de debug no se puede escribir (permisos, ruta inválida),
    // no debe romper la impresión real por eso.
    console.error(`No se pudo escribir el log de debug en ${config.debugLogPath}: ${error.message}`);
  }
}

module.exports = { debugLog };
