# CHANGELOG — Subástalo Aquí

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Versionado: [SemVer](https://semver.org/lang/es/).

Las fechas corresponden a los commits. La evidencia de cada versión está en
`EVIDENCIA_PRUEBAS.md`.

## [Sin publicar]

### Corregido: "Una foto es demasiado grande" al usar la IA (2026-10-27)
- En el navegador, image_picker no comprime PNG. Ahora cada foto se
  reconvierte a JPEG de máx. 1600 px y ~1.2 MB (`lib/backend/photo_utils.dart`,
  paquete `image`) antes de subirla o mandarla a la IA.

### Agregado: filtro de datos de contacto en publicaciones (2026-10-27)
- `onLotModerate` (función 35): si el título, la descripción o las
  características traen teléfono (en número o en letra), correo, WhatsApp,
  redes o "@usuario", el lote pasa a `status: review` (no se ve ni acepta
  pujas) y se avisa al vendedor. Corregido, vuelve solo a `active`.
  Reglas: el dueño puede editar en `review`, pero no cambiar el estado.
  Fotos (OCR) en una etapa posterior. Pruebas: `test/contact_filter.test.js`.
- Publicar: al faltar un dato, la pantalla baja/sube al campo que falta; el
  formulario ahora valida todos los campos aunque no estén en pantalla.

### Agregado: correo oficial contacto@subastaloaqui.com (2026-10-27)
- Tarjeta "¿Necesitas ayuda?" en Ayuda (abre el correo) y punto en
  Privacidad para consultar, corregir o borrar datos. Buzón en Zoho Mail.
- Modo de prueba de Mercado Pago: no se envía el correo real del comprador
  (MP rechazaba el pago: "una de las partes es de prueba").

### Corregido: "Pagar ahora" no hacía nada en iPhone (2026-10-27)
- Safari bloqueaba la pestaña de Mercado Pago porque se abría después de
  esperar al servidor. En web el cobro se abre en la misma pestaña, y al
  terminar Mercado Pago regresa al artículo (no al inicio).
- Texto del apartado: "si no pagas, vuelve a la venta" (ya no menciona
  depósito en compra directa).

### Corregido: flecha de regreso invisible y versiones viejas en caché (2026-10-27)
- Con Material 2 los íconos de la barra superior salían blancos sobre fondo
  blanco (Ayuda, Vendedor): la flecha existía pero no se veía. Tema global
  `appBarTheme` oscuro y `BackOrHomeButton` en todas las pantallas
  secundarias: regresa, o va al inicio si se entró directo (enlace
  compartido, recarga, app instalada).
- Hosting: `Cache-Control: no-cache` (revalida con ETag) para que tras cada
  despliegue se cargue la versión nueva sin cerrar la app.

### Cambiado: "Comprar ahora" de subasta = compra directa sin depósito (2026-10-27)
- El "Comprar ahora" de una subasta sin pujas usa el mismo "aparta y paga"
  que el precio fijo: sin depósito ni INE, 30 min para pagar, solo pago
  inmediato. Si no paga, la subasta vuelve a estar activa con su fecha de
  cierre y se suma a `unpaid_buys` (con 3, se vuelve a pedir depósito).

### Agregado: pago en efectivo (OXXO/tiendas) y transferencia para el ganador (2026-10-27)
- El cobro del GANADOR de una subasta ya no usa `binary_mode`: acepta
  efectivo y transferencia de Mercado Pago. La ficha vence
  `OFFLINE_PAYMENT_MARGIN_HOURS` (4) antes del plazo; si quedan < 2 h, solo
  pago inmediato. `OFFLINE_PAYMENTS=off` lo apaga.
- "Aparta y paga" y el depósito siguen solo con pago inmediato (efectivo
  excluido explícitamente).
- Un pago pendiente NO cuenta como pagado: se anota en el lote
  (`offline_payment_pending`), se avisa al comprador una vez (candado
  `payments/mp_pending_{id}`) y ya no se puede cambiar la entrega. Un pago
  aprobado después de perder el lote se reembolsa completo (ya existía).
- Pruebas: `test/offline_payments.test.js` (7). Total 202/202.

### Cambiado: anti-sniping de 40 segundos, configurable (2026-10-21)
- `ANTI_SNIPE_SECONDS` (por defecto 40, rango 15–300) reemplaza los 2 min
  fijos: más ágil y con margen para el retraso del video en vivo.

### Cambiado: precio fijo "aparta y paga" (2026-10-21)
- Comprar a precio fijo ya no pide depósito ni INE: el artículo se aparta
  30 min (`BUY_HOLD_MINUTES`) mientras se paga con tarjeta o Mercado Pago.
  Si no paga, vuelve a la venta (o termina sin venta si ya venció), sin
  strike. Con 3 apartados vencidos (`users.unpaid_buys`) se vuelve a pedir
  depósito.
- La subasta con Comprar ahora conserva las reglas de pujar.
- `expireUnpaidWins` corre cada 5 min (antes 15) para liberar apartados a
  tiempo.
- **Corregido (seguridad):** el vendedor podía borrar un lote vendido o
  apartado por Comprar ahora (no tiene pujas). Ahora no se borra si tiene
  comprador o estado de pago.

### Agregado: sello "Vendedor fundador" (2026-10-19)
- Nueva función de admin `adminSetFoundingSeller` (34 funciones): asigna o
  retira el sello. Solo es reconocimiento; no cambia comisiones.
- Aparece como insignia "Vendedor fundador" en el perfil público y en los
  lotes publicados **después** de asignarlo (los lotes guardan las insignias
  al publicarse).
- Panel → Usuarios: botón "Hacer Vendedor fundador" / "Quitar sello".
- Reglas: el cliente no puede darse el sello.

### Cambiado: comisión de lanzamiento y anti-sniping (2026-10-19)
- **Comisión de lanzamiento:** 0 % para todos los vendedores hasta el
  31 de marzo de 2027 (`LAUNCH_FREE_UNTIL`), hasta 30 ventas por vendedor al
  mes (`LAUNCH_FREE_MAX_MONTHLY_SALES`). Desde la venta 31 del mes, comisión
  normal. Tiendas Oficiales: 0 % sin límite (cuota fija). El Buen Fin
  (`COMMISSION_PROMO`) va antes y no tiene tope.
- El servidor cuenta las ventas del mes por vendedor (`users.monthly_sales`,
  mes de cierre en hora del centro de México) dentro de la transacción del
  pago; las reglas impiden que el cliente lo modifique. Aviso al vendedor al
  llegar al tope.
- **Anti-sniping de 2 minutos** (antes 30 s).
- Centro de ayuda: comisión de lanzamiento, precio fijo y Comprar ahora.
- ROADMAP: R-16 preguntas públicas, R-17 detección de pujas falsas, R-18
  sugerencia de precio; R-42 (cuota de Tienda Oficial) sube a P1.

### Agregado: precio fijo y "Comprar ahora" (R-10, 2026-10-18)
- Al publicar, el vendedor elige **Subasta** o **Precio fijo** (1 pieza,
  7–60 días). En subastas por tiempo puede agregar un precio "Comprar ahora".
- Nueva función callable `buyNow` (33 funciones en total): transacción que
  valida el lote y la elegibilidad del comprador, cierra el lote con
  `sold_via: "buy_now"` y reutiliza el cobro del ganador (depósito aplicado,
  24 h, escrow, entrega).
- `placeBid` rechaza pujas en precio fijo (`FIXED_PRICE`); la reserva no se
  permite en precio fijo y debe quedar debajo del "Comprar ahora".
- Reglas: `sale_type` inmutable, `buy_now_price` validado y en la lista blanca.
- UI: selector al publicar, botón "Comprar ahora" con confirmación y pago,
  textos de cierre y etiquetas en las tarjetas.
- Pruebas: backend 182 (10 nuevas), un caso nuevo de reglas.

## [1.0.0] — 2026-10-15

Primera versión "lista para desplegar". **Todavía no está desplegada**: ver
DEPLOY.md y ROADMAP R-01.

### Cierre de versión (2026-10-15)
- **ROADMAP.md**: los pendientes de las fases 2.1, 2.2, 2.4–2.6, 3 y 4, más
  los operativos, cada uno con ID `R-xx` y prioridad. El plan maestro quedó
  archivado en `docs/archivo/`.
- **DEPLOY.md**: guía de despliegue desde cero. Incluye:
  - Blaze con alertas de presupuesto;
  - orden de deploy: índices → reglas → storage → funciones → hosting;
  - inventario completo de variables;
  - webhooks de MP y Openpay con pruebas negativas y positivas;
  - App Check de monitor a enforce, con ventana de tolerancia y rollback;
  - admin inicial;
  - decisión de dominio;
  - verificación remota.
- **`firebase/functions/.env.example`**: todas las variables, con valores
  ficticios.
- **`firebase/storage.cors.json`**: sin esta configuración, la web no muestra
  las fotos de Storage.
- **CHECKLIST_E2E.md**: guion manual de punta a punta en sandbox. Para cada
  paso dice qué se espera, dónde verlo y cómo revertirlo.
- **Auditoría** (`docs/AUDITORIA_v1.0.0.md`): no hay secretos ni en el árbol
  ni en el historial, y no falta ningún índice.
- **README** reescrito: arquitectura, módulos, modelo híbrido, envío, escrow
  y diagrama del flujo de dinero.
- `verificar_remoto.sh` ahora espera las 32 funciones y valida campaña, costo
  del procesador, días de retención, App Check y Openpay.

### Seguridad
- Reglas: al **crear un lote** se pasó de lista negra a **lista blanca** de
  campos (los 19 que envía la app) y `created_time` debe ser la hora del
  servidor. Antes se podían preestablecer campos del servidor como
  `processing_fee`, `closed_time` o `paid_time`. No se encontró abuso
  explotable, pero ya quedó cerrado. Se agregó una prueba de reglas.
- `.gitignore` excluye `functions/.env*` (excepto el ejemplo), las llaves de
  cuenta de servicio, los keystores, `key.properties` y los `.p8`. **Antes no
  excluía el `.env`.**
- Las credenciales de ejemplo de la documentación de Openpay que había en las
  pruebas se reemplazaron por ceros.
- Los usuarios no pueden modificar `seller_strikes`, `seller_plan`,
  `store_name` ni `store_plan_until`.

### Corregido
- Guía de pagos: `MP_WEBHOOK_SECRET` **lo genera Mercado Pago**, no se
  inventa con `openssl`. Con la instrucción anterior, todos los webhooks
  habrían respondido 401.
- Historial de pujas con hora estrictamente creciente. Corrige el desorden con
  pujas en el mismo milisegundo y una prueba intermitente.
- Al bajar la reserva por debajo del máximo del líder, el precio ahora sube a
  la reserva.
- `lots_record.dart`: había un bloque insertado en un lugar incorrecto.

### Agregado: confianza y dinero (2026-10-15)
- **Código de entrega en persona**:
  - el comprador recibe un código de 6 dígitos;
  - el vendedor lo escribe al entregar y **cobra al instante**;
  - máximo 5 intentos;
  - solo se guarda el hash.
- **Costo real del procesador con 0 % de comisión**:
  - se descuenta al vendedor lo que de verdad cobró MP (bruto − neto
    recibido) u Openpay (`fee`);
  - con `ZERO_COMMISSION_FEE_PAYER=platform` lo absorbe la plataforma;
  - nunca se cobra recargo al comprador.
- **Modelo híbrido**:
  - Tienda Oficial: 0 % con membresía, distintivo, alta y renovación desde el
    panel;
  - campaña de 0 % por fechas (`COMMISSION_PROMO`, p. ej. Buen Fin);
  - si no aplica ninguna de las dos, comisión por tramos.
- **Entrega**: a acordar y/o envío regional (costo fijo o incluido, con
  municipios destino). El ganador elige antes de pagar.
- **Municipios**: 11 municipios de la región y un filtro en el inicio.
- **Escrow**:
  - el payout queda `held` hasta "Ya lo recibí" o hasta que pase
    `PAYOUT_RELEASE_DAYS` sin reclamo;
  - la liberación automática corre cada hora;
  - si el vendedor pierde un reclamo con reembolso total, recibe un strike.
- **Precio de reserva** (Fase 2.3):
  - es secreto y solo aplica a subastas por tiempo;
  - el precio salta a la reserva cuando se alcanza;
  - si no se alcanza, el cierre es `ended_unsold_reserve`;
  - con pujas, la reserva solo se puede bajar.

### Agregado: Fases 0 y 1 (2026-10-14)
- **Segunda oportunidad** (1.3): si el ganador no paga, se ofrece el lote al
  subcampeón por su máximo, con 24 h para aceptar y sin castigo si rechaza.
- **Disputas** (1.2):
  - reclamo dentro de 72 h, que congela la liquidación;
  - el admin resuelve con reembolso total, parcial o rechazo;
  - reembolsos idempotentes y clawback;
  - pestaña Reclamos en el panel.
- **Reputación** (1.1):
  - calificaciones del comprador que pagó (editables 7 días);
  - perfil público del vendedor con insignias;
  - estrellas en las tarjetas.
- **App Check** en las funciones callable (monitor, enforce u off), fotos de
  lotes públicas y tarjetas Open Graph `/l/{id}` con botón Compartir.
- **Pago por SPEI** (Openpay):
  - el ganador elige el método;
  - referencia única por lote;
  - webhook verificado contra la API;
  - el SPEI tardío o duplicado queda como reembolso manual.
- **Catálogo público** sin cuenta, centro de ayuda y `manifest.json`.
- **Nuevo nombre** Subástalo Aquí con los colores del logo, y
  características obligatorias por categoría al publicar.
- **Rediseño** estilo marketplace: banner, categorías y filas, con lotes de
  demostración en la vista previa.

### Agregado: base (2026-10-14)
- Backend seguro: las pujas se procesan solo en el servidor.
- **Puja proxy** con máximo secreto y **anti-sniping** de 30 s.
- **Mercado Pago**:
  - depósito de garantía de $200 como penalización;
  - cobro al ganador en 24 h con el depósito aplicado;
  - castigo y strikes por no pagar;
  - reembolsos;
  - webhook con firma.
- **Verificación INE** con revisión manual y **panel de administración**:
  identidad, pagos, usuarios y lotes.
- **Push** (FCM) en Android, iOS y web.
- **Asistente de IA** para publicar, con límites diarios por usuario y
  globales.
- **Comisión por tramos** marginales con configuración estricta: si es
  inválida, la liquidación queda en revisión.
- **CI**: 3 jobs (backend, reglas en el emulador oficial y Flutter) y vista
  previa en GitHub Pages.

### Pruebas al cierre
- Backend: **172** pruebas.
- Reglas: **21** casos de Firestore + **3** de Storage en el emulador.
- Flutter: analyze, test y build web en CI.

### Conocido / no incluido (ver ROADMAP)
- Sin despliegue a producción (R-01) ni prueba E2E en sandbox (R-02).
- Revisión legal pendiente (R-03).
- Android firma con llaves debug y usa `com.mycompany.bidstream`
  (R-04 / R-05), lo que bloquea la Play Store.
- No incluye: Comprar Ahora, Mejor Oferta, Watchlist, Destacados, búsquedas
  guardadas, streaming propio (Fase 3) ni crecimiento (Fase 4).
