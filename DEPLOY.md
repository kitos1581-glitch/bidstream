# DEPLOY — Subástalo Aquí, desde cero

Guía para desplegar a producción en una computadora limpia.

> **Estado al 2026-10-15: NO EJECUTADO.** Nada de esta guía se ha ejecutado
> contra el proyecto real `bidstream-656cf`. Hoy producción sigue con:
> - las reglas viejas de FlutterFlow;
> - Storage sin activar;
> - plan Spark (sin Blaze).
>
> Cada paso que necesita la consola, una cuenta o un cobro está marcado
> **LISTO PARA EJECUTAR HUMANO**. Al terminar cada sección, anota la fecha y
> el resultado en `EVIDENCIA_PRUEBAS.md`.

**Tiempo estimado:**
- 2–3 horas de trabajo;
- más la espera de índices (minutos);
- más la verificación de dominio (hasta 24 h por DNS).

**Orden obligatorio:**

0 → a → b → c → (b.4 funciones) → d → e (en monitor) → f → g → h.

App Check se pasa a *enforce* **mínimo 7 días después** (§e.4).

---

## 0. Requisitos de la computadora

| Herramienta | Versión | Comando para verificar |
|---|---|---|
| Git | cualquiera | `git --version` |
| Node.js | **20** (lo exige `functions/package.json`) | `node -v` → `v20.x` |
| Firebase CLI | reciente | `npm i -g firebase-tools` → `firebase --version` |
| Flutter | stable | `flutter --version` |
| Google Cloud CLI (opcional, para §h) | reciente | `gcloud --version` |

```bash
git clone https://github.com/kitos1581-glitch/bidstream.git
cd bidstream
git checkout v1.0.0                 # despliega SIEMPRE una versión etiquetada
flutter pub get
cd firebase/functions && npm ci && npm test && cd ../..   # deben pasar todas
```

Si `npm test` falla, **no despliegues**.

---

## 0-bis. Desplegar desde GitHub (sin instalar nada) — RECOMENDADO

El workflow `.github/workflows/desplegar_firebase.yml` hace todo el despliegue
en los servidores de GitHub, así que no necesitas Flutter ni Node en tu
computadora. Es **manual**: solo corre cuando tú lo ejecutas y escribes
`DESPLEGAR` para confirmar.

**Configuración inicial (se hace una sola vez) — LISTO PARA EJECUTAR HUMANO**

1. **Crea la cuenta de servicio.**
   1. Entra a Google Cloud Console → IAM y administración → **Cuentas de
      servicio** (proyecto `bidstream-656cf`) → **Crear cuenta de servicio**.
   2. Ponle el nombre `github-deploy`.
   3. Asígnale los roles para desplegar **hosting**:
      - **Firebase Hosting Admin**;
      - **API Keys Viewer**;
      - **Cloud Run Viewer**, porque el *rewrite* `/l/**` apunta a una función.
   4. Para desplegar **reglas, índices y funciones** hacen falta más roles.
      Se agregan **cuando se active Blaze**, y la lista exacta se confirma con
      el primer despliegue (**NO VERIFICADO** todavía):
      - Firebase Rules Admin;
      - Cloud Datastore Index Admin;
      - Cloud Functions Admin;
      - Service Account User;
      - Cloud Scheduler Admin;
      - Artifact Registry Administrator.
2. **Descarga la llave.** En la cuenta `github-deploy`, ve a **Claves** →
   **Agregar clave** → **JSON**. Se descarga un archivo `.json`.
3. **Guarda la llave en GitHub.**
   1. En el repositorio, ve a **Settings** → **Secrets and variables** →
      **Actions** → **New repository secret**.
   2. Nombre: `FIREBASE_SERVICE_ACCOUNT`. Valor: pega **todo** el contenido
      del `.json`.
   3. Después **borra el archivo `.json` de tu computadora**. No lo mandes
      por WhatsApp ni por correo.
