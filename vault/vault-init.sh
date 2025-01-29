#! /bin/sh

set -e

export VAULT_ADDR=http://vault:8200

sleep 3

MOUNTED_DIR=/certs
# login with root token at $VAULT_ADDR
vault login root

vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki
vault write pki/root/generate/internal common_name=sample.mesh ttl=87600h issuer_name=root-2024
vault write pki/config/urls issuing_certificates="http://vault.example.com:8200/v1/pki/ca" crl_distribution_points="http://vault.example.com:8200/v1/pki/crl"

vault secrets enable -path=pki_int_east pki
vault secrets tune -max-lease-ttl=43800h pki_int_east
vault write pki_int_east/config/urls issuing_certificates="http://127.0.0.1:8200/v1/pki_int_east/ca" crl_distribution_points="http://127.0.0.1:8200/v1/pki_int_east/crl"
vault write pki_int_east/intermediate/generate/internal common_name="sample.mesh Intermediate Authority" ttl=43800h -format=json | jq -r '.data.csr' > pki_int_east.csr
vault write pki/root/sign-intermediate csr=@pki_int_east.csr format=pem ttl=43800h > signed_certificate.pem
vault write -format=json pki/root/sign-intermediate csr=@pki_int_east.csr ttl=43800h > signed.json
cat signed.json | jq -r '.data.certificate' > cluster-east-chain.pem
cat signed.json | jq -r '.data.issuing_ca' >> cluster-east-chain.pem

vault write pki_int_east/intermediate/set-signed certificate=@cluster-east-chain.pem

vault write pki_int_east/roles/cluster-east-issuer \
    allowed_domains=istio-ca \
    enforce_hostnames=false \
    allow_any_name=true \
    require_cn=false \
    allowed_uri_sans="spiffe://*" \
    allow_subdomains=true max_ttl=72h


vault secrets enable -path=pki_int_west pki
vault secrets tune -max-lease-ttl=43800h pki_int_west
vault write pki_int_west/config/urls issuing_certificates="http://127.0.0.1:8200/v1/pki_int_west/ca" crl_distribution_points="http://127.0.0.1:8200/v1/pki_int_west/crl"
vault write pki_int_west/intermediate/generate/internal common_name="sample.mesh Intermediate Authority" ttl=43800h -format=json | jq -r '.data.csr' > pki_int_west.csr
vault write pki/root/sign-intermediate csr=@pki_int_west.csr format=pem ttl=43800h > signed_certificate.pem
vault write -format=json pki/root/sign-intermediate csr=@pki_int_west.csr ttl=43800h > signed.json
cat signed.json | jq -r '.data.certificate' > cluster-west-chain.pem
cat signed.json | jq -r '.data.issuing_ca' >> cluster-west-chain.pem

vault write pki_int_west/intermediate/set-signed certificate=@cluster-west-chain.pem

vault write pki_int_west/roles/cluster-west-issuer \
    allowed_domains=istio-ca \
    enforce_hostnames=false \
    allow_any_name=true \
    allowed_uri_sans="spiffe://*" \
    require_cn=false \
    allow_subdomains=true max_ttl=72h
