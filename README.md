# Windows N: workaround para recuperar la webcam

Procedimiento reproducible para el aviso **“You need a media feature pack”** de Cámara en Windows N cuando la instalación normal de Media Feature Pack falla, por ejemplo, con **`0x800f0991` (`PSFX_E_MISSING_PAYLOAD_FILE`)**.

El paso que desbloqueó el caso documentado fue instalar la capacidad usando los archivos locales y **`-LimitAccess`**, y reiniciar después:

```powershell
Add-WindowsCapability -Online -Name 'Media.MediaFeaturePack~~~~0.0.1.0' -LimitAccess
```

**Resultado comprobado en un equipo:** después del reinicio, la webcam Logitech C920 entregó una fotografía real de 1280 × 720 mediante OpenCV/DirectShow. El usuario confirmó posteriormente que funcionaba. No se reinstaló Windows para conseguir esa captura.

## Cuándo aplica

- Windows 10/11 **N** y un aviso de Cámara que pide Media Feature Pack.
- La capacidad multimedia está ausente o quedó preparada parcialmente (`Staged`).
- Los archivos necesarios ya están disponibles localmente o en un origen válido configurado explícitamente.

Se probó en **Windows 11 Pro N, 25H2, compilación 26200.9168**, con una **Logitech HD Pro Webcam C920**. No se ha validado este procedimiento completo en Windows 10 ni en otras compilaciones.

`-LimitAccess` impide que esta operación consulte Windows Update para obtener archivos de origen. **No descarga los archivos que falten, no repara automáticamente cualquier corrupción y no limita el consumo de otras aplicaciones o servicios.** Si faltan los archivos locales, puede fallar o dejar la capacidad sin instalar; hay que revisar el estado final.

## Workflow

1. Abrir **Windows PowerShell de 64 bits como administrador** en la carpeta del repositorio.
2. Consultar el estado sin instalar nada:

   ```powershell
   .\Repair-MediaFeaturePack.ps1
   ```

3. Previsualizar la operación o instalar únicamente Media Feature Pack:

   ```powershell
   .\Repair-MediaFeaturePack.ps1 -Install -WhatIf
   .\Repair-MediaFeaturePack.ps1 -Install
   ```

4. Si aparece `InstallPending` o se indica que hace falta reiniciar, guardar el trabajo y **reiniciar manualmente**. El script no reinicia ni programa reinicios.
5. Volver a consultar el estado:

   ```powershell
   .\Repair-MediaFeaturePack.ps1
   ```

   Se espera `CapabilityState: Installed` y `RuntimePresent: True`. Estos indicadores comprueban el componente; **no prueban por sí solos que la cámara funcione**.
6. Abrir Cámara y comprobar la vista previa. Para verificar la webcam por una segunda vía, usar la captura opcional descrita abajo. Destapar el lente y apuntarlo hacia una escena iluminada.

