# ROADMAP — Subástalo Aquí (después de v1.0.0)

Fuente de verdad de lo que **falta** a partir del lanzamiento. El plan maestro
original (Fases 0–4) quedó archivado en
[`docs/archivo/PLAN_MAESTRO_FASES_0-4.md`](docs/archivo/PLAN_MAESTRO_FASES_0-4.md).
Lo ya implementado está en [`CHANGELOG.md`](CHANGELOG.md) y su evidencia en
[`EVIDENCIA_PRUEBAS.md`](EVIDENCIA_PRUEBAS.md).

**Prioridades**
- **P0**: bloquea un lanzamiento o un canal (tienda de apps, dinero real).
- **P1**: siguiente trimestre; mejora conversión o confianza de forma medible.
- **P2**: cuando haya volumen o datos que lo justifiquen.

Cada pendiente tiene un ID (`R-xx`). Ese ID es el "issue" de referencia. Los
TODO que quedan en el código lo citan. Aquí no se abren issues en GitHub: si
se migran, conserva el ID en el título.

Las reglas de trabajo del plan siguen vigentes para todo lo de esta lista:
- código + pruebas + reglas + fila en EVIDENCIA_PRUEBAS.md;
- el cliente nunca escribe dinero ni estados;
- idempotencia con documento candado;
- es-MX;
- CI verde.

---

## A. Bloqueantes operativos (no son features; se resuelven fuera del código o con un cambio mínimo)

| ID | Pendiente | Contexto | Prioridad |
|---|---|---|---|
| R-01 | Despliegue a producción | Nada está desplegado todavía. Producción sigue con las reglas viejas de FlutterFlow, sin Storage y sin Blaze. Se hace con [`DEPLOY.md`](DEPLOY.md). | **P0** |
| R-02 | Prueba E2E con dinero de sandbox | El guion está en [`CHECKLIST_E2E.md`](CHECKLIST_E2E.md). Requiere el despliegue (R-01) y cuentas sandbox de MP y Openpay. | **P0** |
| R-03 | Revisión legal México | Faltan revisar: términos, aviso de privacidad (INE, CLABE), depósito como penalización, retención de pagos (escrow), Profeco y Buen Fin. Además, si retener fondos de terceros exige algún registro (p. ej. ante la CNBV). | **P0** |
| R-04 | Firma de release Android | `android/app/build.gradle` firma el release con llaves *debug*. Con eso Google Play rechaza la app. Hay que generar un keystore, crear `key.properties` (fuera de git) y apuntar `signingConfig` a `release`. La web no se ve afectada. | **P0** (solo para Play Store) |
| R-05 | Identificador de la app | El ID es `com.mycompany.bidstream` en Android e iOS. Cambiarlo obliga a registrar de nuevo las apps en Firebase y bajar otra vez `google-services.json` / `GoogleService-Info.plist`. Hay que decidirlo **antes** de la primera publicación en tiendas, porque después ya no se puede cambiar. | **P0** (solo tiendas) |
| R-06 | Logo final y landing ligera | El logo actual es provisional (azul marino y naranja; falta el archivo limpio). Falta también una landing pública que explique la plataforma. | P1 |
| R-07 | Conectar el dominio | **Avance al 2026-10-15:** `subastaloaqui.com` y `www` ya están verificados en Firebase Hosting, con DNS en Cloudflare (nube gris) y el certificado en proceso. Hoy muestran "Site Not Found" porque todavía no se ha desplegado la web. **Pendiente:** `subastaloaqui.com.mx` (zona en Cloudflare y redirección en Firebase), correo `contacto@` con Email Routing (reemplaza el MX de Neubox) y borrar los CNAME `ftp`/`mail` de Neubox. La renovación automática en Neubox está apagada; la renovación cuesta $259.90 MXN al año. | **P0** antes del Buen Fin |
| R-09 | Facturación de Google Cloud | Se creó el 2026-10-16 una cuenta de facturación (persona física) con la prueba gratis de $300 USD. Queda **pendiente**: Google pide un prepago de $500 MXN o esperar su verificación. Luego hay que ligarla a `bidstream-656cf` (Firebase → Blaze). **La prueba dura 90 días (hasta mediados de enero de 2027): antes de esa fecha hay que activar la cuenta completa de pago, o Google pausa los servicios.** Al cambiar de razón social, la cuenta se pasa a la comercializadora. Google creó además el proyecto vacío "My First Project", que se puede borrar. | **P0** |
| R-08 | Requisitos de tiendas | Son requisitos para publicar, no features: **botón "Eliminar mi cuenta"** dentro de la app (hoy no existe; Apple y Google lo exigen), URL pública de privacidad (`subastaloaqui.com/privacidad`), ícono y capturas, y ficha de la tienda. En Google, cada app nueva de una cuenta personal necesita una **prueba cerrada de 12 testers durante 14 días**. Se publica primero con la cuenta personal y se transfiere a Comercializadora MEAC cuando tenga cuentas de desarrollador propias. | **P0** (tiendas) |

