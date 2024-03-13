#!/bin/bash

# if [[ $(id -u) -ne 0 ]] ; then
#     echo -e "Must run as \e[5;31;1mroot\e[0m!"
#     exit 1
# fi

exec 5>&1

error='Error: failed computing upgrade: Failed solving solution for upgrade: Could not compute upgrade - couldn'\''t uninstall candidates : could not satisfy the constraints:'
#   ERROR    Error: failed computing upgrade: Failed solving solution for upgrade: Could not compute upgrade - couldn't uninstall candidates : could not satisfy the constraints:
#           android-tools-apps-34.0.1 and
#           qdevicemonitor-apps-1.0.1-r2+2 and
#           !(qdevicemonitor-apps-1.0.1-r2+2) or android-tools-apps-34.0.0+4 and
#           !(android-tools-apps-34.0.0+4) or !(android-tools-apps-34.0.0+4) or !(android-tools-apps-34.0.1)

package_match='[^a-zA-Z0-9-]*([a-zA-Z0-9-]+)\-(libs|apps|layers|fonts)\-.*'

up=true

while [ "$up" = true ] ; do
  packages=
  found=false

  readarray -t RESULT < <(luet repo update && luet upgrade -y | tee >(cat - >&5))

  for line in "${RESULT[@]}" ; do
    if [[ "$line" == *"$error"* ]] ; then
      found=true
    fi

    if [ "$found" = true ] ; then
      echo "$line"

      items=("$line")

      for item in "${items[@]}" ; do
        if [[ $item =~ $package_match ]] ; then
          package="${BASH_REMATCH[2]}"/"${BASH_REMATCH[1]}"

          if [[ "$packages" != *"$package"* ]] ; then
            packages="$packages $package"
          fi
        fi
      done
    fi
  done

  if [[ -z "$packages" ]] ; then
    up=false
    echo "\033[32;5mDone!\033[0m"
  else
    echo "Reinstall: $packages"
    $(luet reinstall -y ${packages} | tee >(cat - >&5))
  fi
done