4. **Agrega los secretos opcionales**, en el mismo lugar:
   - `FUNCTIONS_ENV`: el contenido completo del `.env` de funciones (§c);
     solo hace falta para desplegar funciones;
   - `APP_CHECK_SITE_KEY` y `FCM_VAPID_KEY`.
5. **(Recomendado) Protege el ambiente.** Ve a **Settings** →
   **Environments** → `produccion` → **Required reviewers** y ponte a ti.
   Así, cada despliegue espera tu aprobación aunque alguien más lo lance.

**Para desplegar**

1. Ve a **Actions** → **Desplegar a Firebase** → **Run workflow**.
2. En `destino`, elige:
   - `hosting`: solo la web;
   - `reglas-e-indices`;
   - `funciones`: requiere Blaze y `FUNCTIONS_ENV`;
   - `todo`: despliega en el orden índices → reglas → storage → funciones →
     hosting.
3. En `confirmar`, escribe `DESPLEGAR`.

> Mientras **no** se desplieguen reglas y funciones, la web en
> `subastaloaqui.com` se verá pero **no podrá pujar ni cobrar**. Conviene
> mantenerla sin anunciar (`noindex` sigue activo) hasta completar el resto
> de esta guía.

## a. Plan Blaze y límites de gasto — LISTO PARA EJECUTAR HUMANO

Cloud Functions, las tareas programadas y Storage exigen el plan Blaze (pago
por uso). Las tareas programadas son:

| Tarea | Frecuencia |
|---|---|
| `closeEndedAuctions` | cada minuto |
| `expireUnpaidWins` | cada 15 min |
| `releaseDuePayoutsJob` | cada hora |

1. Abre Consola de Firebase → proyecto `bidstream-656cf` → ⚙ → **Uso y
   facturación** → **Detalles y configuración** → **Modificar plan** →
   **Blaze**.
2. Liga una cuenta de facturación con una tarjeta **del negocio**.
3. **Alerta de presupuesto.** Las alertas avisan pero **no detienen** el gasto.
   1. Entra a Google Cloud Console → Facturación → **Presupuestos y alertas** →
      **Crear presupuesto**.
   2. En Alcance, elige el proyecto `bidstream-656cf`.
   3. Pon un monto mensual, por ejemplo **$500 MXN** para el arranque.
      Ajústalo con el uso real.
   4. Configura umbrales de aviso al **50 %, 90 % y 100 %** (gasto real) y al
      **100 % pronosticado**.
   5. Agrega como destinatarios a los administradores de facturación y a tu
      correo.
4. Pon el límite de gasto de la IA aparte. En console.anthropic.com → **Limits**,
   define un tope mensual. `AI_GLOBAL_DAILY_LIMIT` limita los usos, pero no
   los dólares.
5. Limita también Mercado Pago y Openpay. No tienen "presupuesto", pero revisa
   que las notificaciones de cobros lleguen al correo del negocio.

> Si quieres un **corte duro** de gasto, Google documenta cómo desactivar la
> facturación con Pub/Sub + una función cuando se rebasa el presupuesto. Eso
> **apaga todo el sitio**, así que no lo recomiendo en temporada de Buen Fin.
> Con alertas es suficiente.

---

## b. Firebase CLI y despliegue en orden

### b.1 Sesión y proyecto
```bash
cd firebase
firebase login                      # abre el navegador; usa la cuenta dueña del proyecto
firebase use bidstream-656cf        # ya está como "default" en .firebaserc
firebase projects:list              # el proyecto debe aparecer marcado como (current)
```

### b.2 Servicios en consola antes del primer deploy — LISTO PARA EJECUTAR HUMANO
1. **Authentication** → Método de acceso → **Correo/contraseña**: activado.
   - En Plantillas, pon el idioma en **español**.
   - En **Dominios autorizados**, agrega:
     - `subastaloaqui.com` y `www.subastaloaqui.com` (§g);
     - `bidstream-656cf.web.app`;
     - `kitos1581-glitch.github.io` (staging).
