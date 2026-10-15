> **ARCHIVADO** el 2026-10-15 al cerrar v1.0.0. Ya no es la fuente de verdad: los pendientes viven en [ROADMAP.md](../../ROADMAP.md). Fases 0, 1 y 2.3 están implementadas (ver CHANGELOG.md y EVIDENCIA_PRUEBAS.md).

# Plan de mejoras BidStream / Subástalo Aquí — Prompt de trabajo

Actúa como ingeniero senior full-stack en el proyecto BidStream (repo: kitos1581-glitch/bidstream). Ya conoces la base: Flutter (Android/iOS/web) + Firebase (Auth, Firestore, Storage, Cloud Functions, FCM), puja proxy con anti-sniping de 30 s, escrow con Mercado Pago (depósito $200), verificación de identidad con INE, comisiones por tramos (COMMISSION_TIERS), 90 pruebas backend pasando y CI con tres jobs (funciones, reglas en emulador, Flutter). Objetivo de negocio: ser el marketplace verificado y con escrow para ganado, caballos y maquinaria en México, tomando de eBay su sistema de confianza y su monetización.

## Reglas de trabajo (aplican a todo el plan)

1. NO regresar a FlutterFlow; todo cambio es código en este repo.
2. Cada módulo se entrega con: cambios en código, pruebas nuevas (node --test para funciones, firebase/rules-tests para reglas, flutter test para Dart), reglas de Firestore/Storage actualizadas, y una fila nueva en EVIDENCIA_PRUEBAS.md con el estado real de la ejecución (EJECUTADO / NO EJECUTADO y por qué).
3. Mantener el principio de seguridad actual: el cliente NUNCA escribe precios, pujas, pagos, reputación ni estado de disputas; todo pasa por Cloud Functions con transacciones. Reglas deny-by-default.
4. Todo dinero con idempotencia (documento candado) y toda notificación nueva dispara push vía el trigger onNotificationCreated existente.
5. Español es-MX en mensajes de usuario; errores claros y accionables.
6. Trabajar por fases en este orden. Al terminar cada fase: CI verde en los tres jobs antes de pasar a la siguiente.

---

## FASE 0 — Fundamentos (1–2 días)

- [ ] **0.1 App Check**: activar App Check (reCAPTCHA web / Play Integrity / DeviceCheck) en Authentication, Firestore, Storage y Functions (con tolerancia temporal durante el despliegue). Bloquear llamadas onCall sin token válido.
- [ ] **0.2 Verificación remota**: correr `firebase/scripts/verificar_remoto.sh` con credenciales contra producción y pegar la salida en EVIDENCIA_PRUEBAS.md. Confirmar que reglas, índices y las 16 funciones desplegadas coinciden con el repo (post-v5).
- [ ] **0.3 Fotos de lotes para invitados**: el catálogo es público sin cuenta, pero verificar que las fotos de Storage se ven sin sesión. Si usan URLs con token, documentarlo; si no, abrir `allow read` en `/lots/{uid}/` y añadir caso al rules-test.
- [ ] **0.4 SEO de lanzamiento**: dejar el `noindex` mientras siga en vista previa, pero preparar el cambio: meta description por categoría, Open Graph por lote (og:title/og:image con la primera foto del lote) para que al compartir un lote por WhatsApp/Facebook se vea la tarjeta. Web-only, sin afectar móvil.

## FASE 1 — Confianza (la brecha más grande vs. eBay)

- [ ] **1.1 Sistema de reputación** (P0):

