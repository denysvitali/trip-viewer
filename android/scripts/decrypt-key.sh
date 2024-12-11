#!/bin/bash

KEYSTORE_IN=${1:-"signing.jks.enc"}
KEYSTORE_OUT=${2:-"signing.jks"}

if [ -z "$DECRYPTION_KEY" ]; then
  echo "DECRYPTION_KEY is not set" > /dev/stderr
  exit 1
fi

openssl enc -d -aes-256-cbc -in "$KEYSTORE_IN" -out "$KEYSTORE_OUT" -pbkdf2 -pass env:DECRYPTION_KEY