# CHANGELOG — Subástalo Aquí

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Versionado: [SemVer](https://semver.org/lang/es/).

Las fechas corresponden a los commits. La evidencia de cada versión está en
`EVIDENCIA_PRUEBAS.md`.

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
