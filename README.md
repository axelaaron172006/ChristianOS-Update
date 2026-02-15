# ChristianOS-Update

Proyecto base para construir y validar actualizaciones tipo *Windows Update* para ChristianOS.

## Objetivo

Este repositorio te permite:

- Definir un manifiesto de actualización por versión de Windows (`22H2`, `24H2`, `25H2`, etc.).
- Validar archivos (`.cab` / `.msi` / `.msu`) con SHA256.
- Generar reportes de estado para cada KB.
- Usar IA (API de ChatGPT) para proponer y generar KBs en formato **MSI o CAB**.
- (Opcional) Actualizar automáticamente el manifiesto con tamaño/hash reales.

## Estructura rápida

- `manifests/`: metadatos de cada actualización.
- `src/UpdateNecesaryJSON.ps1`: script de validación y reporte.
- `src/generate_kb_with_ai.py`: generador de manifiestos con API de ChatGPT.
- `reports/`: salida de logs de ejecución.
- `builder/`: artefactos de construcción (CAB/MSU, DDF, payload).

## Flujo recomendado para crear tu propio "Windows Update"

1. Define las novedades de la release.
2. Genera manifiestos KB por versiones (`22H2`, `24H2`, `25H2...`) con IA.
3. Construye el paquete real (`.msi` o `.cab`) y colócalo en `./packages/`.
4. Ejecuta validación para calcular hashes/tamaños.
5. Publica la KB por versión.

## Generar KB con IA (ChatGPT API)

Configura tu API key (no la hardcodees en el repo):

```bash
export OPENAI_API_KEY="tu_api_key"
# opcional
export OPENAI_MODEL="gpt-5-mini"
```

### Un solo release

```bash
python src/generate_kb_with_ai.py \
  --novedades "Correcciones de red, parche de seguridad y mejoras de estabilidad" \
  --product ChristianOS11 \
  --releases 25H2 \
  --kb KB0002
```

### Múltiples releases (22H2, 24H2, 25H2)

```bash
python src/generate_kb_with_ai.py \
  --novedades "Mejoras del sistema y estabilidad" \
  --product ChristianOS11 \
  --releases 22H2,24H2,25H2 \
  --kb KB0003
```

Salida esperada:

- Crea un manifiesto por versión de Windows en `manifests/`.
- Define `type` como `MSI` o `CAB` según recomendación de IA.
- Prepara nombre/ruta de paquete por release en `files[0]`.

## Validación del manifiesto y archivos

Validar sin modificar el JSON:

```powershell
pwsh ./src/UpdateNecesaryJSON.ps1 -ManifestPath ./manifests/KB0003-ChristianOS11-24H2.json
```

Validar y actualizar JSON (`size`, `sha256`, `status`):

```powershell
pwsh ./src/UpdateNecesaryJSON.ps1 -ManifestPath ./manifests/KB0003-ChristianOS11-24H2.json -UpdateManifest
```

## Consejos para novedades de ChristianOS Update

- Incrementa `version` cuando publiques una revisión nueva.
- Mantén `compatibility` exacto por release (`22H2`, `24H2`, `25H2`, etc.).
- Usa nombres consistentes por KB para evitar errores de despliegue.
- No publiques con `AUTO_GENERATE` si ya estás en release: sustituye hashes reales.
