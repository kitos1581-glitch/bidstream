# BidStream

Subastas en línea, por tiempo o en vivo con transmisión de YouTube.
Flutter (Android, iOS, web) + Firebase (Auth, Firestore, Storage, Cloud Functions).

> Este proyecto **ya no se edita en FlutterFlow**. Si lo vuelves a exportar
> desde FlutterFlow, se borran todos estos cambios.

---

## 1. Qué hace la app

| Pantalla | Qué hace |
|---|---|
| Acceso | Iniciar sesión, crear cuenta, recuperar contraseña |
| Completa tu cuenta | Verificar correo + nombre, teléfono, ciudad, términos |
| Subastas (inicio) | Búsqueda, categorías, sección "En vivo ahora", catálogo |
| Detalle del lote | Fotos, precio, cuenta regresiva, historial de pujas en tiempo real |
| Confirmar puja | Elegir monto (sugeridos u otro) y confirmar |
| Subasta en vivo | Video de YouTube dentro de la app + pujas rápidas |
| Publicar | Fotos (hasta 10), datos, precio, por tiempo o en vivo |
| Avisos | Te superaron / ganaste / vendiste / sin pujas |
| Mi cuenta | Mis pujas (ganando/superado), ganadas, mis ventas |

### Reglas del negocio (las aplica el servidor)
- Solo se puede pujar con **correo verificado** y **perfil completo**.
- **Puja proxy:** cada postor ofrece un máximo secreto. El precio visible solo
  sube lo necesario: el sistema puja por el líder superando al retador por el
  incremento, sin rebasar su máximo. En empate gana quien ofertó primero.
- Primera oferta: mínimo el precio inicial (el precio visible queda en el
  precio inicial). Retadores: al menos puja actual + incremento.
- El líder puede subir su máximo; eso no cambia el precio ni el cierre.
- El vendedor no puede pujar en su propio lote.
- **Anti-sniping:** una oferta válida con 30 s o menos para el cierre lo mueve
  a "ahora + 30 s".
- Tope contra errores de dedo: máximo $50,000,000 por oferta.
- Se requiere depósito de garantía (ver GUIA_PAGOS_MERCADO_PAGO.md).
- Cada minuto se cierran las subastas vencidas. El ganador y el vendedor
  reciben en sus avisos el contacto del otro.
- En el historial público solo se ve "Nombre + inicial" (ej. "Juan P.").

---

## 2. Estructura de datos (Firestore)

```
users/{uid}                     perfil privado (solo lo lee su dueño)
  ├─ notifications/{id}         avisos (los crea el servidor)
  └─ bidding/{lotId}            subastas donde pujó (las mantiene el servidor)
lots/{lotId}                    lote (público)
  ├─ bids/{bidId}               ofertas proxy: user_id, max_amount, current_effective_bid,
  │                             timestamp. PRIVADAS: cada quien solo lee las suyas
  ├─ history/{id}               historial público (sin máximos); auto=true si la
  │                             puja la hizo el sistema proxy
  └─ private/proxy_state        líder y su máximo; solo el servidor lo lee
```

Campos del lote: `title, description, category, image_urls, starting_price,
current_bid, minimum_increment, bid_count, start_time, end_time, status
(active|ended), format (timed|live), stream_url, seller_uid, seller_name,
highest_bidder_uid, highest_bidder_name, winner_uid, winner_name, final_price`.

---

## 3. Primera instalación

Necesitas: Flutter (stable), Node 20 y Firebase CLI (`npm i -g firebase-tools`).

```bash
# App
flutter pub get
flutter analyze          # revisa que no haya errores
flutter test             # pruebas unitarias

# Backend
cd firebase
firebase login
cd functions && npm install && npm test && cd ..
```

### En la consola de Firebase (proyecto `bidstream-656cf`)
1. **Plan Blaze** (pago por uso). Cloud Functions y la tarea programada lo
   exigen. Con poco uso el costo suele ser muy bajo, pero **pon una alerta de
   presupuesto** en Google Cloud.
2. **Authentication → Método de acceso → Correo/contraseña:** activado.
3. **Storage:** crea el bucket si no existe.
4. Plantilla del correo de verificación en español
   (Authentication → Plantillas).

### Desplegar backend
```bash
cd firebase
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```
Las variables de Mercado Pago y montos van en `firebase/functions/.env`
(ver GUIA_PAGOS_MERCADO_PAGO.md). Extra: `VERIFIED_BID_THRESHOLD=20000`.
Los índices tardan unos minutos en construirse. Mientras tanto, algunas
listas pueden marcar error de "index".

