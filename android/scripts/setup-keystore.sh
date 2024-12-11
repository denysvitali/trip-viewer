#!/bin/bash

KEYSTORE=${1:-"upload.jks"}
PROPS_FILE=${2:-"key.properties"}

echo "storePassword=$STORE_PASSWORD" > "$PROPS_FILE"
echo "keyPassword=$KEY_PASSWORD" >> "$PROPS_FILE"
echo "keyAlias=upload" >> "$PROPS_FILE"
echo "storeFile=../$KEYSTORE" >> "$PROPS_FILE"