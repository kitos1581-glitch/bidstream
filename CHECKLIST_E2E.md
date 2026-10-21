# CHECKLIST E2E: prueba manual de punta a punta (sandbox)

Este guion recorre todo el ciclo de dinero y confianza con **cuentas reales
de la app** y **dinero de pruebas**: usuarios de prueba de Mercado Pago y el
sandbox de Openpay.

> **Estado al 2026-10-15: NO EJECUTADO.** Requiere el despliegue de
> [`DEPLOY.md`](DEPLOY.md), que está pendiente. Ningún paso se ha corrido
> contra un proyecto real.
>
> El backend sí está cubierto por las 172 pruebas automáticas (Firestore y MP
> simulados) y las reglas por 23 casos en el emulador. Esta lista valida lo
> que las pruebas automáticas **no pueden** cubrir:
> - correo real;
> - checkout de MP;
> - webhooks reales;
> - push;
> - la interfaz en el celular.

**Cómo registrar el resultado.** Copia la tabla del final a
`EVIDENCIA_PRUEBAS.md` y marca cada paso así:
- `EJECUTADO ✅`;
- `EJECUTADO ❌ (qué pasó)`;
- `NO EJECUTADO (por qué)`.

Cuando algo falle, guarda una captura y el `id` del lote o del documento.

---

## 0. Preparación (una vez)

| # | Qué | Detalle |
|---|---|---|
| 0.1 | Proyecto | Despliega con `MP_ACCESS_TOKEN=TEST-…` y `OPENPAY_SANDBOX=true`. Para que la prueba de liberación automática (paso 9) no tarde una semana, pon `PAYOUT_RELEASE_DAYS=1`. **Regrésalo a 7 al terminar.** |
| 0.2 | Cuentas de la app | **A = vendedor**, **B = comprador**, **C = segundo postor**, **ADM = admin** (DEPLOY.md §f). Usa correos reales distintos; Gmail acepta alias `tucorreo+a@gmail.com`. |
| 0.3 | Usuarios de prueba MP | En mercadopago.com.mx/developers → *Cuentas de prueba*, crea dos compradores de prueba: uno para B y otro para C. Al pagar en el checkout, inicia sesión con ellos. Usa las **tarjetas de prueba** de la documentación de MP. |
| 0.4 | Dispositivos | Para ver las dos sesiones al mismo tiempo: Chrome normal + ventana de incógnito, o computadora + celular. |
| 0.5 | Acelerar tiempos | Algunos pasos piden editar un campo en **Consola → Firestore**. Eso solo se permite en sandbox: la consola no pasa por las reglas. **Nunca lo hagas en producción.** Anota cada edición en la evidencia. |

---

## 1. Registro con correo real

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 1.1 | Con **A**: abre la app → **Crear cuenta** con correo y contraseña. | Te lleva a **Completa tu cuenta**. | Consola → Authentication → borrar usuario (y `users/{uid}` en Firestore). |
| 1.2 | Revisa el correo de A y abre el enlace de verificación (revisa spam). Si no llega, usa **Reenviar correo**. | El correo llega **en español**. Al volver a la app, el correo aparece como verificado. | — |
| 1.3 | Llena nombre, teléfono, municipio y acepta términos → Guardar. | "Perfil guardado." Si no aceptas términos: "Debes aceptar los términos para continuar." | Edítalo de nuevo en Mi cuenta. |
| 1.4 | Repite 1.1–1.3 con **B**, **C** y **ADM**. | Igual que A. | Igual que 1.1. |
| 1.5 | Sin iniciar sesión, abre el inicio. | El catálogo y las fotos se ven sin cuenta. Si las fotos no aparecen en web, falta el CORS (DEPLOY §b.2-4). | — |

## 2. Verificación de identidad (INE, flujo admin)

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 2.1 | **A** → Mi cuenta → **Verificar identidad (INE)**: frente, reverso y selfie (Cámara o Galería) → Enviar. | "Enviado. Te avisaremos cuando lo revisemos." Los archivos quedan en Storage `verifications/{uid}/`. | Admin → Identidad → **Rechazar** (con motivo). |
| 2.2 | **B** intenta abrir una foto de A pegando la URL de Storage en el navegador. | **Acceso denegado.** Las fotos de INE solo las ven el dueño y los admins. | — |
| 2.3 | **ADM** → Administración → pestaña **Identidad** → solicitud de A → **Ver prueba** → **Aprobar**. | A recibe un aviso (y push en Android o web). Su perfil muestra el distintivo de verificado. | **Rechazar** o suspender desde **Usuarios**. Queda registrado en `admin_log`. |
| 2.4 | Rechazo: envía otra solicitud con una foto borrosa usando **C** → ADM la **Rechaza** con motivo. | C recibe el aviso con el motivo y puede reenviar. | — |
| 2.5 | **C** (sin INE) intenta publicar un lote. | Se bloquea: "Verifica tu identidad". | — |