## B. Fase 2 pendiente — Conversión y monetización

| ID | Plan | Pendiente | Contexto | Prioridad |
|---|---|---|---|---|
| R-10 | 2.1 | ~~Comprar Ahora~~ **HECHO (2026-10-18)** | Precio fijo de 1 pieza y "Comprar ahora" en subastas sin pujas. Función `buyNow` con transacción; reutiliza el cobro, escrow y comisión de una subasta ganada. Pruebas: `test/buy_now.test.js` (incluye doble compra simultánea) y reglas. **Pendiente (R-15):** inventario de varias piezas. | ~~P1~~ |
| R-15 | 2.1 | **Inventario (varias piezas)** | Precio fijo con cantidad > 1: cada compra descuenta existencias en la transacción y crea su propia orden (hoy el pago vive en el lote, así que hace falta un documento `orders/{id}` por compra). Es el cambio más grande de esta lista: vale la pena cuando haya vendedores con mercancía repetida. | P2 |
| R-16 | 2.1 | **Preguntas públicas en la ficha** | Estilo Mercado Libre: el comprador pregunta, el vendedor responde y queda visible para todos. Filtro de teléfonos y redes (como en la descripción) para que no se salten el pago. Más sencillo que el chat (R-40) y ahorra preguntas repetidas. | P1 |
| R-17 | — | **Detección básica de pujas falsas** | Alertas al panel (sin bloqueo automático): pujas desde el mismo equipo o IP que el vendedor, cuentas nuevas que solo pujan con un vendedor, puja retirada por impago repetida con el mismo vendedor. En un mercado chico donde todos se conocen va a pasar. | P1 |
| R-18 | — | **Sugerencia de precio con IA** | Extiende el asistente de descripción: precio inicial sugerido con el historial de ventas propio. Sirve cuando haya suficientes ventas cerradas por categoría; antes, no hay de dónde sacarlo. | P2 |
| R-11 | 2.2 | **Mejor Oferta** | Una sola ronda: oferta → aceptar / rechazar / contraofertar. Cada oferta expira a las 48 h. Aceptar sigue la misma ruta que R-10, por eso depende de R-10. | P1 |
| R-12 | 2.4 | **Watchlist y alertas** | `users/{uid}/watchlist/{lotId}` (lo escribe el dueño). Dos push: "termina en 30 min" (una vez por lote) y "te superaron". Es lo más barato de esta lista y sube la reactivación; es el primero que recomiendo hacer. | P1 |
| R-13 | 2.5 | **Destacados de pago** | Tarifa fija configurable con preferencia MP e idempotencia por lote. Solo el webhook escribe `promoted_until`. Choca con la promesa de 0 % del Buen Fin: conviene lanzarlo después. | P2 |
| R-14 | 2.6 | **Búsquedas guardadas** | Job diario que manda un solo push agrupado por usuario. Vale la pena cuando haya bastantes lotes nuevos por día. | P2 |

## C. Fase 3 — Transmisión en vivo propia (LiveKit)

Hoy el vivo incrusta YouTube, con 10–30 s de latencia. Eso es aceptable para
mostrar el lote, pero no sirve para un martillo rápido. Mientras no exista la
Fase 3, en vivo funciona mejor con cierres por tiempo, no con "a la una, a
las dos".