### Correr la app
```bash
flutter run -d chrome          # web
flutter run                    # celular conectado
```

### Publicar la versión web en Firebase Hosting
```bash
flutter build web --release
cd firebase && firebase deploy --only hosting
```

---

## 4. Cómo probar el flujo completo

Usa **dos cuentas** (ej. en Chrome normal y en ventana de incógnito):

1. Cuenta A: registrarse → verificar correo → completar perfil → publicar un
   lote "En vivo" que empiece ahora, de 15 min, con un enlace de YouTube.
2. Cuenta B: registrarse → verificar → completar perfil → entrar al lote →
   pujar.
3. Cuenta A no debe poder pujar en su propio lote.
4. Cuenta B puja otra vez → debe decir "Ya vas ganando".
5. Una tercera cuenta (o A con otro lote) supera a B → B recibe aviso "Te superaron".
6. Al terminar el tiempo (≤1 min de retraso) → avisos "Ganaste" y "Vendiste"
   con los contactos.

---

## 5. Administración

### Darte permisos de administrador
```bash
cd firebase/functions && npm install && cd ..
export GOOGLE_APPLICATION_CREDENTIALS=/ruta/fuera/del/proyecto/llave.json
node scripts/set_admin.js tu-correo@ejemplo.com
```
(La llave se descarga en Consola de Firebase → Configuración → Cuentas de
servicio. **Nunca la subas a git ni la compartas.**) Cierra sesión y vuelve a
entrar: en "Mi cuenta" aparece el botón **Administración**.

### Qué hace el panel
| Pestaña | Para qué |
|---|---|
| Identidad | Ver INE + selfie y aprobar/rechazar (con motivo) |
| Pagos | Transferir a vendedores (muestra su CLABE) y registrar la referencia SPEI; reintentar cobros que fallaron; ver reembolsos fallidos |
| Usuarios | Buscar por correo, ver depósito/strikes, suspender o reactivar |
| Lotes | Cancelar subastas activas (fraude, artículo prohibido) |

Cada acción queda registrada en la colección `admin_log`.

### Verificación de identidad (INE)
- **Obligatoria para vender** (lo exige `firestore.rules`).
- **Obligatoria para pujas mayores a $20,000** (configurable con
  `VERIFIED_BID_THRESHOLD` en `functions/.env`).
- Las fotos son privadas (`verifications/{uid}/` en Storage): solo el dueño y
  los admins las ven. Revisión manual; para automatizarla (comparación facial,
  validación contra el INE) se puede integrar un proveedor como Truora,
  MetaMap o Incode, que cobran por verificación.

### Pagos a vendedores
Son **manuales** a propósito: el panel muestra cuánto y a qué CLABE, tú
transfieres y registras la referencia, y el vendedor recibe un aviso.
Automatizarlo bien requiere el modelo "marketplace" de Mercado Pago (cada
vendedor conecta su cuenta y el pago se divide solo, con tu comisión), lo cual
cambia el flujo de cobro. Conviene hacerlo cuando el volumen lo justifique.

---

## 6. Asistente de IA para publicar

En "Publicar", el vendedor elige el estado (nuevo, como nuevo, usado,
usado con detalles, para reparar), puede escribir notas (año, km, fallas,
qué incluye) y toca **Llenar con IA**. Claude lee hasta 4 fotos y propone
título, categoría y descripción; además avisa:
- detalles visibles (rayones, golpes) — ya incluidos en la descripción,
- datos que los compradores van a preguntar,
- si el estado elegido no coincide con las fotos,
- si el artículo podría estar prohibido.

La IA nunca publica sola: el vendedor revisa y corrige. Se le prohíbe
inventar marca, modelo o especificaciones, y se borran teléfonos/correos.

Configuración en `functions/.env`:
```
ANTHROPIC_API_KEY=sk-ant-...     # console.anthropic.com → API Keys
AI_MODEL=claude-sonnet-5-5       # opcional
AI_DAILY_LIMIT=20                # usos por usuario por día (entero 1–1000)
AI_GLOBAL_DAILY_LIMIT=2000       # tope de toda la plataforma por día
```
Requisitos para usarlo: correo verificado, identidad (INE) verificada y
cuenta no suspendida (los mismos que para vender). Si la llamada a la IA
falla o la respuesta viene incompleta, **no se descuenta el uso**. Una
configuración inválida (p. ej. `AI_DAILY_LIMIT=abc`) desactiva solo el
asistente con un error explícito en los logs; el resto de la app sigue.
Costo aproximado: unos centavos de dólar por descripción (4 fotos). Pon un
límite de gasto mensual en la consola de Anthropic.

