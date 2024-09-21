#!/bin/bash

# if [[ $(id -u) -ne 0 ]] ; then
#     echo -e "Must run as \e[5;31;1mroot\e[0m!"
#     exit 1
# fi

# set -x

exec 5>&1

package_upgrade_match='[^a-zA-Z0-9_-]*([a-zA-Z0-9_-]+)\-(libs|apps|layers|fonts)\-.*'

error_upgrade='Error: failed computing upgrade: Failed solving solution for upgrade: Could not compute upgrade - couldn'\''t uninstall candidates : could not satisfy the constraints:'
#   ERROR    Error: failed computing upgrade: Failed solving solution for upgrade: Could not compute upgrade - couldn't uninstall candidates : could not satisfy the constraints:
#           android-tools-apps-34.0.1 and
#           qdevicemonitor-apps-1.0.1-r2+2 and
#           !(qdevicemonitor-apps-1.0.1-r2+2) or android-tools-apps-34.0.0+4 and
#           !(android-tools-apps-34.0.0+4) or !(android-tools-apps-34.0.0+4) or !(android-tools-apps-34.0.1)

package_reinstall_match='(libs|apps|layers|fonts)/([a-zA-Z0-9_-]+)'

error_reinstall="Error: Package ${package_reinstall_match}\->=0 not found in the system"
#  ERROR    Error: Package libs/opencv->=0 not found in the system

packages_not_found=()

up=true

while [ "$up" = true ] ; do
  packages=
  found_error_upgrade=false

  readarray -t RESULT < <(luet repo update && luet upgrade -y | tee >(cat - >&5))

  for line in "${RESULT[@]}" ; do
    if [[ "${line}" == *"${error_upgrade}"* ]] ; then
      found_error_upgrade=true
    fi

    if [ ${found_error_upgrade} = true ] ; then
      # echo "${line}"

      items=("${line}")

      for item in "${items[@]}" ; do
        if [[ ${item} =~ ${package_upgrade_match} ]] ; then
          package="${BASH_REMATCH[2]}/${BASH_REMATCH[1]}"
          value="\<${package}\>"
          
          if [[ ! ${packages_not_found[@]} =~ ${value} ]] ; then
            if [[ ! ${packages} =~ ${value} ]] ; then
              packages="${packages} ${package}"
            fi
          fi
        fi
      done
    fi
  done

  if [[ -z ${packages} ]] ; then
    up=false
    echo "\033[32;5mDone!\033[0m"
  else
    echo "Reinstall: $packages"
    readarray -t REINSTALL_RESULT < <(luet reinstall -y ${packages} | tee >(cat - >&5))
    
    for line in "${REINSTALL_RESULT[@]}" ; do
      # Collect all the packages that could not be reinstalled due to be missing from the repo
      # in order to avoid trying reinstalling them, a fact that would prevent the upgrade process
      # and run the same command in a loop.
      if [[ ${line} =~ ${error_reinstall} ]] ; then
        # echo "${line}"
        
        package="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"     
        
        value="\<${package}\>"
        
        if [[ ! ${packages_not_found[@]} =~ ${value} ]] ; then
          packages_not_found+=(${package})
        fi
      fi
    done
  fi
done
