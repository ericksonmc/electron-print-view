# Release 1.0.0

Versión base ya desplegada en los kioscos (la del instalador
`cdapuestas-webview-setup-1.0.0.deb`).

Para que esta carpeta sirva de rollback/instalación, coloca aquí su `.deb`:

```text
releases/1.0.0/
  autostart.sh
  cdapuestas-webview-setup-1.0.0.deb   ← colócalo aquí (no se versiona en git)
```

El `.deb` se genera con `npm run build:full:linux`. Ver la regla completa en
[`../README.md`](../README.md).
