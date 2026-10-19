# Subástalo Aquí

Marketplace de subastas para la región centro-sur de Chihuahua: Camargo,
Jiménez, Saucillo, Delicias, Parral y municipios vecinos.

- Usuarios **verificados**: correo e INE.
- **Puja proxy** con anti-sniping.
- **Pago retenido hasta la entrega** (escrow).
- **Reputación** y **protección al comprador**.

Funciona en Android, iOS y web, con Flutter + Firebase.

> **Versión 1.0.0** (2026-10-15).
>
> - Qué incluye: [`CHANGELOG.md`](CHANGELOG.md).
> - Qué falta: [`ROADMAP.md`](ROADMAP.md).
> - Cómo desplegar: [`DEPLOY.md`](DEPLOY.md).
> - Prueba manual: [`CHECKLIST_E2E.md`](CHECKLIST_E2E.md).
> - Pruebas ejecutadas: [`EVIDENCIA_PRUEBAS.md`](EVIDENCIA_PRUEBAS.md).
>
> **Estado:** el código y las pruebas están listos, pero **nada está
> desplegado todavía** en producción (R-01).
>
> El proyecto **ya no se edita en FlutterFlow**. Si se vuelve a exportar,
> se borra todo.

---

## 1. Arquitectura

```
 App Flutter (Android / iOS / web)
   │  lee: catálogo, historial, perfil público, sus propios datos
   │  escribe SOLO: su perfil, sus fotos, publicar/editar lote sin pujas
   │  todo lo demás → llamadas a funciones (con App Check)
   ▼
 Cloud Functions (Node 20, us-central1)  ── 34 funciones
   │  pujas, cierre, cobros, escrow, disputas, reputación, admin, IA
   │  transacciones + documento candado en todo lo que mueve dinero
   ├──► Firestore    (reglas deny-by-default, lista blanca al publicar)
   ├──► Storage      (fotos públicas de lotes; INE y pruebas privadas)
   ├──► Mercado Pago (depósito, pago del ganador, reembolsos) ◄── mpWebhook
   ├──► Openpay      (pago por SPEI, opcional)               ◄── openpayWebhook
   ├──► Anthropic    (asistente para redactar la publicación)
   └──► FCM          (push de cada aviso)
 Firebase Hosting: la web + /l/{id} (tarjeta para compartir en WhatsApp/Facebook)
```

**Principios del proyecto:**

1. El cliente **nunca** escribe precios, pujas, pagos, reputación ni estado
   de disputas.
2. Todo movimiento de dinero es **idempotente**: se protege con un documento
   candado en `payments/…`.
3. Ningún secreto se puede leer desde la app ni a través de las reglas. Eso
   incluye los máximos proxy, el precio de reserva, el código de entrega y
   las llaves.
4. Si una configuración es inválida, el sistema da un **error explícito**.
   Nunca usa otro valor en silencio.

### Módulos del backend (`firebase/functions/`)

