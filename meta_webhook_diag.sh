#!/usr/bin/env bash
# Diagnostico de entrega de webhooks de Meta (Instagram / Facebook / WhatsApp).
# Recorre en orden toda la cadena de configuracion y se detiene en el primer
# punto donde encuentra la causa de que no lleguen los mensajes.

# ------------------------- Configuracion -------------------------
PLATFORM="ig"                          # ig | fb | wa

PAGE_ID=""              # ig/fb: id de la pagina de Facebook
IG_ID=""         # ig: id de la cuenta profesional (vacio = no se valida)

PHONE_NUMBER_ID=""                     # wa: id del numero
WABA_ID=""                             # wa: id de la cuenta de WhatsApp Business

APP_ID=""
APP_SECRET=""
ACCESS_TOKEN=""

API="https://graph.facebook.com/v23.0"
# -----------------------------------------------------------------

APP_TOKEN="${APP_ID}|${APP_SECRET}"
STEP=0

log() { printf '\n\033[1;34m[%s]\033[0m %s\n' "$((++STEP))" "$1"; }
ok() { printf '  \033[0;32mOK\033[0m  %s\n' "$1"; }
info() { printf '      %s\n' "$1"; }

fail() {
    printf '\n\033[1;31m=========== CAUSA ENCONTRADA ===========\033[0m\n'
    printf '\033[1;31m%s\033[0m\n' "$1"
    [ -n "$2" ] && printf '\nComo se arregla:\n%s\n' "$2"
    printf '\n'
    exit 1
}

# Imprime el body de un GET a la Graph API.
api_get() {
    curl -g -s "${API}/$1"
}

# Devuelve el codigo de error de una respuesta, o vacio si no hubo error.
err_code() {
    printf '%s' "$1" | jq -r '.error.code // empty'
}

err_msg() {
    printf '%s' "$1" | jq -r '.error.message // empty'
}

# Aborta si la respuesta trae error de la Graph API.
check_error() {
    local body="$1" ctx="$2"
    local code
    code=$(err_code "$body")
    [ -z "$code" ] && return 0
    fail "$ctx fallo con error $code: $(err_msg "$body")" \
         "Revisa el token y los permisos antes de seguir con el resto del diagnostico."
}

command -v jq >/dev/null || { echo "Falta jq. Instalalo con: sudo apt install jq"; exit 1; }
[ -n "$ACCESS_TOKEN" ] || { echo "Falta ACCESS_TOKEN en la configuracion."; exit 1; }
[ -n "$APP_SECRET" ] || { echo "Falta APP_SECRET en la configuracion."; exit 1; }

printf '\033[1;37m== Diagnostico de webhooks de Meta (%s) ==\033[0m\n' "$PLATFORM"

# ---------------------------------------------------------------- 1
log "Probando el token de acceso"
TOKEN_INFO=$(api_get "debug_token?input_token=${ACCESS_TOKEN}&access_token=${APP_TOKEN}")
check_error "$TOKEN_INFO" "debug_token"

TOKEN_TYPE=$(printf '%s' "$TOKEN_INFO" | jq -r '.data.type')
TOKEN_APP=$(printf '%s' "$TOKEN_INFO" | jq -r '.data.app_id')
TOKEN_VALID=$(printf '%s' "$TOKEN_INFO" | jq -r '.data.is_valid')
TOKEN_PROFILE=$(printf '%s' "$TOKEN_INFO" | jq -r '.data.profile_id // empty')
TOKEN_EXPIRES=$(printf '%s' "$TOKEN_INFO" | jq -r '.data.expires_at')
TOKEN_SCOPES=$(printf '%s' "$TOKEN_INFO" | jq -r '.data.scopes | join(",")')

info "tipo=${TOKEN_TYPE} app=${TOKEN_APP} valido=${TOKEN_VALID} expira=${TOKEN_EXPIRES}"

[ "$TOKEN_VALID" = "true" ] || fail "El token no es valido." "Genera un token nuevo."

[ "$TOKEN_APP" = "$APP_ID" ] || fail \
    "El token pertenece a la app ${TOKEN_APP}, pero configuraste APP_ID=${APP_ID}." \
    "Corrige APP_ID/APP_SECRET, o usa el token que corresponde a esa app."

if [ "$PLATFORM" != "wa" ]; then
    [ "$TOKEN_TYPE" = "PAGE" ] || fail \
        "El token es de tipo ${TOKEN_TYPE}; para IG/FB se necesita un Page Access Token." \
        "Saca el token de pagina con: GET /me/accounts?fields=id,name,access_token"

    [ "$TOKEN_PROFILE" = "$PAGE_ID" ] || fail \
        "El token es de la pagina ${TOKEN_PROFILE}, pero configuraste PAGE_ID=${PAGE_ID}." \
        "Estas diagnosticando una pagina distinta de la que el token controla."