- Colección `feedback/{lotId}` con: rating 1–5, comentario (máx. 500 chars), author_uid, seller_uid, created_time. Solo lo crea el COMPRADOR que pagó (server-side, verificando `lots/{lotId}.winner_uid == uid` y `payment_status == 'paid'`). Un feedback por venta; editable 7 días; una disputa abierta lo bloquea.
- Agregados en `users/{uid}` (los mantiene el servidor, no el cliente): `rating_avg`, `rating_count`, `sales_count`. Recalcular con transacción al crear feedback.
- Insignias derivadas: "Verificado" (ya existe), "Vendedor destacado" (≥10 ventas y promedio ≥4.5), "Nuevo" (<3 ventas). Mostrar en tarjeta de lote y perfil público.
- Perfil público del vendedor: nombre público, rating, conteo de ventas, insignias, lotes activos. Lectura pública de SOLO esos campos (no teléfono ni email: el contacto sigue liberándose solo tras el pago).
- Funciones: `submitFeedback`, `updateFeedback` (ventana de edición), y reglas Firestore correspondientes.

- [ ] **1.2 Protección al comprador y disputas** (P0):

- `openDispute(lotId, reason, fotos)`: disponible del comprador desde el pago confirmado hasta 72 h después; crea `disputes/{disputeId}` con estado `open`.
- `adminResolveDispute(disputeId, resolution)`: `refund_full` (reembolso vía Mercado Pago del pago del ganador + devolución de comisión, con idempotencia), `refund_partial` (monto), `reject`. Toda resolución genera payout inverso registrado en `payments` y bitácora admin_log.
- Un lote con disputa abierta bloquea feedback del vendedor y marca su perfil "en disputa" hasta resolver.
- Avisos push en cada transición (disputa abierta → vendedor; resolución → ambas partes).

- [ ] **1.3 Second Chance Offer** (P0): al ejecutarse `forfeitWin` (ganador no pagó), en lugar de solo compensar al vendedor con el depósito, buscar al subcampeón (segundo máximo en el historial de pujas), notificarle "Segunda oportunidad: gánalo por tu máximo de $X" con ventana de pago de 24 h (misma maquinaria de `startWinnerPayment`). Si no paga, recién ahí cierra como hoy. El vendedor conserva el depósito del ganador moroso como compensación.

## FASE 2 — Conversión y monetización (estilo eBay)

- [ ] **2.1 Comprar Ahora** (P1): campo opcional `buy_now_price` en el lote (≥ precio inicial). Botón en detalle: compra inmediata server-side (`buyNowNow`) que cierra el lote con `status='ended'`, `winner_uid=comprador`, salta la subasta, reserva el depósito igual que al ganar, y genera el cobro (reutilizar `startWinnerPayment`). El vendedor puede retirarlo cuando quiera mientras no haya pujas.
- [ ] **2.2 Mejor Oferta** (P1): en lotes con precio fijo o Buy Now, el comprador envía oferta; el vendedor acepta/rechaza/contraoferta (una ronda). Aceptar = misma ruta de compra que 2.1. Reglas server-side con expiración de 48 h por oferta.
- [ ] **2.3 Precio reservado** (P1): campo opcional `reserve_price` (secreto, jamás en el cliente ni en el historial público; guardarlo igual que el estado privado del proxy, en `lots/{id}/private`). Al cerrar el lote: si `final_price < reserve_price` → `status='ended_unsold_reserve'` y ningún cobro; aviso al vendedor y al líder ("reserva no alcanzada"). En el detalle mostrar solo "Tiene precio de reserva: sí/no".
- [ ] **2.4 Watchlist y alertas** (P1): colección `users/{uid}/watchlist/{lotId}` (escritura del dueño, campos mínimos). Push automático: "La subasta que sigues termina en 30 min" (una sola vez por lote), "Te superaron en un lote de tu lista". Botón corazón en tarjeta y detalle.
- [ ] **2.5 Destacados de pago** (P1): el vendedor paga una tarifa fija (configurable, p. ej. $49) para tener su lote 7 días en el carrusel superior de su categoría. Cobro con la misma preferencia de Mercado Pago (idempotencia por lote); campo `promoted_until` que solo el servidor escribe tras webhook aprobado. La home consulta destacados primero.
- [ ] **2.6 Búsquedas guardadas** (P2): guardar consulta (texto + categoría + rango de precio); un Cloud Function diario (pubsub) notifica coincidencias nuevas con push (una notificación agregada por usuario al día, no una por lote).