## 3. Depósito de $200 (MP sandbox)

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 3.1 | **B** entra a un lote y toca **Pujar** sin depósito. | "Falta tu depósito de garantía", con botón **Dejar depósito**. | — |
| 3.2 | **Dejar depósito y poder pujar** → se abre el checkout de MP → paga con el comprador de prueba y una tarjeta de prueba aprobada. | Regresa a `SITE_URL`. En 1–60 s: `users/{B}.deposit.status = held`. En el panel de MP → Webhooks: entrega con **200**. | **Pedir reembolso del depósito** (paso 3.4). |
| 3.3 | Repite con **C**. | Igual que 3.2. | Igual. |
| 3.4 | *(Al final de toda la prueba)* B → **Pedir reembolso del depósito**. | Solo se permite si B no va ganando nada ni debe pagos. El reembolso aparece en el panel de MP y el depósito queda `refunded`. | — |
| 3.5 | Pago **rechazado**: usa una tarjeta de prueba que MP marque como rechazada. | El depósito **no** se activa y no se puede pujar. | — |

## 4. Publicar lote (fotos, reserva, envío regional)

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 4.1 | **A** → **Publicar** → agrega 3–6 fotos → (opcional) **Llenar con IA**. | La IA propone título, categoría y descripción. "Listo. Revisa y corrige…". Sin `ANTHROPIC_API_KEY`, solo el asistente da error; lo demás funciona. | — |
| 4.2 | Formato **por tiempo**, precio inicial **$1,000**, incremento $50, **Precio de reserva (opcional, secreto) = $1,500**. | — | — |
| 4.3 | Entrega: marca **Entrega a acordar con el comprador** y **Envío regional / intermunicipal**, con costo **$150**, municipios Camargo y Jiménez. Municipio del artículo: Camargo. | Sin forma de entrega: "Elige al menos una forma de entrega." | — |
| 4.4 | **Publicar lote**. | El lote aparece en el inicio. Con el filtro de municipio Camargo se ve; con Delicias no. En el detalle se ve "Tiene precio de reserva", **nunca el monto**. | **Eliminar** (solo si nadie ha pujado). Si ya hay pujas: Admin → **Lotes** → Cancelar. |
| 4.5 | **Seguridad**: desde la sesión de B, intenta leer `lots/{id}/private/reserve`. Puedes hacerlo con las DevTools de la web o confiar en la prueba de reglas. | Permiso denegado. | — |
| 4.6 | Prepara un **segundo lote** de A para el paso 10 (segunda oportunidad): por tiempo, precio inicial $500, **sin reserva**, solo "a acordar". | — | Igual que 4.4. |

## 5. Puja proxy con 2 cuentas y anti-sniping

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 5.1 | **A** intenta pujar en su propio lote. | "Este es tu lote. No puedes pujar en él." | — |
| 5.2 | **B** puja un máximo de **$1,200** → **Confirmar puja**. | El precio visible queda en **$1,000** (primera oferta = precio inicial). En el historial: "B. (inicial)". B ve "Mi máximo: $1,200". | Las pujas no se pueden borrar; usa un lote nuevo. |
| 5.3 | **C** puja **$1,100**. | El sistema puja por B: el precio queda en **$1,150** (1,100 + 50), y B sigue líder. C ve que lo superaron. B **no** recibe aviso. | — |
| 5.4 | **C** puja **$1,600**. | Como 1,600 ≥ reserva, el precio sube a **$1,500** (directo a la reserva, no a 1,250). "Reserva alcanzada". B recibe "Te superaron" (aviso + push). | — |
| 5.5 | **B** sube a **$1,700**. | El precio queda en $1,650 y B es líder. | — |
| 5.6 | **Anti-sniping**: en Consola → Firestore → `lots/{id}`, pon `end_time` = ahora + 4 min (sandbox, §0.5). Cuando falten **≤ 40 s**, **C** puja $1,800. | `end_time` pasa a **ahora + 40 s** y la cuenta regresiva se reinicia. El historial muestra horas crecientes. | — |
| 5.7 | **Doble clic / dos pestañas**: B puja el mismo monto dos veces seguidas. | Solo se registra una oferta; la otra recibe un error claro. | — |
| 5.8 | **Puja alta sin INE**: con C sin INE, puja **$20,001** en otro lote. | Rechazada: exige verificación (`VERIFIED_BID_THRESHOLD`). | — |