| Módulo | Qué hace | Funciones exportadas |
|---|---|---|
| `index.js` | Pujas proxy, cierre de subastas, alta de lote. | `placeBid`, `closeEndedAuctions` (cada min), `onLotCreated` |
| `auction_logic.js` | Lógica pura de la puja: proxy, incrementos, anti-sniping, hora creciente del historial. | — |
| `payments.js` | Depósito, cobro al ganador, webhook de MP, castigo por no pagar, reembolsos, liquidación. | `createDeposit`, `requestDepositRefund`, `expireUnpaidWins` (cada 15 min), `mpWebhook` |
| `spei.js` + `openpay.js` | Pago del ganador por SPEI. | `chooseWinnerPaymentMethod`, `openpayWebhook` |
| `commission_policy.js` | Orden tienda → campaña → tramos, y costo real del procesador. | — |
| `escrow.js` | Retención y liberación; código de entrega en persona. | `confirmReceipt`, `confirmDeliveryCode`, `releaseDuePayoutsJob` (cada hora) |
| `delivery.js` | El ganador elige recoger o envío regional. | `chooseDelivery` |
| `reserve.js` | Precio de reserva secreto. | `setReservePrice` |
| `second_chance.js` | Ofrece el lote al subcampeón si el ganador no paga. | `respondSecondChance` |
| `disputes.js` | Reclamos con reembolso total o parcial, y clawback. | `openDispute`, `adminResolveDispute` |
| `reputation.js` | Calificaciones, perfil público, insignias. | `submitFeedback`, `updateFeedback`, `onPublicProfileInputs`, `onSaleRecorded` |
| `admin.js` | INE, suspensiones, payouts, cancelaciones, Tienda Oficial. | `submitIdentityVerification`, `adminReviewVerification`, `adminSetBan`, `adminMarkPayoutSent`, `adminRetryWinnerPayment`, `adminCancelLot`, `adminRecalculatePayout`, `adminSetStorePlan` |
| `ai.js` | Asistente de publicación (de las fotos saca título, categoría y descripción). | `generateLotDescription` |
| `share.js` | Tarjeta Open Graph de cada lote. | `lotPreview` |
| `push.js` | Envía un push por cada aviso. | `onNotificationCreated` |
| `appcheck.js` | App Check en las 22 funciones callable (modos `monitor`, `enforce` u `off`). | — |

### Datos (Firestore)

```
users/{uid}                 privado (dueño y admin). deposit, strikes, seller_strikes,
                            verified, seller_plan, store_* → solo el servidor
  ├─ notifications/{id}     avisos (los crea el servidor; el usuario marca leído)
  ├─ bidding/{lotId}        subastas donde pujó
  ├─ delivery_codes/{lotId} código de entrega (solo el comprador)
  ├─ fcm_tokens/{token}     dispositivos para push
  └─ ai_usage/{día}         cuota del asistente
lots/{lotId}                público. status: active | ended | ended_unsold_reserve | cancelled
                            payment_status: pending | paid | payment_error | forfeited
  ├─ bids/{id}              máximos proxy (cada quien lee solo los suyos)
  ├─ history/{id}           historial público (sin máximos)
  └─ private/*              proxy_state, reserve, delivery_code → nadie desde la app
payments/{id}               depósitos, cobros, payouts, reembolsos, clawbacks, candados
disputes/{lotId}            reclamos (comprador, vendedor y admin leen)
feedback/{lotId}            calificaciones (públicas)
public_profiles/{uid}       nombre público, ★, ventas, insignias (público, sin contacto)
verifications/{uid}         solicitud de INE
admin_log/{id}              bitácora de administradores
```

---

## 2. Reglas de la subasta

- **Para pujar** se necesita correo verificado, perfil completo y un depósito
  de garantía activo. Las pujas **mayores a $20,000** además exigen INE
  verificada (`VERIFIED_BID_THRESHOLD`).
- **Para vender** se necesita INE aprobada por un admin y una cuenta no
  suspendida.
- **Puja proxy:** cada postor ofrece un máximo secreto, y el precio visible
  sube solo lo necesario. En empate gana quien ofertó primero. El vendedor no
  puede pujar en sus propios lotes.
- **Anti-sniping:** una oferta válida en los últimos 2 min mueve el cierre a
  "ahora + 2 min" (conexiones de celular lentas en la región).
- **Precio de reserva** (solo en subastas por tiempo):
  - Es secreto: vive en `private/reserve`.
  - Si el máximo del líder alcanza la reserva, el precio salta a la reserva.
  - Si nadie la alcanza, el lote cierra como `ended_unsold_reserve`, sin
    cobro.
