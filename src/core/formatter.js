const path = require('path');
const os = require('os');
const escpos = require('escpos');
const qr = require('qr-image');
const fs = require('fs-extra');
const { BufferAdapter } = require('./transports/buffer-adapter');
const { cdapuestasLogo } = require('./assets/logo');

// Convierte el mini-lenguaje de tags del frontend de cdapuestas.com en bytes
// ESC/POS. Es el mismo contrato que ya usa la web — no cambiar la gramática
// de tags sin coordinar con ese lado.
//
// Tags soportados: [center] [left] [right] [bold] [underline] [big] [line]
// [cut] [bar]...[/bar] [qr]...[/qr] [img]...[/img] [table]...[/table]
// [NEXT] [FLUSH] [CDAPUESTAS]
async function format(input) {
  const adapter = new BufferAdapter();
  const printer = new escpos.Printer(adapter, { encoding: 'ISO-8859-1' });

  printer.size(0.5, 0.5);
  const lines = input.split(/\r?\n|\r|\[NEXT\]/g);

  let endedWithCut = false;
  for (const line of lines) {
    const trimmedLine = line.trim();
    if (!trimmedLine) continue;
    endedWithCut = false;

    if (trimmedLine.toUpperCase() === '[LINE]') {
      printer.drawLine();
    } else if (trimmedLine.toUpperCase() === '[CUT]') {
      printer.feed().cut();
      endedWithCut = true;
    } else if (trimmedLine.toUpperCase() === '[CDAPUESTAS]') {
      // El logo ya ocupa 67 puntos verticales; dos feeds adicionales dejan un
      // hueco excesivo antes de la primera línea del ticket.
      await printBase64Image(cdapuestasLogo, printer, 1);
    } else if (trimmedLine.toUpperCase() === '[NEXT]') {
      printer.newLine();
    } else if (trimmedLine.toUpperCase() === '[FLUSH]') {
      printer.newLine();
    } else {
      await processLine(trimmedLine, printer);
    }
  }

  // Un salto después del corte avanzaría el papel y sumaría margen arriba del siguiente ticket.
  if (!endedWithCut) printer.newLine();
  printer.flush();
  return adapter.toBuffer();
}

async function processLine(line, printer) {
  let currentPos = 0;
  const length = line.length;
  let buffer = '';
  const styleStack = [];

  while (currentPos < length) {
    const nextOpen = line.indexOf('[', currentPos);
    if (nextOpen === -1) {
      buffer += line.substring(currentPos);
      break;
    }

    buffer += line.substring(currentPos, nextOpen);
    currentPos = nextOpen;

    const nextClose = line.indexOf(']', currentPos);
    if (nextClose === -1) {
      buffer += line.substring(currentPos);
      break;
    }

    const tagContent = line.substring(currentPos + 1, nextClose);
    currentPos = nextClose + 1;

    if (buffer) {
      printer.text(buffer);
      buffer = '';
    }

    if (tagContent.startsWith('/')) {
      const tagName = tagContent.substring(1).toLowerCase();
      if (styleStack.length > 0 && styleStack[styleStack.length - 1].tag === tagName) {
        const { revert } = styleStack.pop();
        revert();
      }
    } else {
      const newPos = await handleOpenTag(tagContent, line, styleStack, printer, currentPos);
      if (newPos !== undefined) {
        currentPos = newPos;
      }
    }
  }

  if (buffer) printer.text(buffer);
}

const QR_DEFAULT_WIDTH = 160;
const QR_MIN_MODULE = 3;
const QR_MARGIN = 2;

function qrModuleSize(content, maxWidth) {
  const modules = qr.matrix(content).length + QR_MARGIN * 2;
  return Math.max(QR_MIN_MODULE, Math.floor(maxWidth / modules));
}

function numericAttr(tagParts, name) {
  const value = Number((tagParts.find((p) => p.startsWith(`${name}=`)) || '').slice(name.length + 1));
  return value > 0 ? value : null;
}

