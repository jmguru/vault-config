#!/bin/bash

VAULT_UNSEAL_KEY=$(cat keys.json | jq -r ".unseal_keys_b64[]")
echo $VAULT_UNSEAL_KEY

VAULT_ROOT_KEY=$(cat keys.json | jq -r ".root_token")
echo $VAULT_ROOT_KEY

kubectl -n vault exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