- **Precio fijo y "Comprar ahora"** (R-10):
  - El vendedor elige **Subasta** o **Precio fijo** (1 pieza, publicado
    7–60 días). En precio fijo no hay pujas: el primero que da "Comprar
    ahora" se lo lleva.
  - En una subasta por tiempo, el vendedor puede poner un precio "Comprar
    ahora" mayor al inicial (y a la reserva). Desaparece con la primera puja.
  - La compra la decide el servidor (`buyNow`) en una transacción: dos
    compradores a la vez → solo uno gana. Exige lo mismo que pujar
    (depósito, perfil, términos e INE arriba de $20,000).
  - Después sigue la ruta de una subasta ganada: se aplica el depósito,
    24 h para pagar, escrow y entrega. El cliente nunca escribe el precio.
- **Ganador moroso:**
  - Pierde su depósito, que se le da al vendedor como compensación.
  - Recibe un strike; con 2 strikes la cuenta se suspende.
  - El lote se ofrece **una sola vez** al subcampeón, por su máximo, con 24 h
    para aceptar.

---

## 3. Modelo de negocio híbrido

**Comisión por venta.** Se decide con la **fecha de cierre** del lote, en
este orden:

| # | Caso | Comisión | Configuración |
|---|---|---|---|
| 1 | **Tienda Oficial** con membresía vigente | 0 % | Panel → Usuarios → "Hacer Tienda Oficial". La membresía hoy se cobra fuera de la app (R-42). |
| 2 | **Campaña** por fechas (p. ej. Buen Fin) | 0 % | `COMMISSION_PROMO=2026-11-13T00:00:00-06:00/2026-11-17T23:59:59-06:00` |
| 3 | **Lanzamiento**: todos los vendedores, hasta N ventas al mes | 0 % (de la venta N+1 del mes en adelante, normal) | `LAUNCH_FREE_UNTIL=2027-03-31T23:59:59-06:00`, `LAUNCH_FREE_MAX_MONTHLY_SALES=30`. El conteo es por mes de cierre (hora del centro de México); lo lleva el servidor en `users.monthly_sales` y el cliente no lo puede tocar. |
| 4 | **Normal**, por tramos marginales (como el ISR) | 10 % / 8 % / 6 % | `COMMISSION_TIERS=10000:0.10,100000:0.08,inf:0.06`, `COMMISSION_MIN=50` |

**Costo del procesador con 0 % de comisión.** El vendedor paga solo el costo
**real** del procesador:

- Mercado Pago: `transaction_amount − net_received_amount`.
- Openpay: `fee`.

Con `ZERO_COMMISSION_FEE_PAYER=platform`, ese costo lo absorbe la plataforma.
Si el procesador no reporta el costo, no se descuenta nada y la liquidación
queda marcada `processing_fee_unknown`.

**Al comprador nunca se le cobra recargo.** Profeco exige precio total final,
sin comisión extra por pagar con tarjeta.

**Depósito de garantía:** $200 MXN (`DEPOSIT_AMOUNT`). Es una
**penalización** si el ganador no paga. Si gana y paga, se descuenta del
cobro. Se puede pedir el reembolso cuando ya no hay compromisos pendientes.

**Precios:** todo en MXN. El precio inicial lo pone cada vendedor.

---

## 4. Entrega regional y municipios

- **Municipios** (`lots.municipality`): camargo, jimenez, saucillo, delicias,
  parral, meoqui, la_cruz, san_francisco_de_conchos, chihuahua, cuauhtemoc,
  otro.
- En el inicio hay un filtro "Toda la región" o por municipio. El equipo
  recuerda la última elección.
- **Modalidades** (`lots.delivery`):
  - `pickup`: entrega a acordar, sin costo.
  - `regional`: costo fijo o incluido, con municipios de destino.
- Si el lote tiene una sola modalidad, se aplica sola. Si tiene dos, el
  ganador elige con `chooseDelivery` antes de pagar.
- El costo de envío se suma al cobro y llega **completo** al vendedor, sin
  comisión.
- Las guías multi-paquetería están pendientes (R-43).

---

## 5. Escrow: pago retenido hasta la entrega

Cuando se confirma el pago, la liquidación al vendedor queda **`held`**
(retenida). Pasa a **`ready`** (liberada) de una de tres formas:

