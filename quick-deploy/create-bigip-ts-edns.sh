#!/bin/bash

WORDS_FILE=./bigip-vs-edns/words
COUNT=100

# Read words once, filter once
mapfile -t WORDS < <(grep -v '!-' "$WORDS_FILE" | tail -50)

declare -a NAMES

# -------- Phase 0: generate names --------
for a in $(seq 1 $COUNT); do
  w1=${WORDS[RANDOM % ${#WORDS[@]}]}
  w2=${WORDS[RANDOM % ${#WORDS[@]}]}
  w3=${WORDS[RANDOM % ${#WORDS[@]}]}
  NAMES[$a]="$w1-$w2-$w3-$a"
done

# -------- Phase 1: create ALL TS --------
for a in $(seq 1 $COUNT); do
  name="${NAMES[$a]}"

  helm upgrade --install ts-$a ./ts \
    --set vs.fqdn=$name.app.com \
    --set vs.service=test-app-$a \
    --set vs.ipamlabel=prod \
    --set vs.name=$name
done

echo "✅ All TS created"
sleep 60

# -------- Phase 2: create ALL EDNS --------
for a in $(seq 1 $COUNT); do
  name="${NAMES[$a]}"

  helm upgrade --install edns-$a ./edns \
    --set vs.fqdn=$name.app.com \
    --set vs.service=test-app-$a \
    --set vs.ipamlabel=prod \
    --set vs.name=$name
done

echo "✅ All EDNS created"
