# Evidencia de pruebas — Subástalo Aquí

## Estado al cierre de v1.0.0 (2026-10-15, CI de GitHub Actions)

En cada fila se indica qué se ejecutó de verdad y dónde. "CI" significa GitHub
Actions (`.github/workflows/pruebas.yml`, 3 trabajos) sobre el commit
etiquetado `v1.0.0`.

| Módulo / verificación | Estado | Detalle |
|---|---|---|
| Pruebas backend (Cloud Functions) | **EJECUTADO en CI y en local: 172/172 pasan** | Firestore, Mercado Pago, Openpay, FCM y Claude **simulados**. |
| Reglas Firestore + Storage en emulador oficial | **EJECUTADO en CI** | 21 casos de Firestore y 3 de Storage. Incluye el caso nuevo de lista blanca al publicar (auditoría v1.0.0). |
| `flutter analyze` / `flutter test` / `flutter build web` | **EJECUTADO en CI** | 0 errores y 0 advertencias. |
| Código de entrega en persona | **EJECUTADO: 5 pruebas + reglas** | Código erróneo, límite de 5 intentos, liberación instantánea y que el vendedor no puede leer el código. |
| Costo real del procesador con 0 % | **EJECUTADO: 4 pruebas** | Neto de MP, `fee` de Openpay, `platform` absorbe el costo y costo desconocido → `processing_fee_unknown`. |
| Pago final por SPEI (Openpay) | **EJECUTADO (simulado): 15 pruebas** | Sin cuenta de Openpay todavía: nunca se llamó a la API real. |
| Fase 0.1 App Check | **EJECUTADO (lógica): 4 pruebas** | Está en las 22 funciones callable, en modo `monitor`. **NO activado** en la consola (DEPLOY §e). |
| Fase 0.3 Fotos de lotes sin sesión | **EJECUTADO en emulador** | El CORS del bucket está documentado (DEPLOY §b.2) y **NO aplicado**. |
| Fase 0.4 Tarjetas Open Graph | **EJECUTADO (simulado): 3 pruebas** | Requiere tener Hosting desplegado. |
| Fases 1.1, 1.2 y 1.3 (reputación, disputas, segunda oportunidad) | **EJECUTADO: 9 + 13 + 8 pruebas** | Incluye casos de abuso. |
| Fase 2.3 Precio de reserva | **EJECUTADO: 7 pruebas + reglas** | — |
| Escrow + strike al vendedor | **EJECUTADO: 10 pruebas** | — |
| Modelo híbrido, entrega y municipios | **EJECUTADO: 13 + 6 + 2 pruebas** | — |
| Auditoría de secretos, reglas e índices | **EJECUTADO** | Ver `docs/AUDITORIA_v1.0.0.md`. |
| Validación de `.env.example` con los lectores de configuración del código | **EJECUTADO (local)** | Comisiones, campaña, costo del procesador, días de retención y App Check son válidos. Sin llave, la IA da el error esperado. |
| **Despliegue a producción** (DEPLOY.md) | **NO EJECUTADO** | Faltan plan Blaze, Storage y autorización del dueño. **LISTO PARA EJECUTAR HUMANO.** |
| **Verificación remota** (`verificar_remoto.sh`) | **NO EJECUTADO** | No hay nada desplegado que verificar. Se debe correr después de DEPLOY §h y pegar la salida aquí. |
| **Webhooks reales** de MP y Openpay | **NO EJECUTADO** | No hay cuentas de producción ni sandbox configuradas. Además, la simulación de SPEI en el sandbox de Openpay **no se verificó**. |
| **Prueba de punta a punta** (`CHECKLIST_E2E.md`) | **NO EJECUTADO** | Depende del despliegue. |
| Pruebas en dispositivo real | **NO EJECUTADO** | Sin backend desplegado, no hay flujo real de dinero. |

### Después de v1.0.0

| Módulo / verificación | Estado | Detalle |
|---|---|---|
| R-10 Precio fijo y "Comprar ahora" — backend | **EJECUTADO en local: 182/182 pasan (10 nuevas)** | `test/buy_now.test.js`: compra, doble compra simultánea (1 ganador, 1 cobro), abuso, INE, pujas bloqueadas, cierre sin venta, moroso sin segunda oportunidad, reserva. |
| R-10 — reglas y Flutter | **Ver CI del commit** | Caso nuevo en `rules-tests`; `flutter analyze` solo corre en CI (sin SDK en este entorno). |
| Comisión de lanzamiento + anti-sniping 2 min | **EJECUTADO en local: 188/188 pasan (6 nuevas)** | `test/launch_commission.test.js` (6): tope por mes, mes nuevo, mes de cierre vs. pago tardío, tienda y Buen Fin sin tope, configuración inválida → revisión y recálculo. Regla nueva: el cliente no toca `monthly_sales` (CI). |
| Sello "Vendedor fundador" | **EJECUTADO en local: 189/189 pasan (1 nueva)** | Asignar, retirar, idempotencia, cuenta suspendida, no cambia comisión. Regla nueva: el cliente no se da el sello (CI). |
| Precio fijo "aparta y paga" | **EJECUTADO en local: 194/194 pasan** | Sin depósito ni INE, apartado de 30 min, pago aprobado → liquidado, apartado vencido → vuelve a la venta sin strike, pago tardío devuelto, límite de 3 apartados, publicación vencida → sin venta. Reglas: no borrar lote apartado/vendido; no tocar `unpaid_buys` (CI). |
| **Despliegue parcial a producción (2026-10-26)** | **EJECUTADO** | Plan Blaze activo (cuenta de facturación en prueba gratuita, alerta de presupuesto $200 MXN). Storage creado (US-CENTRAL1, modo producción). Índices de Firestore y reglas de Firestore + Storage desplegados con el workflow "Desplegar a Firebase" (corrida 40334908064). Funciones y hosting nuevo: **pendientes** (credenciales de Mercado Pago). |
| R-10 en producción | **NO EJECUTADO** | Requiere desplegar reglas y funciones (Blaze). **LISTO PARA EJECUTAR HUMANO.** |