## FASE 3 — Transmisión en vivo propia (sin depender de YouTube)

Contexto: hoy la subasta en vivo incrusta YouTube, con su latencia de 10–30 s — inaceptable para pujas rápidas con martillo. El objetivo es transmitir DESDE la app con latencia real y retransmitir simultáneamente a Facebook y YouTube.

- [ ] **3.1 Proveedor**: LiveKit Cloud (SDK Flutter oficial, WebRTC con latencia sub-segundo; tier Build gratis 5,000 min WebRTC/mes, Ship $50/mes con 150,000 min; referencia: Whatnot, marketplace de subastas en vivo, corre sobre LiveKit). Alternativa si se prefiere HLS simple: Cloudflare Stream o Mux (ingesta RTMP/SRT, restream a hasta 50 destinos incl. Facebook y YouTube por RTMPS).
- [ ] **3.2 Transmitir desde la app**: pantalla "Ir en vivo" para el vendedor verificado: publica con la cámara del celular (LiveKit Flutter SDK), título, lote asociado. El stream queda DENTRO de la app (player LiveKit en `live_stream_auction`), no en YouTube.
- [ ] **3.3 Retransmisión a Facebook y YouTube** (opcional por subasta, configuración del vendedor): guardar por vendedor su RTMPS URL + stream key de Facebook (se obtienen con Facebook Login / Live API) y su stream key de YouTube. LiveKit Egress envía la sala a esos destinos; el celular solo sube UNA copia (la retransmisión la hace la nube). Botón "también transmitir a mis redes".
- [ ] **3.4 Pujas en vivo sincronizadas**: con latencia sub-segundo, habilitar modo "martillo" del subastador: cuenta regresiva visual de 10 s controlada por el vendedor (función `callHammer` que aplica anti-sniping normal), historial visible por todos, contador de espectadores.
- [ ] **3.5 Grabación**: toda transmisión se graba (egress a storage) y queda visible en el detalle del lote como evidencia del estado del artículo y de la venta (ayuda a disputas de la Fase 1).
- [ ] **3.6 Fallback**: mantener la integración actual con YouTube como opción; una subasta `format='live'` puede usar `stream_provider: 'youtube' | 'native'`.

## FASE 4 — Crecimiento

- [ ] **4.1 SEO y compartición** (con 0.4): quitar `noindex` al lanzar, landing pública por categoría (server-rendered simple o pre-render en CI), sitemap estático de lotes activos, deep links universales (Android App Links / iOS Universal Links) para que el link de un lote abra la app.
- [ ] **4.2 Comisión diferenciada por categoría**: ampliar COMMISSION_TIERS a COMMISSION_TIERS_BY_CATEGORY (JSON por categoría con fallback global); sugerido: ganado/caballos/maquinaria al 8/6/4% para atraer oferta, electrónica al 10/8/6%. Validación estricta igual que hoy (config inválida → needs_review, nunca valor por defecto silencioso).
- [ ] **4.3 Resumen diario**: pubsub 9am hora CDMX: push/email digest con "tus subastas activas, estás ganando/perdiendo, nuevos lotes de tus búsquedas guardadas".
- [ ] **4.4 Analytics**: eventos Firebase Analytics (puja, publicación, depósito, compra, disputa) y funnel en consola.

---

## Criterio de aceptación global

- CI verde en los 3 jobs por fase; pruebas nuevas que cubran los casos felices Y los de abuso (feedback de quien no compró, doble compra-ahora simultánea, subcampeón inválido, reserva revelada en cliente, retransmisión con stream key vencida).
- EVIDENCIA_PRUEBAS.md actualizado con lo ejecutado y lo pendiente, igual que en v5.
- README actualizado con los módulos nuevos y sus reglas de negocio.
- Ningún secreto (stream keys, máximos proxy, reserve_price) legible desde el cliente ni las reglas.