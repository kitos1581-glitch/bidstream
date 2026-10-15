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
| R-07 | Dominio definitivo | El dominio actual es GitHub Pages, que queda como *staging*. La decisión y los pasos están en DEPLOY.md §g. | **P0** antes del Buen Fin |

## B. Fase 2 pendiente — Conversión y monetización

| ID | Plan | Pendiente | Contexto | Prioridad |
|---|---|---|---|---|
| R-10 | 2.1 | **Comprar Ahora** | Campo `buy_now_price ≥ precio inicial`. La compra la hace el servidor, cierra el lote y reutiliza `startWinnerPayment` (con escrow y la política de comisión actuales). El vendedor lo puede retirar mientras no haya pujas. La prueba de abuso clave es una doble compra simultánea. | P1 |
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
| R-42 | Cobro automático de la membresía de Tienda Oficial | Hoy se cobra fuera de la app y el admin la activa a mano. No existe `STORE_PLAN_PRICE` en el código. | P2 |
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
