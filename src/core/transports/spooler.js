const config = require('../config');
const { debugLog } = require('../debugLog');

// Envía el buffer ESC/POS como un trabajo RAW al spooler del sistema
// operativo: winspool en Windows, CUPS en Linux. No requiere reemplazar el
// driver de la impresora (a diferencia del transporte USB/libusb), así que es
// el camino recomendado en Windows.
async function printSpooler(buffer) {
  const printer = require('@thiagoelg/node-printer');

  const printerName = config.printerName || printer.getDefaultPrinterName();
  debugLog(
    `[spooler] impresora resuelta: "${printerName || '(ninguna)'}" ` +
      `(${config.printerName ? 'PRINTER_NAME' : 'predeterminada del sistema'})`
  );
  if (!printerName) {
    throw new Error('No hay una impresora por defecto configurada en el sistema.');
  }

  await new Promise((resolve, reject) => {
    printer.printDirect({
      data: buffer,
      printer: printerName,
      type: 'RAW',
      success: () => {
        debugLog(`[spooler] trabajo enviado correctamente a "${printerName}".`);
        resolve();
      },
      error: (err) => {
        debugLog(`[spooler] ERROR al imprimir en "${printerName}": ${err.message || err}`);
        reject(err);
      },
    });
  });
}

module.exports = { printSpooler };