1. **En persona:** el comprador dicta su código de 6 dígitos y el vendedor lo
   escribe (`confirmDeliveryCode`, máximo 5 intentos). Se libera **al
   instante**.
2. **Por envío:** el comprador toca "Sí, lo recibí" (`confirmReceipt`).
3. **Por plazo:** si no hay reclamo, se libera sola a los
   `PAYOUT_RELEASE_DAYS` días, 7 por defecto (`releaseDuePayoutsJob`).

**Reclamos** (`openDispute`): se pueden abrir hasta 72 h después del pago y
mientras el pago siga retenido. Al abrirse, la liquidación se congela
(`on_hold`) y el admin elige una de tres resoluciones:

- **Reembolso total:** se cancela la liquidación y el vendedor recibe un
  strike.
- **Reembolso parcial:** la liquidación se reduce.
- **Rechazo:** la liquidación se libera.

Si al vendedor ya se le había transferido, se registra un **clawback**.

**Pago al vendedor:** hoy es manual. El admin transfiere y registra la clave
de rastreo SPEI en el panel. La automatización está en el roadmap (R-41).

### Flujo del dinero

```
 COMPRADOR                         PLATAFORMA (cuenta MP / Openpay)                  VENDEDOR
 ─────────                         ────────────────────────────────                  ────────
 1. Depósito $200 ───────────────► deposit: held  (habilita pujar)
    (MP checkout)                    │
                                     │
 2. Gana la subasta                  │ cierre (closeEndedAuctions) → deposit: reserved
    cobro = final − $200 + envío     │ payment_status: pending (24 h)
       │                             │
       ├─ no paga ──────────────────►│ expireUnpaidWins: deposit → forfeited ───────► compensación
       │                             │ strike + segunda oportunidad al subcampeón
       │
 3. Paga (MP o SPEI) ─────────────►  webhook verificado + candado payments/…
                                     │ deposit: applied · payment_status: paid
                                     │ comisión: tienda 0 % | campaña 0 % | tramos
                                     │ 0 % → se descuenta costo real del procesador
                                     ▼
 4. RETENCIÓN                      payout: HELD ── reclamo ──► ON_HOLD ──► admin resuelve
                                     │                          (total → cancelled
                                     │                           parcial → monto menor
                                     │                           rechazo → sigue)
 5. LIBERACIÓN                       │ código en persona  (instante)
    "Sí, lo recibí" ────────────────►│ confirmación       (instante)
                                     │ o PAYOUT_RELEASE_DAYS sin reclamo
                                     ▼
 6. PAYOUT                         payout: READY ── admin transfiere SPEI ──► SENT ─────► $ neto
                                                    (registra clave de rastreo)         + envío
```

---

## 6. Confianza

- **Identidad:** el usuario sube INE (frente y reverso) y una selfie, y un
  admin la revisa. Las fotos son privadas.
- **Calificaciones:** solo el comprador que pagó puede calificar, de 1 a 5
  estrellas con comentario. Puede editarla durante 7 días. Los teléfonos y
  correos del comentario se ocultan.
- **Perfil público** (`/vendedor?uid=…`): muestra ★, ventas e insignias
  (verificado, destacado, nuevo, en disputa, Tienda Oficial). No muestra
  datos de contacto.
- **Contacto:** comprador y vendedor reciben el contacto del otro solo cuando
  el pago está confirmado.

---

## 7. Administración

Para darte permisos de administrador, sigue DEPLOY.md §f
(`scripts/set_admin.js`).

El panel está en Mi cuenta → Administración. Cada acción queda registrada en
`admin_log`.

| Pestaña | Para qué |
|---|---|
| Reclamos | Resolver disputas: total, parcial o rechazo. |
| Identidad | Ver INE y selfie; aprobar o rechazar con motivo. |
| Pagos | Liquidaciones retenidas y listas (marcar enviado con referencia); recalcular; reintentar cobros; reembolsos fallidos o manuales. |
| Usuarios | Buscar por correo; suspender o reactivar; hacer o cancelar Tienda Oficial. |
| Lotes | Cancelar subastas activas (fraude, artículo prohibido). |