2. **Firestore**: la base ya existe; confirma su ubicación.
3. **Storage** → Comenzar.
   - Elige la **misma región** que Firestore.
   - Desde octubre de 2024, los buckets nuevos requieren Blaze; por eso va
     después de §a.
4. **CORS de Storage.** Sin este paso, la versión web de Flutter **no muestra
   las fotos** de los lotes.
   ```bash
   gcloud storage buckets update gs://bidstream-656cf.firebasestorage.app \
     --cors-file=storage.cors.json
   # (si tu bucket es el antiguo: gs://bidstream-656cf.appspot.com)
   ```
   El archivo `firebase/storage.cors.json` está en el repo. Solo permite `GET`
   desde cualquier origen, porque las fotos de los lotes son públicas por
   diseño. Las fotos de INE siguen protegidas por las reglas de Storage.

### b.3 Despliegue de base de datos y reglas (en este orden)
```bash
# 1) Índices primero: las reglas y funciones nuevas hacen consultas que los necesitan.
firebase deploy --only firestore:indexes
# Espera a que TODOS estén "Habilitado"/READY:
#   Consola → Firestore → Índices   (o: gcloud firestore indexes composite list)

# 2) Reglas de Firestore (deny-by-default).
firebase deploy --only firestore:rules

# 3) Reglas de Storage.
firebase deploy --only storage
#   (en la CLI, "storage" despliega storage.rules; equivale a "storage:rules")
```

> ⚠️ **Corte con la app vieja.** Las reglas nuevas niegan las escrituras
> directas que hacía la app de FlutterFlow. Las consecuencias:
> - una app vieja instalada deja de poder pujar y publicar;
> - los lotes y usuarios existentes que no cumplan el esquema nuevo seguirán
>   visibles, pero no se podrán editar desde la app.
>
> Despliega reglas y funciones **en la misma sesión**.

### b.4 Funciones (después de §c)
```bash
cd firebase
firebase deploy --only functions
```
- La primera vez, la CLI pide activar varias APIs: Cloud Functions, Cloud
  Build, Artifact Registry, Cloud Scheduler y Eventarc. **Acepta.**
- Si pregunta por una política de limpieza de imágenes en Artifact Registry,
  pon **1 día**. Evita cobros por almacenamiento de imágenes viejas.
- Se deben crear **34 funciones**. La lista exacta está en
  `scripts/verificar_remoto.sh`.
- Si falla una sola, la CLI lo dice; repite el comando. Es seguro, porque el
  deploy es idempotente.

### b.5 Hosting (después de §g)
```bash
cd ..                                   # raíz del repo
flutter build web --release \
  --dart-define=APP_CHECK_SITE_KEY=<site key reCAPTCHA v3> \
  --dart-define=FCM_VAPID_KEY=<clave VAPID> \
  --dart-define=SHARE_BASE_URL=https://subastaloaqui.com \
  --dart-define=WEB_APP_URL=https://subastaloaqui.com
# NUNCA uses --dart-define=DEMO_LOTS=true en producción: es solo para GitHub Pages.
rm -rf firebase/web_build && cp -r build/web firebase/web_build   # Firebase solo publica carpetas dentro de firebase/
cd firebase && firebase deploy --only hosting
```

---

## c. Variables de entorno — inventario completo

Van en `firebase/functions/.env`. La plantilla es
[`firebase/functions/.env.example`](firebase/functions/.env.example):

```bash
cd firebase/functions
cp .env.example .env
nano .env              # (o tu editor)
```

- `.env` está en `.gitignore`. **Nunca lo subas ni lo mandes por WhatsApp.**
- Si una variable obligatoria falta o es inválida, el módulo afectado responde
  con un error explícito. **El código no usa nunca otro valor en silencio.**
- Después de cambiar `.env`, vuelve a ejecutar `firebase deploy --only functions`.