fi

[ "$TOKEN_EXPIRES" = "0" ] && ok "El token no expira" || info "El token tiene fecha de expiracion"
ok "Token valido y correspondiente a la app y la pagina configuradas"

# ---------------------------------------------------------------- 2
log "Probando los permisos del token"
case "$PLATFORM" in
    ig) NEEDED="instagram_basic instagram_manage_messages pages_messaging pages_manage_metadata" ;;
    fb) NEEDED="pages_messaging pages_manage_metadata pages_read_engagement" ;;
    wa) NEEDED="whatsapp_business_messaging whatsapp_business_management" ;;
esac

MISSING=""
for scope in $NEEDED; do
    printf '%s' ",${TOKEN_SCOPES}," | grep -q ",${scope}," || MISSING="${MISSING} ${scope}"
done

[ -z "$MISSING" ] || fail \
    "Al token le faltan permisos:${MISSING}" \
    "Vuelve a generar el token pidiendo esos scopes en el flujo de autorizacion."
ok "Estan todos los permisos necesarios"

# ---------------------------------------------------------------- 3
log "Probando el estado de la app"
APP_INFO=$(api_get "${APP_ID}?fields=name&access_token=${APP_TOKEN}")
check_error "$APP_INFO" "Consulta de la app"
info "app=$(printf '%s' "$APP_INFO" | jq -r '.name')"
ok "La app responde"

# ---------------------------------------------------------------- 4
log "Probando la suscripcion de la app al webhook"
SUBS=$(api_get "${APP_ID}/subscriptions?access_token=${APP_TOKEN}")
check_error "$SUBS" "Suscripciones de la app"

case "$PLATFORM" in
    ig) TOPIC="instagram" ;;
    fb) TOPIC="page" ;;
    wa) TOPIC="whatsapp_business_account" ;;
esac

TOPIC_DATA=$(printf '%s' "$SUBS" | jq -r --arg t "$TOPIC" '.data[] | select(.object == $t)')
[ -n "$TOPIC_DATA" ] || fail \
    "La app no tiene ninguna suscripcion al topic '${TOPIC}'." \
    "Dashboard de la app -> Webhooks -> suscribe '${TOPIC}' al campo 'messages'."

TOPIC_ACTIVE=$(printf '%s' "$TOPIC_DATA" | jq -r '.active')
TOPIC_FIELDS=$(printf '%s' "$TOPIC_DATA" | jq -r '[.fields[].name] | join(",")')
TOPIC_URL=$(printf '%s' "$TOPIC_DATA" | jq -r '.callback_url')

info "topic=${TOPIC} activo=${TOPIC_ACTIVE}"
info "callback=${TOPIC_URL}"
info "campos=${TOPIC_FIELDS}"

[ "$TOPIC_ACTIVE" = "true" ] || fail \
    "La suscripcion al topic '${TOPIC}' esta desactivada." \
    "Meta la desactiva tras fallos repetidos del endpoint. Reactivala en el dashboard."

printf '%s' ",${TOPIC_FIELDS}," | grep -q ",messages," || fail \
    "El topic '${TOPIC}' esta suscrito pero no incluye el campo 'messages'." \
    "Agrega el campo 'messages' a la suscripcion en el dashboard."
ok "La app esta suscrita a ${TOPIC}/messages y esta activa"

# ---------------------------------------------------------------- WhatsApp
if [ "$PLATFORM" = "wa" ]; then
    log "Probando la suscripcion de la WABA"
    [ -n "$WABA_ID" ] || fail "Falta WABA_ID en la configuracion." "Completa WABA_ID y vuelve a correr."

    WABA_SUBS=$(api_get "${WABA_ID}/subscribed_apps?access_token=${ACCESS_TOKEN}")
    check_error "$WABA_SUBS" "subscribed_apps de la WABA"

    WABA_APP=$(printf '%s' "$WABA_SUBS" | jq -r --arg a "$APP_ID" \
        '.data[] | select(.whatsapp_business_api_data.id == $a) | .whatsapp_business_api_data.id')
    [ -n "$WABA_APP" ] || fail \
        "La WABA ${WABA_ID} no esta suscrita a la app ${APP_ID}." \
        "Suscribela con: curl -X POST \"${API}/${WABA_ID}/subscribed_apps?access_token=\$TOKEN\""
    ok "La WABA esta suscrita a la app"

    if [ -n "$PHONE_NUMBER_ID" ]; then
        log "Probando el numero"
        PHONE=$(api_get "${PHONE_NUMBER_ID}?fields=verified_name,quality_rating,platform_type&access_token=${ACCESS_TOKEN}")
        check_error "$PHONE" "Consulta del numero"
        info "numero=$(printf '%s' "$PHONE" | jq -r '.verified_name') calidad=$(printf '%s' "$PHONE" | jq -r '.quality_rating')"
        ok "El numero responde"
    fi

    printf '\n\033[1;33m== Sin causa encontrada en la configuracion ==\033[0m\n'
    printf 'Todo lo verificable por API esta correcto. Revisa los logs de tu endpoint.\n\n'
    exit 0
