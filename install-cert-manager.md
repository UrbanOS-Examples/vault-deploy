## install the cert manager
```
helm install \
  jetstack/cert-manager \
  --name cert-manager \
  --namespace cert-manager \
  --version v1.0.3 \
  --set installCRDs=true
```

## add a secret to cert-manager
Reference: https://cert-manager.io/docs/configuration/ca/

This is not perfect, as these secrets need to be locked down by RBAC, ideally, but the other CA options are also pretty janky

On Mac add this to your `/etc/ssl/openssl.cnf
```
[ v3_ca ]
basicConstraints = critical,CA:TRUE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
```
Then generate your key and crt and put them in a secret
```
openssl genrsa -out ca.key 2048
openssl req -x509 -new -key ca.key -out ca.crt -extensions v3_ca

k create secret tls ca-key-pair \
  --cert=ca.crt \
  --key=ca.key \
  --namespace=cert-manager
```

## install a cluster-wide issuer that references that cert
```
k apply -f cluster-issuer.yaml
```

## install a cert (this would be part of an apps deploy chart)
```
k apply -f vault-cert.yaml
```

## reference that cert in the deploy for the app in question
```yaml
...
        volumeMounts:
        - mountPath: /etc/tls/vault-pem
          name: vault-pem
...
      volumes:
      - name: vault-pem
        secret:
          secretName: vault-pem
...
```

## the application can then use those for:
- its CA cert chain verification of other services via /etc/tls/vault-pem/ca.crt (will likely have to bundle this with the main bundles we already have for internet traffic)
- its own key and cert for TLS, which will then be CA cert checkable by other services that have the ca.crt via /etc/tls/vault-pem/tls.crt and /etc/tls/vault-pem/tls.key