| Variable | ¿Obligatoria? | Default | Para qué | Ejemplo ficticio |
|---|---|---|---|---|
| `MP_ACCESS_TOKEN` | **Sí** | — | Token de Mercado Pago (depósito y pago del ganador). Primero `TEST-…`, en producción `APP_USR-…`. | `TEST-0000…-000000000` |
| `MP_WEBHOOK_SECRET` | **Sí** | — | Clave secreta que **genera MP** en Webhooks (§d.1). Valida la firma `x-signature`. Sin ella, todo webhook responde 401. | `9f3c…` (64 hex) |
| `WEBHOOK_URL` | **Sí** | vacío | URL de `mpWebhook`. Se manda como `notification_url` en cada cobro. | `https://us-central1-bidstream-656cf.cloudfunctions.net/mpWebhook` |
| `SITE_URL` | **Sí** (en la práctica) | `https://bidstream.web.app` ⚠️ **ese default NO es tu sitio** | Página a la que MP regresa al comprador después de pagar. | `https://subastaloaqui.com` |
| `DEPOSIT_AMOUNT` | No | `200` | Depósito de garantía en MXN. | `200` |
| `WINNER_PAYMENT_WINDOW_HOURS` | No | `24` | Horas que tiene el ganador para pagar. | `24` |
| `VERIFIED_BID_THRESHOLD` | No | `20000` | Las pujas mayores a este monto exigen INE verificada. | `20000` |
| `PAYOUT_RELEASE_DAYS` | No | `7` | Días de retención antes de liberar al vendedor (entero de 1 a 60). Si es inválido, no se libera nada automáticamente y aparece un error en los logs. | `7` |
| `COMMISSION_TIERS` | No | — | Tramos marginales `límite:pct`; el último es `inf`. | `10000:0.10,100000:0.08,inf:0.06` |
| `COMMISSION_PCT` | No | `0.10` | Porcentaje plano. Solo aplica si no existe `COMMISSION_TIERS`. | `0.10` |
| `COMMISSION_MIN` | No | `0` | Comisión mínima por venta, en MXN. | `50` |
| `COMMISSION_PROMO` | No | sin campaña | Ventana de 0 % en formato ISO con zona horaria, `inicio/fin`, de 62 días como máximo. Hay **una sola** ventana; "campañas con nombre" (`CAMPAIGN_*`) **no existen** (ROADMAP R-46). | `2026-11-13T00:00:00-06:00/2026-11-17T23:59:59-06:00` |
| `ZERO_COMMISSION_FEE_PAYER` | No | `seller` | Con 0 %, quién paga el costo real del procesador: `seller` o `platform`. | `seller` |
| `OPENPAY_MERCHANT_ID` | Solo con SPEI | — | ID de comercio de Openpay. | `m0000000000000000000` |
| `OPENPAY_PRIVATE_KEY` | Solo con SPEI | — | Llave privada `sk_…`. **Nunca va en la app.** | `sk_0000…` |
| `OPENPAY_SANDBOX` | Solo con SPEI | — (obligatoria) | `true` (pruebas) o `false` (producción). | `true` |
| `OPENPAY_WEBHOOK_USER` | Solo con SPEI | — | Usuario de autenticación básica del webhook; **lo eliges tú**. Mínimo 6 caracteres. | `openpay-hook` |
| `OPENPAY_WEBHOOK_PASS` | Solo con SPEI | — | Contraseña del webhook. Mínimo 16 caracteres; genérala con `openssl rand -hex 16`. | `3b1f…` |
| `ANTHROPIC_API_KEY` | Solo con IA | — | Llave para el asistente de publicación. Si falta, solo se apaga el asistente. | `sk-ant-api03-…` |
| `AI_MODEL` | No | `claude-sonnet-5-5` | Modelo de IA. | `claude-sonnet-5-5` |
| `AI_DAILY_LIMIT` | No | `20` | Usos por usuario al día (de 1 a 1000). | `20` |
| `AI_GLOBAL_DAILY_LIMIT` | No | `2000` | Usos de toda la plataforma al día. | `2000` |
| `APP_CHECK_MODE` | No | `monitor` | `monitor`, `enforce` u `off` (§e). ⚠️ Lleva guion bajo: `APP_CHECK_MODE`, no `APPCHECK_MODE`. | `monitor` |
| `SEO_NOINDEX` | No | `true` | Las tarjetas `/l/{id}` llevan `noindex` hasta el lanzamiento SEO (R-30). | `true` |

