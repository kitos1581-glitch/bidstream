# Auditoría final del repositorio — v1.0.0 (2026-10-15)

**Alcance:** el árbol actual y **todo el historial de git**.
**Método:** comandos reproducibles, listados abajo.
**Lo que no se auditó:** el proyecto remoto de Firebase. Su revisión está en
DEPLOY.md §h y queda **NO EJECUTADA** hasta que se despliegue.

## 1. Secretos

| Revisión | Comando | Resultado |
|---|---|---|
| Llaves de Google | `git grep -n AIza` | 4 apariciones: `google-services.json`, `GoogleService-Info.plist`, `firebase_config.dart` y `firebase-messaging-sw.js`. Son **llaves de cliente de Firebase**, públicas por diseño: viajan dentro de cualquier app o web compilada. **No se revocan.** Su protección real son las reglas, App Check y la restricción de la llave (ver la acción humana A-1). |
| Llaves de Anthropic | `git grep -nE 'sk-ant-[A-Za-z0-9]'` | Solo hay marcadores ficticios (`sk-ant-api03-…` / `000…`) en la documentación. |
| Llaves de Openpay | `git grep -nE 'sk_[a-z0-9]{16,}'` | En `test/spei.test.js` estaba `sk_e568c42a…` con el comercio `mzdtln0b…`. Son las **credenciales de ejemplo de la documentación pública de Openpay**, no de esta cuenta. Igual **se reemplazaron por ceros** para que ningún escáner las marque. |
| Tokens de Mercado Pago | `git grep -nE 'APP_USR-[0-9]\|TEST-[0-9]{6,}'` | Solo el ejemplo ficticio de `.env.example`. Las pruebas usan `"TEST-token"`. |
| Llaves privadas | `git grep -n -i 'private_key\|BEGIN .*PRIVATE KEY'` | Solo aparecen nombres de variables y textos de documentación; no hay llaves. |
| Historial completo | `git log --all -p \| grep -E '^\+.*(APP_USR-[0-9]\|sk-ant-[A-Za-z0-9]\|BEGIN .*PRIVATE KEY\|"private_key")'` | **Nunca** se versionó un secreto real. |
| Archivos sensibles en el historial | `git log --all --name-only \| grep -iE '\.env\|adminsdk\|\.p8\|\.jks\|key\.properties'` | Solo `firebase/functions/.env.example`. |

**Riesgo que corregí:** `.gitignore` **no excluía** `firebase/functions/.env`.
Con el primer `git add -A` después de configurar producción se habrían subido
las llaves de MP, Openpay y Anthropic. Ahora se excluyen:
- `.env` y `.env.*` (excepto `.env.example`);
- llaves de cuenta de servicio;
- keystores;
- `key.properties`;
- archivos `.p8`.

**No hubo que revocar nada.** Ningún secreto real llegó a git.

## 2. TODO / FIXME / HACK

Comando: `git grep -nE 'TODO|FIXME|HACK'`.

| Dónde | Qué era | Decisión |
|---|---|---|
| `android/app/build.gradle` (applicationId) | `com.mycompany.bidstream` | Lo dejé como está, con referencia a **ROADMAP R-05**. Cambiarlo rompe la vinculación con Firebase si no se registra otra vez la app, así que no es trivial. |
| `android/app/build.gradle` (firma release) | Firma con llaves debug | Lo dejé como está, con referencia a **ROADMAP R-04**. Requiere un keystore del dueño. |

Después del cambio, `git grep` solo encuentra la palabra española "TODOS" en
la documentación.

## 3. Reglas (deny-by-default)

**Firestore**
- El `match /{document=**}` final sigue en `allow read, write: if false`.
- Hay lectura pública **intencional** en:
  - `lots` y `lots/*/history`: catálogo sin cuenta;
  - `feedback` y `public_profiles`: reputación.
- Ninguna otra colección permite lectura anónima.
- Todo lo de dinero, disputas, reputación y estado privado queda en
  `write: if false`:
  - `payments`, `disputes`, `feedback`, `public_profiles`;
  - `lots/*/bids`, `lots/*/private/*`;
  - `users/*/delivery_codes`, `users/*/bidding`, `users/*/ai_usage`;
  - `verifications`, `admin_log`.

