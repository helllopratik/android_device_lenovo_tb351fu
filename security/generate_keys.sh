#!/bin/bash
# Generate private release keys for TB351FU build
# This makes the build signed with private keys, satisfying the Trust interface checks.

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "Generating private keys for TB351FU..."

for key in releasekey testkey platform shared media networkstack sdk_sandbox bluetooth nfc cts_uicc_2021; do
    if [ ! -f "${key}.pk8" ] || [ ! -f "${key}.x509.pem" ]; then
        echo "Generating ${key}..."
        openssl genrsa -f4 -out "${key}.pem" 2048
        openssl req -new -x509 -sha256 -key "${key}.pem" -out "${key}.x509.pem" -subj "/CN=TB351FU/O=LineageOS/OU=tb351fu/" -days 10000
        openssl pkcs8 -in "${key}.pem" -topk8 -outform DER -out "${key}.pk8" -nocrypt
        rm -f "${key}.pem"
    else
        echo "${key} already exists, skipping."
    fi
done

echo "Keys generated successfully in $DIR!"
chmod 600 *.pk8 *.x509.pem
