#!/bin/bash

for i in *.zip; do [[ -f "$i" ]] && [[ $(unzip -l "$i" | tail -1 | awk '{ print $2 }') -ne 2 ]] && echo "$i" ; done
