#!/bin/bash

ifs=$IFS
IFS=':'

# libdirs="/bin:/usr/bin:/lib:/lib64:/usr/lib:/usr/lib64" #"/:opt/bin:/opt/firefox/"
# libdirs="/usr/bin:/usr/lib:/usr/lib64"
libdirs="/usr/lib:/usr/lib64"
extras=

declare -A packages

# Check ELF binaries in the PATH and specified dir trees.
for tree in $PATH $libdirs $extras
do
    echo DIR $tree

    # Get list of files in tree
    files=$(find $tree -type f)
    IFS=$ifs
    for i in $files
    do
        if [ `file $i | grep -c 'ELF'` -ne 0 ]; then
            # Is an ELF binary.
            if [ `ldd $i 2>/dev/null | grep -c 'not found'` -ne 0 ]; then
                # Missing lib
                printed=0
                file_path="$(dirname "${i}")"
                ldd_files=($(ldd $i 2>/dev/null | awk '/ => not found/ { print $1 }'))
                for j in "${ldd_files[@]}"; do
                    found=0
                    dep_path="${file_path}"

                    while [[ found -eq 0 ]] && [[ ! "${dep_path}" = "/" ]]; do
                        if [ -e "${dep_path}/${j}" ]; then
                            found=1
                        fi
                        
                        dep_path="$(dirname "${dep_path}")"
                    done
                    
                    if [[ found -eq 0 ]] && [ -e "/${j}" ]; then
                        found=1
                    fi
                  
                    if [[ found -eq 0 ]]; then
                        if [[ $printed -eq 0 ]]; then
                            # file_name="$(basename "${i}")"
                            file_name=$(echo ${i} | sed -n -E 's/^\/(.*)/\1/p')
                            package=$(luet search --files $file_name | sed -n -E 's/^> (.*)\-[[:digit:].]+((_p|-r)+[[:digit:]]+){0,}(\+[[:digit:]]+){0,1}/\1/p' | sed ':a;N;$!ba;s/\n/ /g')
                            if [[ ! -v packages[$package] ]]; then
                                # This is an associative array, so map the vlaue (the package name) by just reading to an empty string.
                                # Not interested in the values associated with the keys.
                                packages[$package]=
                            fi

                            echo "$i: $package"
                            printed=1
                        fi
                        echo "    ${j} => not found"
                    fi
                done
            fi
        fi
    done
done

if [ ${#packages[@]} -ne 0 ]; then
    echo -e "\nThe following packages have missing deps:"
    for p in "${!packages[@]}"; do
        printf '> %s\n' "${p}"
    done
fi

exit 