**Variables que pidió el plan pero NO existen en el código** (no las pongas,
no hacen nada):
- `STORE_PLAN_PRICE`: la membresía se cobra fuera de la app (R-42).
- `CAMPAIGN_*`: hay una sola ventana, `COMMISSION_PROMO` (R-46).

**Valores que se pasan al compilar la app** (`--dart-define`). No son secretos
de servidor:

| Clave | Para qué |
|---|---|
| `APP_CHECK_SITE_KEY` | Site key **pública** de reCAPTCHA v3 (§e.1). |
| `FCM_VAPID_KEY` | Clave pública Web Push. Está en Consola → Configuración → Cloud Messaging → Certificados web push. |
| `SHARE_BASE_URL` | Dominio con Hosting para las ligas `/l/{id}` (§g). |
| `WEB_APP_URL` | Solo móvil sin `SHARE_BASE_URL`. Por defecto apunta a GitHub Pages; en producción pon el dominio final. |
| `DEMO_LOTS` | **Solo staging.** Nunca en producción. |

Para validar el `.env` sin desplegar:
```bash
cd firebase && bash scripts/verificar_remoto.sh   # la sección 6 valida localmente, sin red
```

---

## d. Webhooks — LISTO PARA EJECUTAR HUMANO

URLs (las crea el deploy de §b.4):

```
https://us-central1-bidstream-656cf.cloudfunctions.net/mpWebhook
https://us-central1-bidstream-656cf.cloudfunctions.net/openpayWebhook
```

### d.1 Mercado Pago
1. Entra a mercadopago.com.mx/developers → **Tus integraciones** → tu
   aplicación → **Webhooks** → **Configurar notificaciones**.
2. En **URL modo pruebas** y en **URL modo producción**, pon la URL de
   `mpWebhook`. Es la misma función para los dos modos.
3. En eventos, marca **Pagos**. Guarda.
4. MP **genera la clave secreta**: revélala y cópiala a `MP_WEBHOOK_SECRET`.
   Después vuelve a desplegar las funciones.
   - La guía antigua decía "genérala con openssl"; **es incorrecto**. La clave
     la da Mercado Pago y no caduca. Si la restableces, actualiza `.env` y
     vuelve a desplegar.
5. Prueba negativa, segura y sin dinero. Una petición sin firma **debe**
   responder 401:
   ```bash
   curl -i -X POST "https://us-central1-bidstream-656cf.cloudfunctions.net/mpWebhook?type=payment&data.id=1"
   # Esperado: HTTP/2 401 … invalid signature
   ```
6. Prueba positiva:
   1. Con usuarios de prueba (GUIA_PAGOS_MERCADO_PAGO.md, paso 1), deja un
      depósito de $200 desde la app (CHECKLIST_E2E.md §3).
   2. En el panel de MP → Webhooks → **historial de notificaciones**, la
      entrega debe aparecer con **200**.
   3. En Firebase, `users/{uid}.deposit.status` debe quedar en `held`.
   - Si aparece **401**: el secreto no coincide.
   - Si aparece **500**: revisa `firebase functions:log --only mpWebhook`.
     MP reintenta solo cada 15 min, y es seguro porque el procesamiento es
     idempotente.
7. Para pasar a producción:
   1. Cambia `MP_ACCESS_TOKEN` a `APP_USR-…` y vuelve a desplegar las funciones.
   2. Haz **un cobro real pequeño**: deposita $200 y pide el reembolso.

