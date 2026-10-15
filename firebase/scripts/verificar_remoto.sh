#!/usr/bin/env bash
# =====================================================================
# Verificación REMOTA de solo lectura del proyecto Firebase de Subástalo Aquí.
# NO despliega, NO cambia facturación, NO modifica datos.
# Requiere: firebase login  y  gcloud auth login  con tu cuenta.
# Uso (desde firebase/):  bash scripts/verificar_remoto.sh
# =====================================================================
set -u
PROJECT="${1:-bidstream-656cf}"
echo "== Proyecto: $PROJECT  ($(date))"

echo; echo "== 1) Plan de facturación (Blaze = cuenta de facturación activa)"
gcloud billing projects describe "$PROJECT" --format="value(billingEnabled,billingAccountName)" \
  || echo "!! No se pudo consultar (¿gcloud auth login? ¿permiso billing.viewer?)"

echo; echo "== 2) Funciones desplegadas (compáralas con la lista esperada)"
firebase functions:list --project "$PROJECT" || echo "!! No se pudo listar"
echo "Esperadas (32): placeBid closeEndedAuctions onLotCreated createDeposit requestDepositRefund"
echo "  expireUnpaidWins mpWebhook chooseWinnerPaymentMethod openpayWebhook submitFeedback updateFeedback"
echo "  onPublicProfileInputs onSaleRecorded openDispute adminResolveDispute confirmReceipt"
echo "  releaseDuePayoutsJob confirmDeliveryCode chooseDelivery setReservePrice respondSecondChance"
echo "  lotPreview submitIdentityVerification adminReviewVerification adminSetBan adminMarkPayoutSent"
echo "  adminRetryWinnerPayment adminCancelLot adminRecalculatePayout adminSetStorePlan"
echo "  generateLotDescription onNotificationCreated"

echo; echo "== 3) Índices compuestos de Firestore (debe existir lots: status ASC + end_time ASC, en estado READY)"
gcloud firestore indexes composite list --project "$PROJECT" \
  --format="table(name.basename(),collectionGroup,fields.list(),state)" \
  || firebase firestore:indexes --project "$PROJECT"

echo; echo "== 4) Reglas publicadas de Firestore (se descargan a /tmp para comparar)"
TOKEN="$(gcloud auth print-access-token 2>/dev/null)"
if [ -n "$TOKEN" ]; then
  REL=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://firebaserules.googleapis.com/v1/projects/$PROJECT/releases/cloud.firestore")
  RULESET=$(echo "$REL" | sed -n 's/.*"rulesetName": *"\([^"]*\)".*/\1/p')
  if [ -n "$RULESET" ]; then
    curl -s -H "Authorization: Bearer $TOKEN" "https://firebaserules.googleapis.com/v1/$RULESET" \
      | python3 -c "import json,sys; print(json.load(sys.stdin)['source']['files'][0]['content'])" \
      > /tmp/firestore.rules.publicadas
    if diff -q /tmp/firestore.rules.publicadas firestore.rules >/dev/null; then
      echo "OK: las reglas publicadas son IGUALES a firestore.rules local."
    else
      echo "!! DIFERENTES. Revisa: diff /tmp/firestore.rules.publicadas firestore.rules"
    fi
  else
    echo "!! No se encontró release de reglas: $REL"
  fi
else
  echo "!! Sin token de gcloud; omitiendo comparación de reglas."
fi

echo; echo "== 5) Variables de configuración que deben existir en functions/.env (no se muestran valores)"
for v in MP_ACCESS_TOKEN MP_WEBHOOK_SECRET WEBHOOK_URL SITE_URL ANTHROPIC_API_KEY OPENPAY_MERCHANT_ID OPENPAY_PRIVATE_KEY OPENPAY_WEBHOOK_USER OPENPAY_WEBHOOK_PASS; do
  if grep -q "^$v=" functions/.env 2>/dev/null; then echo "  $v: presente"; else echo "  $v: FALTA"; fi
done
for v in DEPOSIT_AMOUNT WINNER_PAYMENT_WINDOW_HOURS VERIFIED_BID_THRESHOLD PAYOUT_RELEASE_DAYS COMMISSION_TIERS COMMISSION_PCT COMMISSION_MIN COMMISSION_PROMO ZERO_COMMISSION_FEE_PAYER OPENPAY_SANDBOX AI_MODEL AI_DAILY_LIMIT AI_GLOBAL_DAILY_LIMIT APP_CHECK_MODE SEO_NOINDEX; do
  if grep -q "^$v=" functions/.env 2>/dev/null; then echo "  $v=$(grep "^$v=" functions/.env | cut -d= -f2-)"; else echo "  $v: (default)"; fi
done
echo; echo "== 6) Validación local de la configuración de comisiones e IA (sin red)"
(cd functions && set -a && [ -f .env ] && . ./.env; set +a; node -e '
  const p = require("./payments"); const a = require("./ai");
  const ce = p.getCommissionConfigError(); console.log(ce ? "!! Comisiones: " + ce : "OK: comisiones válidas");
  try { a.readAiConfig(); console.log("OK: configuración de IA válida"); } catch (e) { console.log("!! IA: " + e.message); }
  const cp = require("./commission_policy"); const pr = cp.readPromo(); console.log(pr.error ? "!! " + pr.error : "OK: COMMISSION_PROMO " + (pr.promo ? "activa por fechas" : "sin campaña"));
  const fp = cp.readFeePayer(); console.log(fp.error ? "!! " + fp.error : "OK: costo del procesador con 0 % lo paga " + fp.payer);
  const rd = p.readReleaseDays(); console.log(rd.error ? "!! " + rd.error : "OK: liberación automática a " + rd.days + " días");
  const ac = require("./appcheck").appCheckMode(); console.log(ac.error ? "!! " + ac.error : "OK: App Check en modo " + ac.mode);
  try { require("./openpay").readOpenpayConfig(); console.log("OK: Openpay configurado"); } catch (e) { console.log("-- Openpay: " + e.message + " (si no usas SPEI, es normal)"); }
' 2>/dev/null) || echo "!! No se pudo validar (¿npm install en functions/?)"