fi

# ---------------------------------------------------------------- 5
log "Probando que la pagina corresponda a lo configurado"
PAGE=$(api_get "me?fields=id,name,instagram_business_account{id,username}&access_token=${ACCESS_TOKEN}")
check_error "$PAGE" "Consulta de la pagina"

PAGE_REAL=$(printf '%s' "$PAGE" | jq -r '.id')
PAGE_NAME=$(printf '%s' "$PAGE" | jq -r '.name')
info "pagina=${PAGE_NAME} (${PAGE_REAL})"

[ "$PAGE_REAL" = "$PAGE_ID" ] || fail \
    "El token resuelve a la pagina ${PAGE_REAL}, pero configuraste PAGE_ID=${PAGE_ID}." \
    "Estas mirando una pagina distinta de la que falla."
ok "La pagina coincide con la configurada"

# ---------------------------------------------------------------- 6
if [ "$PLATFORM" = "ig" ]; then
    log "Probando el vinculo con la cuenta de Instagram"
    IG_REAL=$(printf '%s' "$PAGE" | jq -r '.instagram_business_account.id // empty')
    IG_NAME=$(printf '%s' "$PAGE" | jq -r '.instagram_business_account.username // empty')

    [ -n "$IG_REAL" ] || fail \
        "La pagina ${PAGE_NAME} no tiene ninguna cuenta de Instagram profesional vinculada." \
        "Vincula la cuenta de IG a la pagina, y que sea de tipo profesional."

    info "instagram=@${IG_NAME} (${IG_REAL})"

    if [ -n "$IG_ID" ] && [ "$IG_REAL" != "$IG_ID" ]; then
        fail "La pagina tiene vinculada la cuenta IG ${IG_REAL}, pero configuraste IG_ID=${IG_ID}." \
             "Corrige IG_ID, o revisa si revincularon otra cuenta de Instagram a esta pagina."
    fi
    ok "La cuenta de Instagram vinculada coincide con la configurada"
fi

# ---------------------------------------------------------------- 7
log "Probando la suscripcion de la pagina a la app"
PAGE_SUBS=$(api_get "${PAGE_ID}/subscribed_apps?access_token=${ACCESS_TOKEN}")
check_error "$PAGE_SUBS" "subscribed_apps de la pagina"

APP_SUB=$(printf '%s' "$PAGE_SUBS" | jq -r --arg a "$APP_ID" '.data[] | select(.id == $a)')
[ -n "$APP_SUB" ] || fail \
    "La pagina ${PAGE_ID} no esta suscrita a la app ${APP_ID}." \
    "Suscribela con:
  curl -g -s -X POST \"${API}/${PAGE_ID}/subscribed_apps?subscribed_fields=messages&access_token=\$TOKEN\""

SUB_FIELDS=$(printf '%s' "$APP_SUB" | jq -r '[.subscribed_fields[]] | join(",")')
info "campos=${SUB_FIELDS}"

printf '%s' ",${SUB_FIELDS}," | grep -q ",messages," || fail \
    "La pagina esta suscrita a la app pero sin el campo 'messages'." \
    "Re-suscribe con subscribed_fields=messages."
ok "La pagina esta suscrita a la app con el campo messages"

# ---------------------------------------------------------------- 8
log "Probando el acceso a los mensajes"
PLAT_PARAM=""
[ "$PLATFORM" = "ig" ] && PLAT_PARAM="platform=instagram&"
CONV=$(api_get "${PAGE_ID}/conversations?${PLAT_PARAM}fields=participants,updated_time&limit=5&access_token=${ACCESS_TOKEN}")

CONV_ERR=$(err_code "$CONV")
if [ "$CONV_ERR" = "200" ]; then
    fail "El dueno de la cuenta desactivo el acceso a los mensajes para herramientas conectadas.
Respuesta de Meta: $(err_msg "$CONV")" \
         "En la app de Instagram, con la cuenta @${IG_NAME}:
  Configuracion -> Mensajes y respuestas de historias -> Herramientas conectadas
  -> activar 'Permitir acceso a mensajes'"
fi
check_error "$CONV" "Consulta de conversaciones"