## 7. Comisión

Por defecto es 10% plano (`COMMISSION_PCT`). Para cobrar por tramos
(recomendado si hay vehículos, ganado o maquinaria):
```
COMMISSION_TIERS=10000:0.10,100000:0.08,inf:0.06
COMMISSION_MIN=50
```
= 10% de los primeros $10,000, 8% de $10,000 a $100,000, 6% del resto, con
mínimo de $50 por venta.

**Configuración inválida = error explícito.** Si `COMMISSION_TIERS`,
`COMMISSION_PCT` o `COMMISSION_MIN` son inválidos, el sistema NO usa otro
porcentaje en silencio: el pago del comprador se registra normalmente, pero
la liquidación al vendedor queda **"en revisión"** (panel de administración →
Pagos). Corrige el `.env`, redespliega funciones y pulsa **Recalcular**. Es marginal (como el ISR): no hay brincos entre
tramos. Recuerda que de la comisión se paga la tarifa de Mercado Pago
(≈3.49% + $4 + IVA por cobro con liberación inmediata).

## 7.1 Pago final por SPEI (Openpay) — opcional

El ganador elige entre **Mercado Pago** (tarjeta o saldo) y **transferencia
SPEI** (recomendada en montos altos: comisión mucho menor y sin contracargos).

- `chooseWinnerPaymentMethod({lotId, method})` → respuesta tipada
  `{ok, method, url}` (MP) o `{ok, method, clabe, bank, reference, amount, dueTime}` (SPEI).
  Errores con `details.code`: `NOT_WINNER`, `NOT_PENDING`, `PAYMENT_EXPIRED`,
  `METHOD_NOT_AVAILABLE`, `PROVIDER_NOT_CONFIGURED`, `PROVIDER_ERROR`, `IN_PROGRESS`.
- Una sola referencia por lote (`order_id = win_{lotId}`); la CLABE se guarda en
  `payments/openpay_charge_{id}` (privado), nunca en el lote (público).
- `openpayWebhook` (autenticación básica) consulta el cargo en Openpay antes de
  aplicarlo; candado `payments/openpay_{chargeId}`.
- SPEI tardío o duplicado: no se puede devolver por API → `payments` con
  `status: manual_required`, visible en el panel (Pagos → reembolsos).
- Si Openpay no está configurado, el lote solo ofrece Mercado Pago.

Variables en `functions/.env`:
```
OPENPAY_MERCHANT_ID=...
OPENPAY_PRIVATE_KEY=sk_...
OPENPAY_SANDBOX=true            # obligatorio: true | false
OPENPAY_WEBHOOK_USER=...        # ≥6 caracteres
OPENPAY_WEBHOOK_PASS=...        # ≥16 caracteres
```
Webhook en Openpay: `https://us-central1-<proyecto>.cloudfunctions.net/openpayWebhook`
con ese usuario y contraseña; el código de verificación aparece en los logs.

## 8. Notificaciones push

Cada aviso que crea el servidor (te superaron, ganaste, pago, etc.) se manda
también como push a todos los dispositivos del usuario.

- **Android:** funciona tal cual.
- **iOS:** en la consola de Firebase → Configuración → Cloud Messaging, sube
  tu **llave APNs** (.p8) de Apple Developer. En Xcode activa la capacidad
  *Push Notifications*. Antes de publicar en la App Store cambia
  `aps-environment` a `production` en `ios/Runner/Runner.entitlements`.
- **Web:** en Cloud Messaging → *Web Push certificates* genera la **clave
  VAPID** y compila con:
  ```bash
  flutter build web --release --dart-define=FCM_VAPID_KEY=tu_clave
  ```

---

## 9. Pruebas

```bash
cd firebase/functions && npm test        # backend (Firestore/MP/IA simulados)
cd firebase/rules-tests && npm test      # reglas con el emulador oficial
flutter analyze && flutter test          # app
bash firebase/scripts/verificar_remoto.sh   # estado remoto, solo lectura
```
Resultados de esta versión: ver `EVIDENCIA_PRUEBAS.md`.

## 10. Pendientes

- Revisión legal en México: términos y condiciones (depósito, comisión,
  castigos), aviso de privacidad (INE, datos bancarios, pagos), PROFECO, y si
  retener depósitos de terceros te obliga a algún registro.
- Pagos automáticos a vendedores (modelo marketplace de Mercado Pago).
- Verificación de identidad automática (proveedor externo).
- Precio de reserva, "compra ya", reportar lotes.