### d.2 Openpay (SPEI, opcional)
1. Entra a dashboard sandbox de Openpay → **Configuración** → **Webhooks** →
   **Agregar**.
   - **URL:** la de `openpayWebhook`.
   - **Usuario y contraseña:** los mismos que pusiste en
     `OPENPAY_WEBHOOK_USER` y `OPENPAY_WEBHOOK_PASS` (autenticación básica).
   - **Eventos:** al menos `charge.succeeded`. Los demás se ignoran con 200.
2. Al guardar, Openpay manda un evento `verification`. Copia el código de los logs:
   ```bash
   firebase functions:log --only openpayWebhook | grep "Código de verificación"
   ```
   Pégalo en el panel para **verificar** el webhook.
3. Prueba negativa (debe dar 401):
   ```bash
   curl -i -X POST -u mal:credencial https://us-central1-bidstream-656cf.cloudfunctions.net/openpayWebhook
   ```
4. Prueba positiva:
   1. Elige SPEI como ganador; el paso 7 de CHECKLIST_E2E.md da la CLABE de
      prueba.
   2. Simula el pago desde las herramientas de sandbox de Openpay.
   3. El lote debe pasar a `payment_status: paid` y el payout a `held`.
   - **NO VERIFICADO:** no he confirmado cómo simula hoy el panel de Openpay
     una transferencia SPEI en sandbox. Si tu panel no lo ofrece, pide a
     soporte de Openpay el procedimiento. **No pases a producción sin esa
     prueba.**
5. Para pasar a producción:
   1. Pon `OPENPAY_SANDBOX=false` y las llaves de producción.
   2. Registra el webhook de nuevo en el dashboard **de producción**.

---

## e. App Check — LISTO PARA EJECUTAR HUMANO

La app ya llama a `FirebaseAppCheck.activate` (`lib/main.dart`) con estos
proveedores:
- **web:** reCAPTCHA v3;
- **Android:** Play Integrity;
- **iOS:** DeviceCheck;
- **modo debug:** el proveedor *debug*.

Las **22 funciones callable** aplican `APP_CHECK_MODE`. Los dos webhooks, los triggers y las tareas programadas no lo usan porque no los llama la app.

### e.1 Registrar cada app en Consola → App Check → Apps
| Plataforma | Qué necesitas | Dónde se pone |
|---|---|---|
| Web | Crea una clave **reCAPTCHA v3** en google.com/recaptcha/admin con los dominios: el final, `bidstream-656cf.web.app`, `kitos1581-glitch.github.io` y `localhost`. | La **secret key** va en App Check → app web → reCAPTCHA. La **site key** va en `--dart-define=APP_CHECK_SITE_KEY` (§b.5). |
| Android | La app tiene que estar en Google Play (aunque sea en prueba interna). Copia el SHA-256 del **certificado de firma de apps** desde Play Console → Integridad de la app. Vincula el proyecto de Cloud en Play Console → Integridad de la app → API Play Integrity. | App Check → app Android → Play Integrity → huella SHA-256. ⚠️ Depende de R-04 (firma release) y R-05 (ID de la app). |
| iOS | Apple Developer → Keys → nueva llave con **DeviceCheck** → archivo `.p8`, Key ID y Team ID. | App Check → app iOS → DeviceCheck. ⚠️ El `.p8` **no se versiona** (está en `.gitignore`). |
| Desarrollo | Ejecuta la app en modo debug y copia el *debug token* de la consola de la app. | App Check → app → menú ⋮ → **Administrar tokens de depuración**. |

### e.2 Arranque en modo monitor (día 0)
- Deja `APP_CHECK_MODE=monitor`; es el valor por defecto.
- En la consola de App Check, **NO** actives *Enforce* en Firestore ni en
  Storage todavía.
- Despliega la web compilada con `APP_CHECK_SITE_KEY`.