### Verificación remota

_(Vacío. Aquí se pega la salida de `bash scripts/verificar_remoto.sh` con la fecha, después de desplegar.)_

### Resultados de CHECKLIST_E2E

_(Vacío. Aquí se pega la tabla de resultados cuando se ejecute.)_

---

## Historial: versión v5 (correcciones de auditoría)


Fecha: 2026-10-14. Base: `bid_stream_v4.zip` (verificado byte a byte contra la
copia de trabajo antes de cambiar nada). **Nota:** el archivo de auditoría no
llegó adjunto; las correcciones se basan en los hallazgos descritos en el
mensaje (incluido el caso reproducido del incremento negativo).

Todo lo que dice "EJECUTADO" se corrió en esta versión (v5). Nada de lo aquí
reportado proviene de versiones anteriores.

## Resumen

| Verificación | Estado | Detalle |
|---|---|---|
| Pruebas backend (Cloud Functions) | **EJECUTADO: 90/90 pasan** | Node 22 local (producción usa Node 20). Firestore, Mercado Pago, FCM y Claude **simulados** |
| Reproducción del hallazgo (incremento −200) | **EJECUTADO** | En v4 una oferta de 800 bajó el precio de 1000 a **600**. En v5 se rechaza (servidor y reglas) |
| Reglas en emulador | **NO EJECUTADO** | El emulador oficial no se puede descargar en este entorno (`storage.googleapis.com` bloqueado). Suite lista: `firebase/rules-tests` (12 casos, con decenas de aserciones) |
| `flutter analyze` / `flutter test` / compilación | **NO EJECUTADO** | `pub.dev` y el SDK de Flutter bloqueados en este entorno. Se agregaron pruebas Dart nuevas, sin ejecutar |
| Estado remoto (reglas, índice, funciones, plan) | **NO VERIFICADO** | Sin credenciales y sin autorización para tocar el proyecto remoto. Script de solo lectura: `firebase/scripts/verificar_remoto.sh` |
| Verificación local de configuración | **EJECUTADO** | Índice `lots(status ASC, end_time ASC)` presente en `firestore.indexes.json`; 16 funciones exportadas en `index.js` |

## Cómo completar lo pendiente (en tu computadora)

```bash
# 1) App Flutter
flutter pub get && flutter analyze && flutter test && flutter build web --release

# 2) Reglas con el emulador oficial (Java 11+ y firebase-tools)
cd firebase/rules-tests && npm install && npm test

# 3) Backend
cd firebase/functions && npm install && npm test

# 4) Estado remoto, SOLO LECTURA (no despliega ni cambia nada)
cd firebase && bash scripts/verificar_remoto.sh
```

## Salida real de `npm test` (firebase/functions)