---

## 8. Asistente de IA

En "Publicar", el botón **Llenar con IA** pone a Claude a leer hasta 4 fotos
y el estado del artículo. Con eso propone:

- título, categoría y descripción;
- detalles visibles del artículo;
- datos que los compradores van a preguntar;
- un aviso si el artículo podría estar prohibido.

**Nunca publica sola.** Tiene prohibido inventar marca o modelo, y borra
teléfonos y correos.

- **Requisitos:** los mismos que para vender.
- **Límites:** `AI_DAILY_LIMIT` por usuario y `AI_GLOBAL_DAILY_LIMIT` para
  toda la plataforma. Si la IA falla, no se descuenta el uso.
- **Sin `ANTHROPIC_API_KEY` válida:** solo se apaga el asistente; el resto de
  la app sigue funcionando.

---

## 9. Desarrollo local y pruebas

```bash
flutter pub get
flutter run -d chrome                         # web
cd firebase/functions && npm ci && npm test   # backend (MP, Openpay, IA y Firestore simulados)
cd firebase/rules-tests && npm ci && npm test # reglas en el emulador oficial (Java 11+ y firebase-tools)
flutter analyze && flutter test               # app
```

**CI** (`.github/workflows/pruebas.yml`) corre 3 jobs en cada push:

1. backend;
2. reglas en el emulador;
3. Flutter: analyze, test y build web.

**Staging:** `publicar_web.yml` publica en GitHub Pages con lotes de
demostración (`DEMO_LOTS=true`). No toca Firebase.

**Valores de compilación** (`--dart-define`): `APP_CHECK_SITE_KEY`,
`FCM_VAPID_KEY`, `SHARE_BASE_URL`, `WEB_APP_URL`, y `DEMO_LOTS` (solo
staging). El detalle está en DEPLOY.md §c.

**Push:**

- **Android:** funciona sin configuración extra.
- **iOS:**
  1. Sube la llave APNs (.p8) en Cloud Messaging.
  2. Activa *Push Notifications* en Xcode.
  3. Antes de publicar en la App Store, cambia `aps-environment` a
     `production` en `ios/Runner/Runner.entitlements`.
- **Web:** compila con `FCM_VAPID_KEY`.

---

## 10. Documentos

| Archivo | Contenido |
|---|---|
| [`DEPLOY.md`](DEPLOY.md) | Despliegue desde cero: Blaze, orden de deploy, variables, webhooks, App Check, admin, dominio, verificación. |
| [`firebase/functions/.env.example`](firebase/functions/.env.example) | Plantilla de todas las variables del servidor. |
| [`CHECKLIST_E2E.md`](CHECKLIST_E2E.md) | Prueba manual punta a punta en sandbox. |
| [`EVIDENCIA_PRUEBAS.md`](EVIDENCIA_PRUEBAS.md) | Qué se ejecutó, qué no, y por qué. |
| [`ROADMAP.md`](ROADMAP.md) | Pendientes con ID y prioridad (fuente de verdad después de v1.0.0). |
| [`CHANGELOG.md`](CHANGELOG.md) | Historial de versiones. |
| [`GUIA_PAGOS_MERCADO_PAGO.md`](GUIA_PAGOS_MERCADO_PAGO.md) | Cuenta de MP, usuarios de prueba, webhook. |
| [`docs/AUDITORIA_v1.0.0.md`](docs/AUDITORIA_v1.0.0.md) | Auditoría de secretos, reglas e índices. |
| [`docs/archivo/`](docs/archivo/) | Plan maestro original (archivado). |

**Pendiente legal (R-03), antes de operar con dinero real.** Revisar con un
abogado en México:

- términos y condiciones;
- aviso de privacidad (INE y CLABE);
- el depósito como penalización;
- la retención de fondos de terceros;
- las obligaciones ante Profeco.
