import { Extension as ShellExtension } from 'resource:///org/gnome/shell/extensions/extension.js';

// Nota: en el .deb original esta clase vivía en src/extension.js y se
// requería con `require('./extension')` desde Electron — pero GNOME Shell
// carga sus extensiones vía GJS/ESM, no CommonJS, así que nunca llegó a
// ejecutarse. Se reescribe aquí en el formato real de extensión de GNOME
// Shell 45+ para que sí se pueda instalar y probar.
export default class DisableGesturesExtension extends ShellExtension {
  _focusWindowId = null;
  _inFullscreenChangedId = null;

  enable() {
    const disableUnmaximizeGesture = () => {
      global.stage.get_actions().forEach((action) => {
        action.enabled = false;
      });
    };

    disableUnmaximizeGesture();

    if (this._focusWindowId === null) {
      this._focusWindowId = global.display.connect('notify::focus-window', disableUnmaximizeGesture);
    }
    if (this._inFullscreenChangedId === null) {
      this._inFullscreenChangedId = global.display.connect('in-fullscreen-changed', disableUnmaximizeGesture);
    }
  }

  disable() {
    if (this._inFullscreenChangedId !== null) {
      global.display.disconnect(this._inFullscreenChangedId);
      this._inFullscreenChangedId = null;
    }
    if (this._focusWindowId !== null) {
      global.display.disconnect(this._focusWindowId);
      this._focusWindowId = null;
    }
    global.stage.get_actions().forEach((action) => {
      action.enabled = true;
    });
  }
}