## 6. Cierre

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 6.1 | Espera el fin (`closeEndedAuctions` corre cada minuto). | Hay hasta ~1 min de retraso. El lote pasa a `ended`. El ganador (B o C, quien quedó arriba) recibe "¡Ganaste!" y A "Vendiste". | — |
| 6.2 | Ganador → detalle del lote. | Como hay dos formas de entrega: "Primero, ¿cómo quieres recibirlo?". Elige **Envío a mi municipio** → Jiménez. | — |
| 6.3 | Revisa el total. | Total = precio final − **$200 de depósito** + **$150 de envío**. Plazo de 24 h (`WINNER_PAYMENT_WINDOW_HOURS`). | — |
| 6.4 | **Reserva no alcanzada** (lote aparte): publica un lote con reserva $5,000 y puja $2,000. | Al cerrar: "Terminó sin venta: no se alcanzó el precio de reserva del vendedor." Sin ganador, sin cobro. El depósito del líder sigue disponible. | — |

## 7. Pago del ganador

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 7.1 | Ganador → **¿Cómo quieres pagar?** → **Tarjeta o saldo Mercado Pago** → **Pagar ahora** → paga en el checkout de pruebas. | `lots/{id}.payment_status = paid`. A recibe "¡Cobrada!". En `payments` aparece un payout `kind: payout` con **`status: held`** (retenido), `commission_policy: standard` y la comisión por tramos. | Reembolso total vía disputa (paso 11) o desde el panel de MP. |
| 7.2 | **SPEI** (en otro lote ganado): elige **Transfiere desde tu banco por SPEI**. | La app muestra CLABE, banco, referencia y monto. La CLABE **no** queda en `lots/{id}`; vive en `payments/openpay_charge_{id}`. | La referencia vence sola (`due_date`). |
| 7.3 | Simula el pago SPEI en el sandbox de Openpay (DEPLOY §d.2-4, **no verificado**). | El webhook responde 200, el lote queda `paid` y el payout `held`. | — |
| 7.4 | **Pago doble**: vuelve a abrir el enlace de pago ya pagado. | No se cobra dos veces. Si MP llegara a aprobar un duplicado, se reembolsa solo (o queda `manual_required` en SPEI). | — |
| 7.5 | Contactos | Ya pagado, A ve el contacto de B y B el de A en los avisos. | — |

## 8. Confirmación de entrega con código

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 8.1 | Usa un lote ganado con **Entrega a acordar** (lote del paso 4.6 o uno nuevo) y págalo. | El comprador ve **Tu código de entrega** (6 dígitos). El vendedor ve **¿Entregaste en persona?**. | — |
| 8.2 | **A** escribe un código **incorrecto** 2 veces. | Error con los intentos restantes (máximo 5). | — |
| 8.3 | **A** escribe el código correcto. | "¡Entrega confirmada! Tu pago quedó liberado." El payout pasa de `held` a **`ready`** de inmediato, y el comprador ya puede calificar. | No se revierte desde la app; si hace falta, el ADM abre un reclamo manual. |
| 8.4 | Envío (lote de los pasos 4–7): **B** toca **Sí, lo recibí** → confirma. | El payout pasa a `ready` y se cierra la ventana de reclamo. "Listo. Ahora puedes calificar al vendedor." | — |
| 8.5 | **Liberación automática**: en otro lote pagado sin confirmar, cambia en Firestore `payments/{payout}.release_after` a una fecha pasada (sandbox). | En ≤ 1 h (`releaseDuePayoutsJob`), el payout queda `ready`. | — |

## 9. Feedback

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 9.1 | Comprador → **¿Cómo te fue con el vendedor?** → 5 estrellas + comentario con un teléfono "6141234567". | "¡Gracias! Tu opinión ayuda a otros compradores." El teléfono aparece **oculto** en el comentario publicado. | **Editar (hasta 7 días)**. |
| 9.2 | Abre el perfil público del vendedor (`/vendedor?uid=…`). | Promedio, número de opiniones y ventas, insignias ("Vendedor nuevo" si tiene < 3 ventas). **Sin** teléfono ni correo. | — |
| 9.3 | **C** (que no compró) intenta calificar ese lote. | No aparece la opción; si se fuerza por API, el servidor la rechaza. | — |

## 10. Segunda oportunidad

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 10.1 | En el lote de 4.6, **B** puja $700 y **C** puja $900 (C líder, B subcampeón). Acelera el cierre (§0.5). | C gana. | — |
| 10.2 | C **no paga**. En Firestore, `lots/{id}.payment_due_time` = fecha pasada (sandbox). | En ≤ 15 min (`expireUnpaidWins`): el depósito de C queda `forfeited` y +1 strike. A recibe la compensación. B recibe **Segunda oportunidad** por **su máximo, $700**, con 24 h. | El strike se quita desde Admin → Usuarios; el depósito no se devuelve, por diseño. |
| 10.3 | **B** → **Segunda oportunidad** → acepta → paga. | B queda como ganador, con el cobro normal (depósito aplicado) y payout `held`. | — |
| 10.4 | Variante: B toca **No, gracias**. | El lote cierra sin venta y B no recibe castigo. No hay una segunda oferta a otro postor (solo una por lote). | — |

