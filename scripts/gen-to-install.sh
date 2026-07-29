#!/bin/bash

if [[ $(id -u) -ne 0 ]] ; then
    echo -e "Must run as \e[5;31;1mroot\e[0m!"
    exit 1
fi

luet search -o json | jq -r '.packages[] | select( .category == "apps" and .installed == false ) | "luet install -y " + .category + "/" + .name' > to-install.sh
