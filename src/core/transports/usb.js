const escpos = require('escpos');

// escpos-usb espera la API de usb 1.x (eventos en el módulo raíz); en usb 2.x
// los eventos viven en `usb.usb`.
const nodeUsb = require('usb');
if (typeof nodeUsb.on !== 'function' && nodeUsb.usb) {
  require.cache[require.resolve('usb')].exports = Object.assign(Object.create(nodeUsb.usb), {
    getDeviceList: nodeUsb.getDeviceList,
    findByIds: nodeUsb.findByIds,
  });
}
escpos.USB = require('escpos-usb');

// Envía el buffer ESC/POS ya formateado directo a la impresora USB por
// libusb. Es el camino que ya funciona hoy en Ubuntu.
//
// La impresora se abre por cada trabajo (no en module scope): si se abre una
// sola vez al cargar el módulo y no hay impresora conectada, `new
// escpos.USB()` revienta el proceso entero apenas arranca.
async function printUsb(buffer) {
  const device = new escpos.USB();

  await new Promise((resolve, reject) => {
    device.open((err) => {
      if (err) return reject(err);

      device.write(buffer, (writeErr) => {
        if (writeErr) {
          device.close();
          return reject(writeErr);
        }
        device.close(() => resolve());
      });
    });
  });
}

module.exports = { printUsb };
