#!/bin/bash

# if [[ $(id -u) -ne 0 ]] ; then
#     echo -e "Must run as \e[5;31;1mroot\e[0m!"
#     exit 1
# fi

set -x

exec 5>&1


error1='Error: failed computing upgrade: Failed solving solution for upgrade: Could not compute upgrade - couldn'\''t uninstall candidates : could not satisfy the constraints:'
#   ERROR    Error: failed computing upgrade: Failed solving solution for upgrade: Could not compute upgrade - couldn't uninstall candidates : could not satisfy the constraints:
#           android-tools-apps-34.0.1 and
#           qdevicemonitor-apps-1.0.1-r2+2 and
#           !(qdevicemonitor-apps-1.0.1-r2+2) or android-tools-apps-34.0.0+4 and
#           !(android-tools-apps-34.0.0+4) or !(android-tools-apps-34.0.0+4) or !(android-tools-apps-34.0.1)

error2='Error: failed computing upgrade: Failed solving solution for upgrade: could not satisfy the constraints:'
#   ERROR    Error: failed computing upgrade: Failed solving solution for upgrade: could not satisfy the constraints:
#           kwave-apps-24.05.2 and
#           kde-kf5-layers-5.116.0+3 and
#           !(kwave-apps-24.05.2) or kde-kf5-layers- and
#           !(kde-kf5-layers-) or !(kde-kf5-layers-) or !(kde-kf5-layers-5.116.0+3)


package_match='[^a-zA-Z0-9_-]*([a-zA-Z0-9_-]+)\-(libs|apps|layers|fonts)\-.*'

up=true

removed_packages=

while [ "$up" = true ] ; do
  install_packages=
  reinstall_packages=
  found=false

  readarray -t RESULT < <(luet repo update && luet upgrade -y | tee >(cat - >&5))

#   ln=0
  for line in "${RESULT[@]}" ; do
#     ((ln++))
    if [[ "$line" == *"$error1"* || "$line" == *"$error2"* ]] ; then
      found=true
    fi

    if [ "$found" = true ] ; then
#       echo "${ln}: ${line}"

      items=("$line")

      for item in "${items[@]}" ; do
        if [[ $item =~ $package_match ]] ; then
          package="${BASH_REMATCH[2]}"/"${BASH_REMATCH[1]}"

          if [[ "$reinstall_packages" != *"$package"* ]] ; then
            if [[ $(luet search $package --installed) ]] ; then
              reinstall_packages="$reinstall_packages $package"

              if [[ "$removed_packages" != *"$package"* ]] ; then
                removed_packages="$removed_packages $package"
              fi
            else
              if [[ "$install_packages" != *"$package"* ]] ; then
                install_packages="$install_packages $package"
              fi
            fi
          fi
        fi
      done
    fi
  done

  if [[ -z "$install_packages" ]] ; then
    if [[ -z "$reinstall_packages" ]] ; then
      up=false
    else
      echo "Reinstall: $reinstall_packages"
      $(luet reinstall -y ${reinstall_packages} | tee >(cat - >&5) | tail -1)
    fi
  else
    echo "Uninstall: $reinstall_packages"
    $(luet uninstall -y --force ${reinstall_packages} | tee >(cat - >&5) | tail -1)
  fi

done

if [[ ! -z "$removed_packages" ]] ; then
  echo "Innstall removed packages: $removed_packages"
  $(luet install -y ${removed_packages} | tee >(cat - >&5) | tail -1)
fi

echo "\033[32;5mDone!\033[0m"