### e.3 Ventana de tolerancia (mínimo 7 días, y que incluya un fin de semana)
Mide a diario:
- **Consola → App Check → APIs**: en Cloud Firestore, Cloud Storage y Cloud
  Functions revisa el % de solicitudes **verificadas**.
- **Funciones:** cuenta las llamadas sin token.
  ```bash
  firebase functions:log | grep -c "Llamada sin token de App Check"
  ```

**Criterio para pasar a enforce** (los tres deben cumplirse):
1. **≥ 98 %** de solicitudes verificadas durante 3 días seguidos.
2. Las llamadas sin token que quedan corresponden a uids que identificas: tus
   pruebas o versiones viejas.
3. La web en producción ya está compilada con la site key.

### e.4 Paso a enforce (escalonado)
1. **Funciones:** pon `APP_CHECK_MODE=enforce` en `.env` y ejecuta
   `firebase deploy --only functions`.
   Una app sin token ve el mensaje *"Actualiza la app para continuar
   (verificación de dispositivo)"*.
2. Espera **48 h** observando errores `APP_CHECK_REQUIRED` en los logs.
3. **Firestore:** en Consola → App Check → APIs → Cloud Firestore → **Aplicar**.
4. Espera 48 h.
5. **Storage:** en Consola → App Check → APIs → Cloud Storage → **Aplicar**.

### e.5 Rollback, en menos de 5 minutos
- **Firestore o Storage:** en Consola → App Check → APIs → la API afectada →
  **Dejar de aplicar**. Es inmediato y no requiere deploy.
- **Funciones:** pon `APP_CHECK_MODE=monitor` y ejecuta
  `firebase deploy --only functions --force`. Tarda unos 2–3 min.
- **Emergencia total:** `APP_CHECK_MODE=off` (solo temporal; anótalo en
  EVIDENCIA_PRUEBAS.md).
- **No borres** las apps registradas en App Check: volver a registrarlas
  cambia las claves.

---

## f. Administrador inicial — LISTO PARA EJECUTAR HUMANO

1. Regístrate en la app con el correo que será admin y verifica el correo.
2. En Consola → ⚙ Configuración del proyecto → **Cuentas de servicio** →
   **Generar nueva clave privada**. Guárdala **fuera** del repo, por ejemplo en
   `~/claves/bidstream-admin.json`.
3. Desde la raíz del repo:
   ```bash
   cd firebase
   export GOOGLE_APPLICATION_CREDENTIALS=~/claves/bidstream-admin.json
   node scripts/set_admin.js tu-correo@negocio.mx
   # → "tu-correo@negocio.mx ahora es administrador (uid …)"
   ```
4. Cierra sesión en la app y vuelve a entrar. En **Mi cuenta** aparece
   **Administración**.
5. **Borra la llave** o guárdala cifrada. Si se filtra, revócala en la misma
   pantalla (Cuentas de servicio → Administrar permisos → llaves).
6. Para quitar el rol de admin: `node scripts/set_admin.js correo --quitar`.

---

## g. Firebase Hosting, tarjetas OG y dominio — DOMINIO COMPRADO; conexión LISTA PARA EJECUTAR HUMANO

**Por qué Hosting y no solo GitHub Pages.** La liga `/l/{id}` muestra foto y
precio al compartir en WhatsApp o Facebook. La genera la función
`lotPreview`, y solo funciona detrás de Firebase Hosting por el *rewrite* de
`firebase.json`. GitHub Pages **no puede** ejecutar funciones; se queda como
**staging** (con `DEMO_LOTS=true`).

**Decisión (2026-10-15).** Dominio principal: **`subastaloaqui.com`**.
`subastaloaqui.com.mx` se compró como protección y redirige al `.com`. Ambos
están registrados en **Neubox** y vencen el **15/10/2027**.
> ⚠️ La renovación automática está **apagada** porque no hay tarjeta guardada
> en Neubox. Activa la renovación o pon un recordatorio: si el dominio vence,
> la app y las ligas dejan de funcionar.