CONV_COUNT=$(printf '%s' "$CONV" | jq -r '.data | length')
info "conversaciones=${CONV_COUNT}"
[ "$CONV_COUNT" -gt 0 ] || fail \
    "No hay ninguna conversacion en esta cuenta." \
    "Manda un mensaje de prueba a la cuenta y vuelve a correr el script."

LAST_UPDATE=$(printf '%s' "$CONV" | jq -r '.data[0].updated_time')
info "ultima actividad=${LAST_UPDATE}"
ok "Se pueden leer los mensajes (el acceso de herramientas conectadas esta activo)"

# ---------------------------------------------------------------- 9
log "Probando el estado de Conversation Routing"
FEAT=$(api_get "me?fields=messaging_feature_status&access_token=${ACCESS_TOKEN}")
check_error "$FEAT" "messaging_feature_status"

HOP=$(printf '%s' "$FEAT" | jq -r '.messaging_feature_status.hop_v2')
MSGR_MULTI=$(printf '%s' "$FEAT" | jq -r '.messaging_feature_status.msgr_multi_app')
IG_MULTI=$(printf '%s' "$FEAT" | jq -r '.messaging_feature_status.ig_multi_app')
info "hop_v2=${HOP} msgr_multi_app=${MSGR_MULTI} ig_multi_app=${IG_MULTI}"

if [ "$PLATFORM" = "ig" ] && [ "$IG_MULTI" = "true" ]; then
    info "Conversation Routing ACTIVO: solo la app por defecto recibe los mensajes"
else
    info "Conversation Routing inactivo: todas las apps conectadas deberian recibir"
fi
ok "Estado de routing consultado"

# ---------------------------------------------------------------- 10
log "Probando quien controla el hilo"
OWNER_ID=$(printf '%s' "$CONV" | jq -r --arg ig "$IG_REAL" \
    '[.data[].participants.data[] | select(.id != $ig) | .id] | first // empty')

if [ -z "$OWNER_ID" ]; then
    info "No se pudo obtener un id de participante; se omite esta prueba"
else
    info "participante=${OWNER_ID}"
    OWNER=$(api_get "${PAGE_ID}/thread_owner?recipient=${OWNER_ID}&access_token=${ACCESS_TOKEN}")
    OWNER_APP=$(printf '%s' "$OWNER" | jq -r '.data[0].thread_owner.app_id // empty')

    if [ -z "$OWNER_APP" ]; then
        info "Sin dueno de hilo (idle, o tu app no es la receptora principal)"
        if [ "$IG_MULTI" = "true" ]; then
            fail "Conversation Routing esta activo y tu app no es la aplicacion por defecto.
Los mensajes se quedan en el Inbox de Instagram y no salen hacia tu webhook." \
                 "Pagina de Facebook -> Configuracion -> Page Setup -> Instagram Conversation Routing
  -> asignar la app ${APP_ID} como aplicacion por defecto."
        fi
    elif [ "$OWNER_APP" = "$APP_ID" ]; then
        ok "Tu app controla el hilo"
    else
        OWNER_NAME="otra app"
        [ "$OWNER_APP" = "1217981644879628" ] && OWNER_NAME="el Inbox de Instagram"
        [ "$OWNER_APP" = "263902037430900" ] && OWNER_NAME="el Inbox de la Pagina"
        fail "El hilo lo controla ${OWNER_NAME} (app ${OWNER_APP}), no la tuya (${APP_ID}).
Por eso los mensajes no llegan a tu webhook." \
             "Pasa el control a tu app:
  curl -g -s -X POST \"${API}/${PAGE_ID}/pass_thread_control?recipient=${OWNER_ID}&target_app_id=${APP_ID}&access_token=\$TOKEN\""
    fi
fi

# ---------------------------------------------------------------- Final
printf '\n\033[1;33m=========== SIN CAUSA EN LA CONFIGURACION ===========\033[0m\n'
cat <<EOF
Todo lo verificable por API esta correcto:
  - token valido, de la app y pagina configuradas, con los permisos necesarios
  - app suscrita a ${TOPIC}/messages y activa
  - pagina suscrita a la app con el campo messages
  - cuenta de Instagram vinculada y con acceso a mensajes activo
  - routing sin bloqueos

Si aun asi no llegan los mensajes, el problema no esta en la configuracion.
Siguientes pasos:
  1. Webhook Debugger del dashboard (menu Instagram Messaging): muestra si Meta
     intento entregar y con que resultado.
  2. Logs de tu endpoint: ${TOPIC_URL}
  3. Si Meta no registra intentos, es caso para Direct Support con estos ids:
       app=${APP_ID} pagina=${PAGE_ID} instagram=${IG_REAL}
EOF
printf '\n'
