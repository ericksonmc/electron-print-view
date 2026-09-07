const { EventEmitter } = require('events');

// Adaptador escpos que no habla con ningún dispositivo: acumula todo lo que
// el formateador produce en un solo Buffer, para que el transporte elegido
// (USB o spooler) decida a dónde mandarlo.
class BufferAdapter extends EventEmitter {
  constructor() {
    super();
    this.chunks = [];
  }

  open(callback) {
    if (callback) callback(null);
    return this;
  }

  write(data, callback) {
    this.chunks.push(Buffer.isBuffer(data) ? data : Buffer.from(data));
    if (callback) callback(null);
    return this;
  }

  close(callback) {
    if (callback) callback(null);
    return this;
  }

  toBuffer() {
    return Buffer.concat(this.chunks);
  }
}

module.exports = { BufferAdapter };