**DNS recomendado: Cloudflare** (gratis). Ahí se manejan los registros de
Firebase y además da **Email Routing** gratuito para `contacto@subastaloaqui.com`.

0. Configura Cloudflare:
   1. En Cloudflare → **Add a site** → `subastaloaqui.com` → plan **Free**.
      Cloudflare te da **2 nameservers**.
   2. En Neubox → Mis Dominios → 🔧 de `subastaloaqui.com` → **Nameservers /
      DNS** → personalizados → pega los 2 de Cloudflare.
   3. Repite los dos pasos anteriores con `subastaloaqui.com.mx`.
   4. Espera a que Cloudflare marque los dominios como **Active**: entre
      minutos y 24 h.

Pasos, ya con el dominio comprado:
1. En Consola → Hosting → **Agregar dominio personalizado**:
   1. Agrega `subastaloaqui.com`.
   2. Agrega en **Cloudflare → DNS** los registros **TXT** y **A** que indique
      la consola. Ponlos en **"DNS only" (nube gris)**: con la nube naranja
      (proxy), Firebase no puede emitir el certificado y la verificación falla.
   3. Agrega también `www.subastaloaqui.com` y `subastaloaqui.com.mx`. Para
      ambos elige **"Redirigir a un dominio existente" → subastaloaqui.com** y
      pon sus registros en Cloudflare, también con nube gris.
   4. Espera la verificación (hasta 24 h). El SSL se emite solo.
   - El dominio se puede conectar con el plan gratuito. La liga `/l/{id}` solo
     funciona cuando las funciones estén desplegadas (Blaze, §a).
2. **Correo** (opcional, gratis):
   1. En Cloudflare → **Email** → **Email Routing**, crea
      `contacto@subastaloaqui.com` y que reenvíe a tu Gmail.
   2. Usa ese correo en las fichas de Play Store y App Store y en los avisos.
2. Pon el dominio en todos estos lugares:
   - `SITE_URL=https://subastaloaqui.com` en `.env`, y despliega funciones;
   - Authentication → Dominios autorizados;
   - los dominios de la clave reCAPTCHA;
   - `--dart-define=SHARE_BASE_URL=https://subastaloaqui.com` y
     `WEB_APP_URL=https://subastaloaqui.com` al compilar.
3. Compila y despliega Hosting (§b.5).
4. Prueba en tu celular. Abre `https://subastaloaqui.com/l/<idDeUnLote>`: debe
   redirigir al lote. Pega la liga en WhatsApp: debe salir la tarjeta con foto.
   Si la tarjeta no se actualiza, depúrala en
   developers.facebook.com/tools/debug.

> `web/index.html` todavía usa como `og:image` genérica una imagen alojada en
> FlutterFlow. Cámbiala por el logo final cuando exista (R-06).

---

## h. Verificación post-deploy — LISTO PARA EJECUTAR HUMANO

```bash
cd firebase
gcloud auth login            # misma cuenta dueña
bash scripts/verificar_remoto.sh | tee /tmp/verificacion_$(date +%F).txt
```

El script es **de solo lectura**. Revisa:
1. que la facturación esté activa;
2. que estén las 34 funciones esperadas;
3. que los índices estén READY;
4. que las reglas publicadas sean idénticas a `firestore.rules`;
5. que estén las variables de `.env` (sin mostrar secretos);
6. que la configuración de comisiones, campaña, App Check, Openpay e IA sea
   válida.

Pega la salida completa en `EVIDENCIA_PRUEBAS.md`, sección "Verificación
remota", con la fecha. Antes de pegar, revisa que no salga ningún valor
secreto: el script solo imprime los valores de las variables no secretas.

Después ejecuta [`CHECKLIST_E2E.md`](CHECKLIST_E2E.md) completo en sandbox.
**Solo entonces** cambia las llaves a producción.
