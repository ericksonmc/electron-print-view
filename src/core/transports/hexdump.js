// Transporte "null": no imprime nada, solo vuelca los bytes ESC/POS
// generados en hexadecimal. Sirve para probar el formateador sin tener una
// impresora física conectada. Se activa con PRINTER_TRANSPORT=null.
async function printHexdump(buffer) {
  console.log('--- ESC/POS hexdump (PRINTER_TRANSPORT=null) ---');
  console.log(buffer.toString('hex').match(/.{1,32}/g)?.join('\n') || '');
  console.log(`--- ${buffer.length} bytes ---`);
}

module.exports = { printHexdump };
