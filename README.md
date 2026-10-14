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
- Primera puja: mínimo el precio inicial. Siguientes: puja actual + incremento.
- El vendedor no puede pujar en su propio lote; no puedes pujar si ya vas ganando.
- **Anti-francotirador:** una puja en los últimos 2 minutos extiende la subasta 2 minutos.
- Tope contra errores de dedo: no se acepta una puja 20 veces mayor al mínimo.
- Cada minuto se cierran las subastas vencidas. El ganador y el vendedor
  reciben en sus avisos el contacto del otro.
- En el historial público solo se ve "Nombre + inicial" (ej. "Juan P.").

---

## 2. Estructura de datos (Firestore)

```
users/{uid}                     perfil privado (solo lo lee su dueño)
  ├─ notifications/{id}         avisos (los crea el servidor)
  └─ bidding/{lotId}            subastas donde pujó (las mantiene el servidor)
lots/{lotId}                    lote
  └─ bids/{bidId}               pujas (solo las crea el servidor)
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

Para marcar a alguien como verificado, suspenderlo o darle rol, edita su
documento en `users/{uid}` desde la consola de Firebase (campos `verified`,
`banned`, `role`). Los usuarios no pueden cambiarse esos campos.

---

## 6. Pendientes (siguientes versiones)

- **Pagos y comisión** (Stripe / Mercado Pago / Conekta). Hoy el pago y la
  entrega se acuerdan entre comprador y vendedor.
- **Verificación de identidad real** (INE + selfie). Hoy solo se verifica
  correo y se pide teléfono.
- **Notificaciones push** (Firebase Cloud Messaging). Hoy los avisos se ven
  dentro de la app.
- **Video propio** (Mux / Agora) en vez de YouTube, si se necesita menos
  retraso o privacidad.
- Precio de reserva, "compra ya", reportar lotes, panel de administrador.
- Revisar requisitos legales de subastas/comercio electrónico en México
  (PROFECO, aviso de privacidad, términos completos).