Si Windows bloquea la ejecución del archivo, se puede revisar su contenido y ejecutar esta invocación limitada a ese proceso, sin cambiar la política permanente:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Repair-MediaFeaturePack.ps1 -Install
```

### Origen local opcional

Si se dispone de un repositorio oficial de Features on Demand compatible, puede indicarse explícitamente:

```powershell
.\Repair-MediaFeaturePack.ps1 -Install -Source 'E:\LanguagesAndOptionalFeatures'
```

El origen debe incluir realmente la capacidad y sus dependencias. **No asumir que cualquier ISO de Windows o de idiomas contiene Media Feature Pack.** En el caso documentado, el medio Languages and Optional Features revisado incluía Media Player, pero no el paquete completo necesario; no fue el origen que resolvió el problema.

## Captura opcional con Python

Esta prueba abre la webcam localmente y guarda una foto; no la sube a ningún servicio. Requiere Python y OpenCV. La instalación de OpenCV sí necesita una descarga si aún no está instalado:

```powershell
py -m pip install -r requirements.txt
py .\capture_photo.py --output .\foto-prueba.jpg
```

Para seleccionar otra cámara, usar `--index 1`. Para reemplazar una foto existente, añadir `--overwrite`. La prueba no requiere ejecutar Python como administrador. Cerrar otras aplicaciones que estén usando la webcam antes de probar.

La existencia del archivo no es suficiente: **abrir la foto y comprobar que contiene la escena real**. Una imagen oscura puede deberse a una tapa física; una captura por DirectShow tampoco garantiza que todas las aplicaciones o el servidor de cámara de Windows funcionen.

## Qué se observó y qué no está demostrado

| Evidencia | Interpretación |
| --- | --- |
| Aviso “You need a media feature pack” y ausencia de `mfplat.dll` en System32 | Coincide con la dependencia multimedia ausente de Windows N. |
| Instalación normal: `0x800f0991`, con archivos multimedia faltantes en CBS | Falló la instalación del componente; no demuestra por sí solo un defecto físico de la webcam. |
| Instalación con `-LimitAccess`: éxito, `RestartNeeded: True`, `InstallPending` | Operación preparada correctamente; falta activar el cambio mediante reinicio. No tratar la ausencia de la DLL antes del reinicio como un fallo definitivo. |
| Después del reinicio: capacidad instalada, DLL presente y foto real de 1280 × 720 | Captura de la webcam verificada en el equipo de prueba. |

Antes del paso exitoso hubo otros intentos de instalación y mantenimiento, algunos fallidos y algunos que pudieron haber preparado archivos locales. **No se hizo una prueba controlada desde una instalación limpia:** no puede afirmarse que `-LimitAccess` por sí solo reproduzca el resultado en cualquier equipo.

Durante la comprobación, la aplicación Cámara también mostró `0xA00F429E <PageOpenFailed> (0x80004003)` y se observó un fallo de FrameServer, aun cuando DirectShow ya capturaba fotos. Se restablecieron los datos de Cámara, pero la prueba automatizada no confirmó después su vista previa. El usuario confirmó que la cámara funcionaba. Este repositorio no presenta ese restablecimiento ni una modificación del registro como una solución verificada para ese segundo error.

Si persiste el problema, distinguir entre **componente ausente**, **fallo de una aplicación** y **fallo de captura del dispositivo**. No repetir indefinidamente el instalador ni pasar directamente a reinstalar Windows basándose solamente en este aviso.

## Alcance de los scripts

El script de reparación consulta la edición y el estado, y solo instala la capacidad cuando se usa `-Install`. Comprueba el estado después de la operación y respeta `-WhatIf`. No desinstala capacidades, no cambia permisos de cámara, no deshabilita servicios y no crea tareas programadas. No incluye controladores ni DLL redistribuidas.

No se incluyen fotos de prueba, registros del equipo, credenciales, nombres de usuario ni los intentos anteriores de reparación.

## Fuentes oficiales

- [Microsoft: Media Feature Pack para Windows 10/11 N](https://support.microsoft.com/en-us/windows/experience/platform-variants/media-feature-pack-for-windows-10-11-n-february-2023).
- [Microsoft Learn: Add-WindowsCapability y el parámetro LimitAccess](https://learn.microsoft.com/en-us/powershell/module/dism/add-windowscapability).
- [Microsoft Learn: Features on Demand y orígenes compatibles](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-v2--capabilities?view=windows-11).
- [Microsoft: La cámara no funciona en Windows](https://support.microsoft.com/en-us/windows/hardware/camera/camera-doesn-t-work-in-windows).

## Validación del repositorio

La comprobación automatizada valida sintaxis de PowerShell y Python y prueba las decisiones del script con operaciones de sistema simuladas: diagnóstico, instalación pendiente de reinicio, instalación activa, `-WhatIf` y fallos silenciosos. No instala capacidades, no reinicia el equipo y no intenta acceder a una webcam en GitHub Actions. La evidencia de captura procede de la prueba manual descrita arriba.
