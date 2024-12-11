#!/bin/bash

KEYCHAIN_IN=${1:-"signing.jks"}
KEYCHAIN_OUT=${2:-"signing.jks.enc"}

if [ -z "$ENCRYPTION_KEY" ]; then
  echo "ENCRYPTION_KEY is not set" > /dev/stderr
  exit 1
fi

openssl enc -aes-256-cbc -in "$KEYCHAIN_IN" -out "$KEYCHAIN_OUT" -pbkdf2 -pass env:ENCRYPTION_KEY