```
    ok 1 - verificación: enviar, aprobar y quedar verificado
    ok 2 - verificación: no acepta fotos de otra persona ni faltantes
    ok 3 - rechazo exige motivo
    ok 4 - un usuario normal no puede usar funciones de admin
    ok 5 - suspender revoca la sesión; marcar payout enviado una sola vez
    ok 6 - cancelar lote activo avisa a vendedor y líder
    ok 7 - reintentar cobro cuando Mercado Pago había fallado
    ok 8 - pujas altas requieren identidad verificada
    ok 9 - borra teléfonos y correos que la IA pudiera incluir
    ok 10 - sanitiza categoría inválida y recorta listas
    ok 11 - valida fotos: formato y tamaño
    ok 12 - configuración del proveedor: estricta y explícita
    ok 13 - con configuración inválida responde error claro y NO consume cuota
    ok 14 - llama a Claude con fotos, estado y notas; exige revisión humana
    ok 15 - permisos: suspendidos y sin identidad verificada no pueden usarlo
    ok 16 - exige estado del artículo (y no acepta claves heredadas)
    ok 17 - límite diario por usuario
    ok 18 - límite diario global de la plataforma
    ok 19 - si el proveedor falla, se devuelve el uso consumido
    ok 20 - respuesta truncada o sin propuesta: error y se devuelve el uso
    ok 21 - uso concurrente no rebasa el límite
    ok 22 - primera oferta: precio visible = precio inicial, no el máximo
    ok 23 - primera oferta menor al precio inicial se rechaza
    ok 24 - el proxy responde por el líder superando al retador por un incremento
    ok 25 - el proxy nunca rebasa el máximo secreto del líder
    ok 26 - empate de máximos: gana quien ofertó primero
    ok 27 - un retador con máximo mayor pasa a ganar pagando solo lo necesario
    ok 28 - si el nuevo máximo supera al del líder por menos de un incremento, el precio es su máximo
    ok 29 - el retador debe ofrecer al menos puja actual + incremento
    ok 30 - el líder puede subir su máximo sin mover precio ni cierre
    ok 31 - el líder no puede bajar ni repetir su máximo
    ok 32 - guerra de pujas: el resultado es el segundo máximo + incremento
    ok 33 - centavos sin errores de punto flotante
    ok 34 - validaciones generales
    ok 35 - lotes antiguos sin estado privado se reconstruyen
    ok 36 - anti-sniping: con 30 s o menos, cierre = ahora + 30 s
    ok 37 - anti-sniping: con más de 30 s o ya vencido, no cambia
    ok 38 - una oferta válida a 10 s del cierre extiende la subasta
    ok 39 - una oferta rechazada no extiende la subasta
    ok 40 - mínimo siguiente
    ok 41 - nombre público protege apellidos
    ok 42 - AUDITORÍA: incremento negativo ya no puede bajar el precio de 1000 a menos
    ok 43 - rechaza importes inválidos en el lote
    ok 44 - rechaza estados inconsistentes
    ok 45 - propiedad: en 2000 ofertas aleatorias el precio nunca baja ni rebasa el máximo del líder
    ok 46 - tramos marginales
    ok 47 - sin brincos al cruzar un tramo
    ok 48 - comisión mínima y nunca mayor al precio
    ok 49 - sin variables: 10% plano por defecto (explícito y documentado)
    ok 50 - configuraciones inválidas producen error explícito, nunca otro porcentaje
    ok 51 - sin configuración válida, calcular la comisión lanza error
    ok 52 - la configuración inválida se reporta y no se reemplaza por otro valor
    ok 53 - el pago entra, la liquidación queda en revisión y el admin no puede 'arreglarla' sin corregir la config
    ok 54 - el depósito solo se descuenta UNA vez aunque gane varios lotes
    ok 55 - si el depósito supera el precio, se liquida y se reembolsa la diferencia
    ok 56 - pago del ganador aprobado: liquida una sola vez y comparte contactos
    ok 57 - pago con monto menor al adeudado se reembolsa y no liquida
    ok 58 - no pagó a tiempo: pierde el depósito reservado, strike y compensación
    ok 59 - pago tardío después del castigo: se reembolsa, no se paga doble al vendedor
    ok 60 - segundo incumplimiento banea la cuenta
    ok 61 - si Mercado Pago falla al cerrar, el lote queda en payment_error (no se castiga)
    ok 62 - depósito por webhook: se activa una vez; un segundo depósito se reembolsa
    ok 63 - firma inválida del webhook se rechaza
    ok 64 - reembolso de depósito: bloqueado si va ganando; si no, una sola vez
    ok 65 - no se puede pujar mientras el depósito se está reembolsando
    ok 66 - firma válida se acepta
    ok 67 - firma con secreto distinto se rechaza
    ok 68 - idempotencia de referencias externas
    ok 69 - cálculo del pago del ganador con depósito aplicado
    ok 70 - guarda la oferta con los campos pedidos y oculta el máximo
    ok 71 - el proxy responde y actualiza la puja efectiva del líder
    ok 72 - cambio de líder: avisa al anterior
    ok 73 - rechaza ofertas menores a puja actual + incremento
    ok 74 - anti-sniping: oferta a 10 s del cierre lo mueve a ahora + 30 s
    ok 75 - anti-sniping: con más de 30 s no se toca el cierre
    ok 76 - pujas simultáneas: la transacción se reintenta y el resultado es consistente
    ok 77 - sin depósito de garantía no se puja
    ok 78 - 10 pujas simultáneas: gana el máximo más alto y paga segundo máximo + incremento
    ok 79 - doble toque del mismo usuario: una sola puja efectiva, sin inconsistencias
    ok 80 - si lo suspenden entre la revisión rápida y la transacción, se rechaza
    ok 81 - si retira la aceptación de términos en medio, se rechaza
    ok 82 - si le revocan la verificación de identidad en medio, una puja alta se rechaza
    ok 83 - si el perfil se borra en medio, se rechaza
    ok 84 - el aviso 'te superaron' se escribe en la misma transacción que la puja
    ok 85 - una falla al escribir el aviso no deja una puja confirmada reportada como rechazada
    ok 86 - falla del push no afecta nada (el trigger la absorbe)
    ok 87 - lote con datos corruptos (incremento negativo) rechaza la puja sin tocar nada
    ok 88 - mensaje urgente con enlace al lote
    ok 89 - envía a todos los dispositivos y borra tokens muertos
    ok 90 - sin dispositivos no manda nada
# tests 90 · pass 90 · fail 0
```
