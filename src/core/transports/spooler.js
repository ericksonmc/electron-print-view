const config = require('../config');

// Envía el buffer ESC/POS como un trabajo RAW al spooler del sistema
// operativo: winspool en Windows, CUPS en Linux. No requiere reemplazar el
// driver de la impresora (a diferencia del transporte USB/libusb), así que es
// el camino recomendado en Windows.
async function printSpooler(buffer) {
  const printer = require('@thiagoelg/node-printer');

  const printerName = config.printerName || printer.getDefaultPrinterName();
  if (!printerName) {
    throw new Error('No hay una impresora por defecto configurada en el sistema.');
  }

  await new Promise((resolve, reject) => {
    printer.printDirect({
      data: buffer,
      printer: printerName,
      type: 'RAW',
      success: () => resolve(),
      error: (err) => reject(err),
    });
  });
}

module.exports = { printSpooler };
