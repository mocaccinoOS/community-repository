#!/bin/bash

if [[ $(id -u) -ne 0 ]] ; then
    echo -e "Must run as \e[5;31;1mroot\e[0m!"
    exit 1
fi

# set -x

# Exit immediately if any command fails
set -e

# to keep the quotes use `jq -n`
# to skip the quotes use `jq -rn`

# oneliner
# jq -rn --argfile available <(luet search -o json | jq -r '[ .packages[] | { category: .category, name: .name } ] | sort') --argfile installed <(luet search --installed -o json | jq -r '[ .packages[] | { category: .category, name: .name } ] | sort') '$installed-$available | sort | .[] | .category + "/" + .name'

# split on multiple lines
jq -rn \
  --argfile available <(luet search -o json | jq -r '[ .packages[] | { category: .category, name: .name } ] | sort') \
  --argfile installed <(luet search --installed -o json | jq -r '[ .packages[] | { category: .category, name: .name } ] | sort') \
  '$installed-$available | sort | .[] | .category + "/" + .name'
