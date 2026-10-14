# BidStream + Mercado Pago — Guía de integración

> **Nota (actualizada):** este paquete ya está integrado al proyecto y se
> corrigieron varios errores del original (las funciones no se exportaban,
> los reembolsos usaban un método inexistente, el depósito se descontaba en
> varios lotes, el castigo fallaba, pagos tardíos se cobraban doble).
> Los pasos 4 y 5 ya están hechos: la app tiene "Pagar ahora", la pantalla de
> depósito está en "Mi cuenta" y los pagos a vendedores se registran desde el
> **panel de administración** (no desde la consola). Ver README.md.


Sistema de **escrow completo**: depósito de garantía para pujar, pago del
ganador al cerrar la subasta, castigo por no pagar y reembolsos. Todo el
dinero pasa por la cuenta de Mercado Pago de la plataforma.

## Contenido del paquete

```
firebase/functions/payments.js        NUEVO  — depósito, webhook, caducidad, reembolsos
firebase/functions/index.js           REEMPLAZO — placeBid exige depósito, closeLot cobra al ganador
firebase/functions/test/payments_webhook.test.js  NUEVO — pruebas del webhook
firebase/firestore.rules              REEMPLAZO — protege deposit, strikes y colección payments
firebase/firestore.indexes.json       REEMPLAZO — índice para caducar pagos pendientes
lib/backend/payment_service.dart      NUEVO — capa de pagos en la app
lib/pages/deposit_guarantia/          NUEVO — pantalla de depósito (web y móvil)
```

Cómo funciona el flujo completo:

1. El postor paga el **depósito** (configurable, default $200 MXN) desde la
   pantalla de depósito → checkout de Mercado Pago.
2. El webhook confirma el pago y activa `users/{uid}.deposit.status = held`.
3. `placeBid` rechaza pujas sin depósito activo.
4. Al cerrar la subasta con ganador, `closeLot` genera una preferencia de
   cobro por **(precio final − depósito)** y el ganador tiene **24 horas**
   para pagar (enlace en su aviso y en `lot.winner_payment_url`).
5. Cuando Mercado Pago confirma: el lote queda `paid`, se crea el **payout**
   al vendedor por (precio final − comisión del 10%) y ambos reciben aviso.
6. Si no paga a tiempo, `expireUnpaidWins` (cada hora) le quita el depósito
   (se transfiere al vendedor como compensación) y suma un strike. **2 strikes
   = cuenta baneada.**
7. El postor puede pedir el **reembolso** de su depósito cuando no está
   ganando ninguna subasta activa ni debe pagos.

---

## Paso 1 — Cuenta y credenciales de Mercado Pago

1. Crea la cuenta de **producción** de la plataforma en
   [mercadopago.com.mx](https://www.mercadopago.com.mx) (usa un correo del
   negocio, no personal).
2. Ve a **Tus integraciones → Credenciales** y guarda:
   - `Access token` de **producción** (para operar) y de **pruebas** (para
     desarrollar sin dinero real).
