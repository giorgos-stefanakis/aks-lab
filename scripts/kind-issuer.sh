#!/usr/bin/env bash
# Creates the service-account key pair for the kind cluster and the two public OIDC documents
# that Entra reads to verify its tokens. Output goes to .local/oidc/. Rerun is safe: an existing key is kept.
#
# Usage: LAB_ISSUER_URL=https://<account>.blob.core.windows.net/oidc scripts/kind-issuer.sh
set -euo pipefail
umask 077

issuer="${LAB_ISSUER_URL:?Set LAB_ISSUER_URL in .lab.env (output issuerUrl of the kind stack)}"
issuer="${issuer%/}"
out="$(cd "$(dirname "$0")/.." && pwd)/.local/oidc"
mkdir -p "$out/.well-known" "$out/openid/v1"

if [[ ! -f "$out/sa.key" ]]; then
  openssl genrsa -out "$out/sa.key" 2048 2>/dev/null
fi
chmod 0600 "$out/sa.key"
openssl rsa -in "$out/sa.key" -pubout -out "$out/sa.pub" 2>/dev/null

python3 -I - "$out" "$issuer" <<'PY'
import base64, hashlib, json, subprocess, sys

out, issuer = sys.argv[1], sys.argv[2]


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def openssl(*args: str) -> bytes:
    return subprocess.run(["openssl", *args], check=True, capture_output=True).stdout


modulus = bytes.fromhex(openssl("rsa", "-pubin", "-in", f"{out}/sa.pub", "-modulus", "-noout").decode().split("=")[1].strip())
der = openssl("rsa", "-pubin", "-in", f"{out}/sa.pub", "-pubout", "-outform", "DER")
# Same key ID the API server derives: SHA-256 of the DER public key.
kid = b64(hashlib.sha256(der).digest())
jwks = {"keys": [{"kty": "RSA", "alg": "RS256", "use": "sig", "kid": kid, "n": b64(modulus), "e": "AQAB"}]}
discovery = {
    "issuer": issuer,
    "jwks_uri": f"{issuer}/openid/v1/jwks",
    "response_types_supported": ["id_token"],
    "subject_types_supported": ["public"],
    "id_token_signing_alg_values_supported": ["RS256"],
}
for path, doc in ((".well-known/openid-configuration", discovery), ("openid/v1/jwks", jwks)):
    with open(f"{out}/{path}", "w") as f:
        json.dump(doc, f, indent=2)
PY

echo "Wrote $out. Upload .well-known/openid-configuration and openid/v1/jwks to the oidc container (docs/RUNBOOK.md, M4)."