| ID | Plan | Pendiente | Contexto | Prioridad |
|---|---|---|---|---|
| R-20 | 3.1 | Proveedor de video | LiveKit Cloud: WebRTC con latencia menor a 1 s y SDK de Flutter. Alternativa HLS: Cloudflare Stream o Mux. Hay que validar precios vigentes antes de contratar. | P1 |
| R-21 | 3.2 | "Ir en vivo" desde la app | Solo vendedores verificados. El reproductor va dentro de `live_stream_auction`. | P1 |
| R-22 | 3.3 | Retransmisión a Facebook y YouTube | Con LiveKit Egress. Las stream keys son secretos: viven solo del lado del servidor y nunca se pueden leer desde el cliente. | P2 |
| R-23 | 3.4 | Martillo sincronizado | Una función `callHammer` con cuenta regresiva de 10 s y anti-sniping normal. Depende de R-21. | P1 |
| R-24 | 3.5 | Grabación como evidencia | Egress a Storage, ligado al lote. Sirve como evidencia en disputas. | P2 |
| R-25 | 3.6 | Fallback YouTube | `stream_provider: youtube \| native`. YouTube se queda como respaldo. | P1 (junto con R-21) |

## D. Fase 4 — Crecimiento

| ID | Plan | Pendiente | Contexto | Prioridad |
|---|---|---|---|---|
| R-30 | 4.1 | SEO y deep links | Quitar `SEO_NOINDEX` cuando se lance. Faltan landing por categoría, sitemap de lotes activos y App Links / Universal Links. Las tarjetas OG `/l/{id}` ya existen. | P1 |
| R-31 | 4.2 | Comisión por categoría | `COMMISSION_TIERS_BY_CATEGORY`, con la misma validación estricta: una config inválida deja la liquidación en `needs_review`. | P2 |
| R-32 | 4.3 | Resumen diario | Push o correo a las 9 am hora CDMX. Depende de R-14. | P2 |
| R-33 | 4.4 | Analytics | Eventos: puja, publicación, depósito, compra, disputa, y el embudo en consola. Aunque la lista dice P1, **conviene hacerlo antes del Buen Fin**: sin eventos no se puede medir la campaña. | P1 |

## E. Fuera del plan original, pedidos durante el desarrollo

| ID | Pendiente | Contexto | Prioridad |
|---|---|---|---|
| R-40 | Chat comprador–vendedor | Hoy el contacto se libera tras el pago. Un chat dentro de la app permite moderar y deja evidencia para disputas. | P1 |
| R-41 | Pagos automáticos a vendedores | Hoy el admin transfiere a mano y registra la referencia SPEI. Para automatizar hacen falta MP Marketplace (split) u Openpay payouts, lo que cambia el flujo de cobro. | P2 (cuando el volumen pase de unas decenas de ventas por semana) |
| R-42 | Cobro automático de la membresía de Tienda Oficial | Hoy se cobra fuera de la app y el admin la activa a mano. No existe `STORE_PLAN_PRICE` en el código. **Falta decidir la cuota** (mensual/anual) antes de abril de 2027, cuando termina el lanzamiento y a los vendedores con más de 30 ventas al mes les conviene la tienda. | **P1** (antes de abril de 2027) |
| R-43 | Guías multi-paquetería | Estafeta, FedEx, UPS y DHL a través del proveedor del dueño: cotizar por peso y medidas y generar la guía. Necesita la API y las credenciales del proveedor. | P1 |
| R-44 | Verificación de identidad automática | Truora, MetaMap o Incode. Hoy la revisión del INE es manual en el panel. | P2 |
| R-45 | Reportar lote | Botón para que cualquier usuario reporte un lote y una cola de revisión en el panel. | P1 |
| R-46 | Campañas con nombre | El código solo soporta **una** ventana de 0 % (`COMMISSION_PROMO`). Si se quieren varias campañas (`CAMPAIGN_*`), es un cambio pequeño en `commission_policy.js`. | P2 |

---

### Orden sugerido después del lanzamiento

1. Primero R-01 → R-02 → R-07 → R-03, que van antes del Buen Fin.
2. Después R-33 (para medir), R-12 (watchlist) y R-45.
3. Luego R-10 → R-11.
4. R-20 → R-21/R-25 → R-23.

Lo demás según los datos.
