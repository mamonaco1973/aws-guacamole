#!/bin/bash
# ==============================================================================
# validate.sh - Guacamole + Active Directory: deployment check
# ------------------------------------------------------------------------------
#   - Waits for the ALB to report the Guacamole server healthy (its setup
#     takes a few minutes after Terraform finishes).
#   - Checks the HTTPS URL answers (self-signed certificate, so curl -k).
#   - Signs in to Guacamole's API as jsmith -- LDAPS to AD, the mcloud-users
#     group gate -- and checks both connections are granted.
#   - Prints the URL and a login. One line per check, then a summary.
# ==============================================================================
set -euo pipefail
cd "$(dirname "$0")"
export AWS_DEFAULT_REGION="us-east-1"

fail() { echo "FAILED"; echo "ERROR: $*" >&2; exit 1; }
step() { printf '%-58s' "$1..."; }
ok()   { echo "${1:-ok}"; }

URL="$(terraform -chdir=02-servers output -raw guacamole_url 2>/dev/null || true)"
GUAC_ID="$(terraform -chdir=02-servers output -raw guacamole_instance_id 2>/dev/null || true)"
[ -n "${URL}" ] || fail "No guacamole_url output. Run ./apply.sh first."

# ------------------------------------------------------------------------------
# ALB target health (Guacamole's user data: Docker, images, LDAPS trust)
# ------------------------------------------------------------------------------
step "Guacamole healthy behind the ALB (up to 15 min)"
TG_ARN="$(aws elbv2 describe-target-groups --names guacamole-tg \
  --query 'TargetGroups[0].TargetGroupArn' --output text)"
for ((i = 0; i < 90; i++)); do
  STATE="$(aws elbv2 describe-target-health --target-group-arn "${TG_ARN}" \
    --query 'TargetHealthDescriptions[0].TargetHealth.State' --output text)"
  [ "${STATE}" = "healthy" ] && break
  sleep 10
done
[ "${STATE}" = "healthy" ] || fail "Target is ${STATE}. Setup log: aws ssm start-session --target ${GUAC_ID}, then sudo cat /root/userdata.log"
ok

step "HTTPS answers at the ALB"
CODE="$(curl -sk --max-time 15 -o /dev/null -w '%{http_code}' "${URL}")"
[ "${CODE}" = "200" ] || fail "${URL} answered ${CODE}."
ok

# ------------------------------------------------------------------------------
# Sign in as an AD user and list the connections Guacamole grants
# ------------------------------------------------------------------------------
JSMITH="$(aws secretsmanager get-secret-value --secret-id jsmith_ad_credentials_efs \
  --query SecretString --output text | jq -r .password)"

step "Sign-in as jsmith (LDAPS to AD)"
TOKEN=""
for ((i = 0; i < 12; i++)); do
  TOKEN="$(curl -sk --max-time 15 -X POST "${URL}api/tokens" \
    --data-urlencode "username=jsmith" --data-urlencode "password=${JSMITH}" \
    | jq -r '.authToken // empty' 2>/dev/null || true)"
  [ -n "${TOKEN}" ] && break
  sleep 10
done
[ -n "${TOKEN}" ] || fail "jsmith could not sign in. Check LDAPS from the Guacamole server (docker compose logs guacamole)."
ok

step "Connections granted to mcloud-users"
CONNECTIONS="$(curl -sk --max-time 15 "${URL}api/session/data/postgresql/connections" \
  -H "Guacamole-Token: ${TOKEN}" | jq -r '[.[].name] | sort | join(", ")')"
[ "${CONNECTIONS}" = "Linux (SSH), Windows (RDP)" ] || fail "Expected both connections, got '${CONNECTIONS}'."
ok "${CONNECTIONS}"
curl -sk -o /dev/null -X DELETE "${URL}api/session" -H "Guacamole-Token: ${TOKEN}" || true

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
cat <<EOF

Guacamole + Active Directory
============================
URL      : ${URL}
           Self-signed certificate: the browser warns once;
           choose Advanced > Proceed.
Sign in  : jsmith / ${JSMITH}
           (any mcloud-users member; passwords in Secrets Manager
           as <user>_ad_credentials_efs)
Connect  : Windows (RDP) and Linux (SSH), as the signed-in user.
           Windows needs ~10 minutes after deploy to join the
           domain and reboot before RDP accepts domain logins.
EOF