3. Para probar sin tarjetas reales, crea **usuarios de prueba** desde
   [mercadopago.com.mx/developers/panel/test-users](https://www.mercadopago.com.mx/developers/panel/test-users):
   un "comprador" con tarjeta de prueba y un "vendedor". Inicia sesión en
   mp-sandbox.mercadopago.com.mx con esas cuentas para pagar en el checkout
   de pruebas.

## Paso 2 — Configurar el backend

En `firebase/functions/`:

1. Instala el SDK:
   ```bash
   cd functions && npm install mercadopago
   ```
2. Copia `payments.js` y el `index.js` de este paquete, y agrega la prueba en
   `test/`.
3. Crea el archivo `functions/.env` (firebase-tools lo carga automáticamente;
   **no lo subas a git**):
   ```
   MP_ACCESS_TOKEN=TEST-xxxxxxxx        # token de pruebas primero
   MP_WEBHOOK_SECRET=una-clave-larga-aleatoria
   WEBHOOK_URL=https://us-central1-bidstream-656cf.cloudfunctions.net/mpWebhook
   SITE_URL=https://bidstream.web.app   # tu URL de Hosting
   DEPOSIT_AMOUNT=200
   COMMISSION_PCT=0.10
   WINNER_PAYMENT_WINDOW_HOURS=24
   ```
4. Genera el secreto del webhook:
   ```bash
   openssl rand -hex 32
   ```
5. Copia `firestore.rules` y `firestore.indexes.json` de este paquete.
6. Despliega:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,functions
   ```
   Los índices tardan unos minutos; mientras tanto `expireUnpaidWins` marcará
   error de índice en logs y sanará solo.

## Paso 3 — Configurar el webhook en Mercado Pago

1. En el panel de MP: **Tus integraciones → Webhooks → Configurar** con la
   URL `…/mpWebhook` y el **secreto** del paso 2 (MP firma cada notificación
   con ese secreto y el servidor la valida; sin él las notificaciones se
   rechazan con 401).
2. Activa el evento **Pagos**.
3. Tras desplegar en producción, cambia `MP_ACCESS_TOKEN` al token de
   producción y vuelve a desplegar functions:
   ```bash
   firebase deploy --only functions
   ```

## Paso 4 — Integrar la app Flutter

1. En `pubspec.yaml` agrega (luego `flutter pub get`):
   ```yaml
   url_launcher: ^6.3.1
   ```
2. Copia `lib/backend/payment_service.dart` y
   `lib/pages/deposit_guarantia/` a tu proyecto.
3. **Exigir depósito antes de pujar.** En `lot_detail_view_widget.dart` (o
   donde se active el botón "Pujar"), verifica el depósito y si no hay,
   manda a la pantalla de depósito:
   ```dart
   final deposit = currentUserDocument?.snapshotData?['deposit'];
   final canBid = deposit?['status'] == 'held';
   if (!canBid) {
     Navigator.of(context).push(MaterialPageRoute(
       builder: (_) => const DepositGarantiaWidget(),
     ));
     return;
   }
   ```
   Aun así, el mensaje de error de `placeBid` ya lo dice, así que como mínimo
   detecta el error y ofrece el botón:
   ```dart
   if (!result.ok && result.message?.contains('depósito') == true) {
     // mostrar botón "Dejar depósito" que abre DepositGarantiaWidget
   }
   ```
4. **Entrada al depósito desde el perfil.** En `user_profile_activity_widget.dart`
   agrega un botón "Depósito de garantía" que abra `DepositGarantiaWidget`.
5. **Pago del ganador.** Al ganar, el aviso (`type: 'won'`) trae `action_url`;
   al tocarlo ábrelo con `PaymentService.instance.openCheckout(url)`. También
   en `lot_detail_view_widget.dart`, si `lot.winnerUid == currentUserUid` y
   `payment_status == 'pending'`, muestra un botón "Pagar ahora" usando
   `lot.winnerPaymentUrl`.

## Paso 5 — Pagar a los vendedores (payouts)

Cuando el pago del ganador se aprueba, se crea un documento en
`payments` con `kind: 'payout'` y `status: 'ready'` por (precio final −
comisión). Para la primera versión, transfiere manualmente desde el panel de
Mercado Pago (Retirar dinero → a la CLABE del vendedor) y marca el documento
`status: 'sent'` desde la consola de Firebase. Luego puedes automatizarlo con
la **Transfers API** de MP (requiere scope adicional) manteniendo la misma
estructura `payments`.

## Paso 6 — Prueba end-to-end (con usuarios de prueba de MP)

1. Cuenta A: completar perfil → dejar depósito en `DepositGarantiaWidget` →
   pagar en el sandbox de MP → verificar que `deposit.status` queda `held`.
2. Cuenta B: intentar pujar **sin** depósito → debe rechazar con "Debes dejar
   un depósito". Luego dejar depósito y pujar normal.
3. Cuenta A publica un lote de 3 minutos; Cuenta B puja y gana.
4. Al cerrar: B recibe aviso "¡Ganaste!" con enlace; paga (precio − depósito)
   en el sandbox.
5. Verificar: lote `payment_status: paid`, aviso "¡Cobrada!" al vendedor,
   documento `payout` en `payments`.
6. Caso triste: otra subasta donde el ganador **no paga** → forzar
   `payment_due_time` a una fecha pasada en la consola → esperar la corrida
   de `expireUnpaidWins` → verificar depósito `forfeited`, strike al usuario
   y payout de compensación al vendedor.
7. Reembolso: cuenta sin subastas activas → "Pedir reembolso" → verificar en
   el panel de MP que el reembolso quedó registrado.

## Checklist para salir a producción

- [ ] `MP_ACCESS_TOKEN` de **producción** y redeploy de functions
- [ ] Webhook configurado en MP con el secreto correcto (producción)
- [ ] Alerta de presupuesto en Google Cloud (plan Blaze)
- [ ] Monto del depósito (`DEPOSIT_AMOUNT`) y comisión (`COMMISSION_PCT`) decididos
- [ ] Términos y condiciones actualizados: reglas del depósito, comisión y castigo por no pagar
- [ ] Aviso de privacidad que mencione el procesamiento de pagos por Mercado Pago
- [ ] Revisión legal en México (PROFECO) para operar pagos y retención de garantías
- [ ] Prueba con montos pequeños reales (tarjeta propia) antes de usuarios reales

## Notas y límites conocidos

- **Retención de garantías**: retener dinero de terceros puede tener
  implicaciones regulatorias (entidad financiera / fondeo). Para escalar,
  evalúa operar bajo la figura de marketplace de MP (split con
  `marketplace_fee`) con los pagos de comisión, en vez de retener todo.
- El checkout abre en navegador/app de MP (Checkout Pro) en web y móvil; no
  requiere SDK nativo. Si más adelante quieres el formulario dentro de la
  app, migra a **Bricks** (tarjeta) manteniendo el mismo webhook.
- `binary_mode: true` deja pagos solo en approved/rejected (sin "pendiente"),
  simplificando el webhook; OXXO/SPEI no son compatibles con binary_mode, así
  que el depósito es con tarjeta o saldo MP. Si necesitas OXXO, quita
  `binary_mode` y maneja el estado `pending` en el webhook.