**Hallazgo y corrección.** Al publicar un lote, la regla usaba una **lista
negra** de campos prohibidos. Faltaban campos que el servidor escribe y luego
lee:
- `processing_fee`;
- `closed_time`;
- `paid_time`;
- campos futuros como `promoted_until`.

No encontré un abuso explotable hoy: el servidor sobrescribe esos campos al
cerrar y al cobrar antes de usarlos. Aun así, era frágil: un módulo nuevo
podía abrir un hueco sin que nadie lo notara. **La regla ahora es una lista
blanca** (`keys().hasOnly([...])`) con exactamente los 19 campos que manda la
app. Además, `created_time` debe ser la hora del servidor. Prueba nueva en
`rules-tests`: *"AUDITORÍA v1.0.0: al publicar solo se aceptan los campos de
la app"*.

**Actualización de lotes y perfiles de usuario.** Ya usaban lista blanca
(`onlyChanges`) o bloqueaban explícitamente:
- `verified`, `role`, `banned`, `deposit`, `strikes`;
- `seller_strikes`, `seller_plan`, `store_*`.

Comprobé que cada campo de `users` que escribe el servidor está en esa lista.

**Storage**
- Base `/{allPaths=**}` cerrada.
- `lots/{uid}`: lectura pública intencional; escritura solo del dueño, solo
  imágenes, menos de 10 MB.
- `verifications` y `disputes`: solo el dueño y el admin.
- `users/{uid}`: lectura con sesión.

## 4. Índices de Firestore

Revisé cada consulta del backend y de la app. Comando:
`grep -rnE '\.where\(|orderBy\('`.

| Consulta | Necesita compuesto | Índice |
|---|---|---|
| `lots` status == + end_time ≤ + orderBy end_time (cierre de subastas, backend) | Sí | ✅ `status, end_time` |
| `lots` status == + payment_status == + payment_due_time ≤ (`expireUnpaidWins`) | Sí | ✅ `status, payment_status, payment_due_time` |
| `lots` status == + orderBy end_time (catálogo y admin) | Sí | ✅ `status, end_time` |
| `lots` seller_uid == + orderBy created_time desc (mis ventas y perfil público) | Sí | ✅ |
| `lots` winner_uid == + orderBy end_time desc (ganadas) | Sí | ✅ |
| `feedback` seller_uid == + orderBy created_time desc | Sí | ✅ |
| `payments` kind == + status == / in (panel) | No: solo igualdades; las sirven los índices simples | — |
| `disputes` status in · `verifications` status == · `users` email == · `lots` payment_status == · `lots` highest_bidder_uid == · `lots` second_chance.status == · `payments` lot_id == · `payments` status == | No: un solo campo | — |
| `history`, `bidding`, `notifications` orderBy de un campo | No | — |

**Resultado: no falta ningún índice.** `firestore.indexes.json` queda sin
cambios.

## 5. Acciones humanas que salen de esta auditoría

- **A-1. Restringir las llaves de API de Firebase. LISTO PARA EJECUTAR HUMANO.**
  1. Entra a Google Cloud Console → APIs y servicios → Credenciales.
  2. **Llave de navegador:** en "Restricciones de aplicaciones", elige
     *Sitios web* y agrega el dominio final, `bidstream-656cf.web.app`,
     `bidstream-656cf.firebaseapp.com` y `kitos1581-glitch.github.io`.
  3. **Llaves de Android e iOS:** restríngelas por app; Android con paquete y
     SHA-1, iOS con bundle ID.
  4. En las tres, limita las APIs a las de Firebase: Identity Toolkit,
     Firestore, Storage, Installations, FCM y App Check.
- **A-2.** El `og:image` genérico de `web/index.html` apunta a una imagen
  hospedada por FlutterFlow. Hay que cambiarlo por el logo final (R-06).

## 6. Pruebas corridas en esta auditoría

| Suite | Resultado |
|---|---|
| Backend (`npm test`) | 172/172 ✅ (local, Node 22) |
| `spei.test.js` con las llaves ficticias nuevas | 15/15 ✅ |
| Reglas (emulador) | Validé la sintaxis localmente. **Corren en CI**, porque esta computadora no tiene Java ni Firebase CLI. El resultado está en el commit de cierre. |
| Flutter | **En CI**, porque esta computadora no tiene Flutter. Solo cambiaron comentarios de `build.gradle`. |