## 11. Disputa con reembolso parcial

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 11.1 | En un lote pagado y **aún retenido** (no confirmes la entrega), el comprador toca **¿No llegó o llegó distinto? Reclamar** → motivo + descripción (≥ 20 caracteres) + fotos. | "Recibimos tu reclamo. El pago al vendedor queda en pausa…". Payout `on_hold`. El perfil del vendedor muestra "en disputa". El vendedor recibe un aviso. | — |
| 11.2 | **ADM** → Pagos: intenta **Marcar enviado** en ese payout. | **No se permite** mientras esté en disputa. | — |
| 11.3 | **ADM** → **Reclamos** → **Reembolso parcial** → monto **$300** → nota. | Se reembolsan $300 en el panel de MP (con llave de idempotencia). El payout baja $300 y **regresa al estado que tenía antes del reclamo** (normalmente `held`, que se libera con "Sí, lo recibí" o automáticamente). Ambos reciben aviso. Se quita "en disputa". | Si MP rechaza el reembolso: queda `refund_failed`, con botón para reintentar. |
| 11.4 | Variante de **reembolso total** en otro lote. | Se devuelve el pago completo y el payout queda `cancelled`. El vendedor recibe un strike (`seller_strikes`); al segundo, se suspende la cuenta. | Admin → Usuarios → Reactivar. |
| 11.5 | Variante de **clawback**: marca el payout como enviado (8.x) y **después** resuelve con reembolso. | Se crea `payments/clawback-{disputeId}` para cobrarle al vendedor (el id de la disputa es el del lote). | — |

## 12. Tienda Oficial (0 % de comisión)

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 12.1 | **ADM** → Usuarios → busca a A → **Hacer Tienda Oficial** → nombre "Tienda Prueba", 1 mes. | A recibe la insignia **Tienda Oficial: Tienda Prueba** en el perfil y las tarjetas. Exige INE aprobada (intenta con C sin INE: rechazado). | **Cancelar tienda**. |
| 12.2 | A vende un lote nuevo y el comprador paga con MP. | Payout con `commission_policy: store`, comisión **$0**, y `processing_fee` = costo **real** de MP (`transaction_amount − net_received_amount`), descontado al vendedor. El comprador **no** paga ningún recargo. | — |
| 12.3 | Campaña: pon `COMMISSION_PROMO` con una ventana que incluya **hoy**, vuelve a desplegar las funciones y vende un lote de un vendedor **sin** tienda. | `commission_policy: promo` con comisión $0. | Borra `COMMISSION_PROMO` y vuelve a desplegar. |
| 12.4 | Escribe `COMMISSION_PROMO=hola` y vuelve a desplegar. | Las ventas nuevas quedan `needs_review` y aparece un error en los logs; **nunca** se aplica otro % en silencio. Corrige, vuelve a desplegar y usa **Recalcular**. | Corrige `.env`. |

## 13. Retiro SPEI simulado (pago al vendedor)

Hoy el pago al vendedor es **manual** (ROADMAP R-41): el admin transfiere
desde su banco o desde MP y registra la referencia. En sandbox **no se mueve
dinero real**; solo se prueba el registro.

| Paso | Acción | Qué se espera y dónde | Cómo revertir |
|---|---|---|---|
| 13.1 | **ADM** → **Pagos** → payout `ready` de A. | Muestra el monto neto y la CLABE del vendedor; solo el admin la ve. | — |
| 13.2 | **Marcar enviado** → Referencia: `SIMULADO-0001`. | Payout `sent`, con la referencia guardada. A recibe el aviso de pago enviado. Queda en `admin_log`. | No hay "deshacer" en la app. Si fue un error, se corrige en Firestore y se anota en la evidencia. |
| 13.3 | Intenta **Marcar enviado** en un payout `held` u `on_hold`. | No se permite. | — |

## 14. Cierre de la prueba

- Reembolsa los depósitos de B y C (paso 3.4).
- Regresa `PAYOUT_RELEASE_DAYS=7`, quita `COMMISSION_PROMO` si no aplica y
  vuelve a desplegar.
- Cancela la Tienda Oficial de prueba.
- Borra los usuarios y lotes de prueba, **o** márcalos con `[PRUEBA]` en el
  título si prefieres conservar la evidencia.
- Pega la tabla de resultados en `EVIDENCIA_PRUEBAS.md`:

```
| Paso | Resultado | Notas / ids |
|------|-----------|-------------|
| 1.1  |           |             |
| …    |           |             |
```
