#!/bin/bash

# disable globbing
set -f
# password length or 1st parameter
PWLEN="${1:-16}"
# password symbol set or 2nd parameter
PWSYM="${2:-'@/+=_~*'}"

# must start with alpha
FCHAR="$(cat /dev/urandom | tr -dc '[:alpha:]' | head -c1)"
# have a symbol
SCHAR="$(cat /dev/urandom | tr -dc \"${PWSYM}\" | head -c1)"
# upper, lower, digit, some symbols
RCHAR="$(cat /dev/urandom | tr -dc \"[:alnum:]${PWSYM}\" | head -c$((PWLEN - 2)))"
# wrap the symbol into the password
RPASS="$(echo "${SCHAR}${RCHAR}" | fold -c -w1 | shuf | tr -d '\n')"

echo "${FCHAR}${RPASS}"