async function handleOpenTag(tagContent, line, styleStack, printer, startPos) {
  const tagParts = tagContent.toLowerCase().split(' ');
  const tagName = tagParts[0];

  if (['bar', 'qr', 'table', 'img'].includes(tagName)) {
    const closingTag = `[/${tagName}]`;
    const closingIndex = line.indexOf(closingTag, startPos);
    if (closingIndex === -1) return startPos;

    const content = line.substring(startPos, closingIndex);
    const newPos = closingIndex + closingTag.length;

    switch (tagName) {
      case 'bar':
        printer.style('B').align('ct').barcode(content, 'CODE39', { width: 250, height: 80 });
        break;
      case 'qr': {
        // [qr width=N]: ancho máximo en puntos (203 dpi, 8 pts ≈ 1 mm). [qr size=N]: módulo fijo en puntos.
        const width = numericAttr(tagParts, 'width') || QR_DEFAULT_WIDTH;
        const size = numericAttr(tagParts, 'size') || qrModuleSize(content, width);
        const qrOptions = { type: 'png', size, margin: QR_MARGIN };
        await new Promise((resolve) => {
          printer.align('ct').qrimage(content, qrOptions, resolve);
        });
        printer.feed(2);
        break;
      }
      case 'table': {
        const MAX_COLUMNS = 4;
        const rows = content.split('|').filter((row) => row.trim());
        const rowCount = rows.length;

        const COLUMN_WIDTHS = {
          1: [1],
          2: [0.5, 0.5],
          3: [0.33, 0.33, 0.33],
          4: [0.25, 0.25, 0.25, 0.25],
        };

        const COLUMN_ALIGNMENTS = {
          1: ['CENTER'],
          2: ['CENTER', 'CENTER'],
          3: ['LEFT', 'CENTER', 'RIGHT'],
          4: ['LEFT', 'CENTER', 'CENTER', 'RIGHT'],
        };

        if (rowCount > MAX_COLUMNS) {
          printer.style('B').align('CENTER').text(`Error: Maximum ${MAX_COLUMNS} columns allowed`);
          break;
        }

        const tableData = rows.map((row, index) => ({
          text: row.trim(),
          align: COLUMN_ALIGNMENTS[rowCount][index],
          width: COLUMN_WIDTHS[rowCount][index],
          style: 'B',
        }));

        printer.tableCustom(tableData, { encoding: 'cp857', size: [1, 1] });
        break;
      }
      case 'img':
        await printBase64Image(content, printer);
        break;
    }

    return newPos;
  } else {
    applyStyleTag(tagName, styleStack, printer);
    return undefined;
  }
}

function applyStyleTag(tagName, styleStack, printer) {
  let revertFn;
  switch (tagName) {
    case 'center':
      printer.align('ct');
      revertFn = () => printer.align('lt');
      break;
    case 'table':
    case 'left':
      printer.align('lt');
      revertFn = () => {};
      break;
    case 'right':
      printer.align('rt');
      revertFn = () => printer.align('lt');
      break;
    case 'bold':
      printer.style('B');
      revertFn = () => printer.style('NORMAL');
      break;
    case 'underline':
      printer.style('U');
      revertFn = () => printer.style('NORMAL');
      break;
    case 'big':
      printer.size(1, 1);
      revertFn = () => printer.size(0.5, 0.5);
      break;
    default:
      return;
  }
  styleStack.push({ tag: tagName, revert: revertFn });
}

async function printBase64Image(base64String, printer, trailingFeed = 1) {
  let imagePath;
  try {
    const tempDir = os.tmpdir();
    await fs.ensureDir(tempDir);

    const imageName = `temp_image_${Date.now()}.png`;
    imagePath = path.join(tempDir, imageName);

    const base64Data = base64String.replace(/^data:image\/\w+;base64,/, '');
    await fs.writeFile(imagePath, base64Data, 'base64');

    await new Promise((resolve) => {
      escpos.Image.load(imagePath, (image) => {
        printer.align('ct').raster(image);
        printer.feed(trailingFeed);
        resolve();
      });
    });
  } catch (error) {
    console.error('Error printing image:', error.message);
  } finally {
    if (imagePath) {
      try {
        await fs.remove(imagePath);
      } catch (err) {
        console.error('Error deleting temp image:', err.message);
      }
    }
  }
}

module.exports = { format };
