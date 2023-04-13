#!/bin/bash

echo -e "\n\e\033[0;32;1mLooking for upgradable packages...\e[0m!\n"

if [[ $(id -u) -ne 0 ]] ; then
    echo -e "Must run as \e[5;31;1mroot\e[0m!"
    exit 1
fi

function levenshtein {
    if [ "$#" -ne "2" ]; then
        echo "Usage: $0 word1 word2" >&2
    elif [ "${#1}" -lt "${#2}" ]; then
        levenshtein "$2" "$1"
    else
        local str1len=$((${#1}))
        local str2len=$((${#2}))
        local d i j
        for i in $(seq 0 $(((str1len+1)*(str2len+1)))); do
            d[i]=0
        done
        for i in $(seq 0 $((str1len))); do
            d[$((i+0*str1len))]=$i
        done
        for j in $(seq 0 $((str2len))); do
            d[$((0+j*(str1len+1)))]=$j
        done

        for j in $(seq 1 $((str2len))); do
            for i in $(seq 1 $((str1len))); do
                [ "${1:i-1:1}" = "${2:j-1:1}" ] && local cost=0 || local cost=1
                local del=$((d[(i-1)+str1len*j]+1))
                local ins=$((d[i+str1len*(j-1)]+1))
                local alt=$((d[(i-1)+str1len*(j-1)]+cost))
                d[i+str1len*j]=$(echo -e "$del\n$ins\n$alt" | sort -n | head -1)
            done
        done
        echo ${d[str1len+str1len*(str2len)]}
    fi
}

function getCategoryPackageVersion() {

    declare -A CPV
    
    # /^
    # ([<>]?=?)                                   # version specifier
    # (([^\/]+)\/)?                               # category
    # ([^[:space:]]+)                             # package name
    # -                                           # separator
    # (
    #     ([[:digit:]]+)*                         # version, major 
    #     (\.([[:digit:]]+))*                     # version, minor
    #     ([a-z])?                                # version, letter
    #     (
    #         _                                   # separator
    #         (alpha|beta|pre|rc|p)               # version, release type
    #         [[:digit:]]*                        # version, patchlevel
    #     )*
    #     (
    #         -                                   # separator
    #         (
    #             r([[:digit:]]+)                 # version, revision
    #         )?
    #     )?
    # )?
    # $/
    
    CATEGORY_PACKAGE='^([<>]?=?)(([^\/]+)\/)?([^[:space:]:]+)'
    VERSION_SLOT='([-:])'
    # VERSION='((([[:digit:]]+)?(\.([[:digit:]]+))*)?([a-z])?(_(alpha|beta|pre|rc|p)([[:digit:]]*))*(-(r([[:digit:]]+))?)?)?$'
    VERSION='((([[:digit:]]+)(\.([[:digit:]]+))*)([a-z])?(_(alpha|beta|pre|rc|p)([[:digit:]]*))*(-(r([[:digit:]]+))?)?)?$'
    
    if [[ "$1" =~ ${CATEGORY_PACKAGE}${VERSION_SLOT}${VERSION} ]] || [[ "$1" =~ ${CATEGORY_PACKAGE} ]] ; then
        CPV[VERSION_SPECIFIER]="${BASH_REMATCH[1]}"
        CPV[CATEGORY]="${BASH_REMATCH[3]}"
        CPV[PACKAGE_NAME]="${BASH_REMATCH[4]}"
        
        case "${BASH_REMATCH[5]}" in
            "-")
                CPV[VERSION_SLOT_TYPE]="version"
                ;;
            ":")
                CPV[VERSION_SLOT_TYPE]="slot"
                ;;
            *)
                CPV[VERSION_SLOT_TYPE]=
                ;;
        esac
        
        CPV[VERSION]="${BASH_REMATCH[6]}"
        CPV[VERSION_DOTS]="${BASH_REMATCH[7]}"
        CPV[VERSION_LETTER]="${BASH_REMATCH[11]}"

        CPV[VERSION_PATCH_TYPE]="${BASH_REMATCH[13]}"
        
        case "${BASH_REMATCH[13]}" in
            "alpha")
                CPV[VERSION_PATCH_TYPE_PRIORITY]=0
                ;;
            "beta")
                CPV[VERSION_PATCH_TYPE_PRIORITY]=1
                ;;
            "pre")
                CPV[VERSION_PATCH_TYPE_PRIORITY]=2
                ;;
            "rc")
                CPV[VERSION_PATCH_TYPE_PRIORITY]=3
                ;;
            "p")
                CPV[VERSION_PATCH_TYPE_PRIORITY]=4
                ;;
             *)
                CPV[VERSION_PATCH_TYPE_PRIORITY]=5
                ;;
        esac
        
        CPV[VERSION_PATCH_LEVEL]="${BASH_REMATCH[14]}"
        CPV[VERSION_REVISION_NUMBER]="${BASH_REMATCH[17]}"
    fi

    # echo "${BASH_REMATCH[@]}" > /dev/tty

    # echo "Version specifier: ${CPV[VERSION_SPECIFIER]}" > /dev/tty
    # echo "Category: ${CPV[CATEGORY]}" > /dev/tty
    # echo "Package name: ${CPV[PACKAGE_NAME]}" > /dev/tty
    # echo "Version/slot: ${CPV_INFO[VERSION_SLOT_TYPE]}"
    # echo "Version: ${CPV[VERSION]}" > /dev/tty
    # echo "Version, dots: ${CPV[VERSION_DOTS]}" > /dev/tty
    # echo "Version, letter: ${CPV[VERSION_LETTER]}" > /dev/tty
    # echo "Version, patch type: ${CPV[VERSION_PATCH_TYPE]}" > /dev/tty
    # echo "Version, patch type priority: ${CPV[VERSION_PATCH_TYPE_PRIORITY]}" > /dev/tty
    # echo "Version, patch level: ${CPV[VERSION_PATCH_LEVEL]}" > /dev/tty
    # echo "Version, revision number: ${CPV[VERSION_REVISION_NUMBER]}" > /dev/tty
    # echo "" > /dev/tty
    
    declare -p CPV
}

function compareDotsVersions() {
    local i VER1=(${1//./ }) VER2=(${2//./ })
    declare -i RESULT=0

    # echo "${VER1[@]} ${VER2[@]}" > /dev/tty
    if [[ "${VER1[@]}" != "${VER2[@]}" ]] ; then
        for ((i=${#VER1[@]}; i < ${#VER2[@]}; i++)) ; do
            VER1[i]=0
        done
        
        for ((i=0; i < ${#VER1[@]}; i++)) ; do
            if [[ -z ${VER2[i]} ]] ; then
                VER2[i]=0
            fi
            
            if ((10#${VER1[i]} < 10#${VER2[i]})) ; then
                RESULT=-1
                break
            else
                if ((10#${VER1[i]} > 10#${VER2[i]})) ; then
                    RESULT=1
                    break
                fi            
            fi
        done
    fi
    
    echo "${RESULT}"
}

function compareVersions() {
    # $1 < $2 --> -1
    # $1 == $2 --> 0
    # $1 > $2 --> 1
    
    local tmp=$(getCategoryPackageVersion "$1")
    # echo "1: $tmp" > /dev/tty
    eval "${tmp/CPV=/CPV1=}"
    # echo "1: ${CPV1[@]}" > /dev/tty
    
    local tmp=$(getCategoryPackageVersion "$2")
    # echo "2: $tmp" > /dev/tty
    eval "${tmp/CPV=/CPV2=}"
    # echo "2: ${CPV2[@]}" > /dev/tty
    
    # category and name must be the same, does not make sense to compare different atoms
    if [[ ${CPV1[CATEGORY]} != ${CPV2[CATEGORY]} || ${CPV1[PACKAGE_NAME]} != ${CPV2[PACKAGE_NAME]} ]] ; then
        echo "-2"
    fi
    
    # no logic based on version specifier, for now    
    KEYS=(VERSION_DOTS VERSION_LETTER VERSION_PATCH_TYPE_PRIORITY VERSION_PATCH_LEVEL VERSION_REVISION_NUMBER)
    
    declare -i RESULT=0

    for KEY in "${KEYS[@]}" ; do
        if [[ "${KEY}" == VERSION_DOTS ]] ; then
            if [[ ${CPV1[$KEY]} =~ [9]{4,} ]] ; then
                RESULT=-1
                break
            else
                if [[ ${CPV2[$KEY]} =~ [9]{4,} ]] ; then
                    RESULT=1
                    break
                else
                    RESULT=$(compareDotsVersions "${CPV1[$KEY]}" "${CPV2[$KEY]}")
                    if ((${RESULT} != 0)) ; then
                        break
                    fi
                fi
            fi
        else        
            if [[ ${CPV1[$KEY]} -eq ${CPV2[$KEY]} ]] ; then
                # echo "${CPV1[$KEY]} = ${CPV2[$KEY]}" > /dev/tty
                continue
            else
                if [[ ${CPV1[$KEY]} -lt ${CPV2[$KEY]} ]] ; then
                    # echo "${CPV1[$KEY]} < ${CPV2[$KEY]}" > /dev/tty
                    RESULT=-1
                    break
                else
                    # if [[ ${CPV1[$KEY]} -gt ${CPV2[$KEY]} ]] ; then
                    # echo "${CPV1[$KEY]} > ${CPV2[$KEY]}" > /dev/tty
                    RESULT=1
                    break
                    # fi
                fi
            fi
        fi
    done

    echo "${RESULT}"
}

function getFlavorFromFile() {
    local EBUILD=$1
    local TESTING=$2
    local STABLE=$3

    # echo grep -Pqx "\s*KEYWORDS=\".*${TESTING}(?!-)+.*\"" "${EBUILD}" > /dev/tty
    
    local FLAVOR=
    if grep -Pqx "\s*KEYWORDS=\".*${TESTING}(?!-)+.*\"" "${EBUILD}" ; then
        FLAVOR="${TESTING}"
    else 
        if grep -Pqx "\s*KEYWORDS=\".*${STABLE}(?!-)+.*\"" "${EBUILD}" ; then
            FLAVOR="${STABLE}"
        fi
    fi
    
    echo "${FLAVOR}"
}

function getLatestVersion() {

    local USE_PACKAGES_GENTOO_ORG=${USE_PACKAGES_GENTOO_ORG:-false}
    
    local ROOT_PATH=$1
    local PACKAGE=$2
    local ATOMS_FLAVORS=($3)
    local ATOM_CATEGORY=$4
    local ATOM_NAME=$5
    local PORTAGE_TREE_PATH=$6
    local OVERLAYS=($7)

    local ATOM="${ATOM_CATEGORY}/${ATOM_NAME}"

    local VER=
    
    # Get mOS repo atom flavor (stable/testing)
    local ATOM_FLAVORS_FILE=${ROOT_PATH}/package.accept_keywords/${PACKAGE//\//-}.accept_keywords
    
    if [ -f "${ATOM_FLAVORS_FILE}" ] ; then
        local ATOMS=()
        # IFS=$'\r\n' read -d '' -r -a ATOMS < ${ATOM_FLAVORS_FILE}
        
        while read LINE; do
            ATOMS+=("${LINE// /|}")
        done < <(sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' "${ATOM_FLAVORS_FILE}")

        ATOMS_FLAVORS=("${ATOMS[@]}" "${ATOMS_FLAVORS[@]}")
    fi

    # Get atom flavor
    local TESTING='~amd64'
    local STABLE='amd64'
    
    local ATOM_FLAVOR=${STABLE}

    for ATOM_FLAVOR_ITEM in ${ATOMS_FLAVORS[@]} ; do
        local ATOM_FLAVOR=(${ATOM_FLAVOR_ITEM//|/ })

        if [[ "${ATOM_FLAVOR[0]}" == "${ATOM}" && "${ATOM_FLAVOR[1]}" == "${TESTING}" ]] ; then
            ATOM_FLAVOR=${TESTING}
            break;
        fi
    done
            
    # Get Gentoo web/repo atom version
    if [ "${#OVERLAYS[@]}" -gt 0 ] ; then
        local FLAVOR=$([[ "${ATOM_FLAVOR}" == "${STABLE}" ]] && echo "${STABLE}" || echo "${TESTING}")

        # one overlay only, so far
        OVERLAY="${OVERLAYS[0]}"

        local ATOM_FLAVOR_EBUILD=$(curl --silent "https://gpo.zugaina.org/${ATOM}" | xmllint --html --xpath "(//div[contains(@id,'${OVERLAY}')]//div[contains(text(), '${FLAVOR}')]/preceding::div[1]/b/text())[1]" - 2>/dev/null)
        
        # check for newer version that is stable
        local LATEST_STABLE_EBUILD=
        if [[ "${ATOM_FLAVOR}" == "${TESTING}" ]] ; then
            LATEST_STABLE_EBUILD=$(curl --silent "https://gpo.zugaina.org/${ATOM}" | xmllint --html --xpath "(//div[contains(@id,'${OVERLAY}')]//div[contains(text(), '${TESTING}')]/preceding::div[1]/b/text())[1]" - 2>/dev/null)
        fi
        
        local EBUILD="${ATOM_FLAVOR_EBUILD}"
        if [[ ! -z "${LATEST_STABLE_EBUILD}" && "${LATEST_STABLE_EBUILD}" != "${ATOM_FLAVOR_EBUILD}" ]] ; then
            local COMPARISON_RESULT=$(compareVersions "${ATOM_CATEGORY}/${LATEST_STABLE_EBUILD}" "${ATOM_CATEGORY}/${ATOM_FLAVOR_EBUILD}")
            
            if [[ ((${COMPARISON_RESULT} == 1)) ]] ; then
                EBUILD="${LATEST_STABLE_EBUILD}"
            fi
        fi
        
        local tmp=$(getCategoryPackageVersion "${ATOM_CATEGORY}/${EBUILD}")
        # echo "1: $tmp" > /dev/tty
        eval "${tmp/CPV=/EBUILD_CPV=}"
        # echo "1: ${EBUILD_CPV[@]}" > /dev/tty

        VER="${EBUILD_CPV[VERSION]}"
        # echo "VER: ${VER}" > /dev/tty
        
        echo "${ATOM}: ${VER}" >> debug # > /dev/tty
    else
        if [[ ${USE_PACKAGES_GENTOO_ORG} == true ]] ; then
            # to do: peek newer stable version if exists
            local FLAVOR_CLASS=$([[ "${ATOM_FLAVOR}" == "${STABLE}" ]] && echo "stable" || echo "testing")

            # Use https://packages.gentoo.org
            VER=$(curl --silent "https://packages.gentoo.org/packages/${ATOM}" | xmllint --html --xpath "(//*[contains(@class,'kk-versions')]//td[contains(@class,'kk-keyword-${FLAVOR_CLASS}')]/preceding::td[1]//a[contains(@class,'kk-ebuild-link')]/text())[1]" - 2>/dev/null)
        else
            shopt -s globstar extglob nullglob
            local EBUILDS=(${PORTAGE_TREE_PATH}/${ATOM}/*.ebuild)
            EBUILDS=( "${EBUILDS[@]##*/}" )      # strip off directory names
            EBUILDS=( "${EBUILDS[@]%.ebuild}" )  # strip off extensions

            if [ ${#EBUILDS[@]} -gt 0 ] ; then
                # echo "Unsorted: ${EBUILDS[@]}" > /dev/tty

                # local FLAVORS=()
                # for EBUILD in "${EBUILDS}"; do
                #     FLAVORS+=($(getFlavorFromFile "${PORTAGE_TREE_PATH}/${ATOM}/${EBUILD}" "${TESTING}" "${STABLE}"))
                # done
                
                for ((i=0; i <= $((${#EBUILDS[@]} - 2)); ++i)) ; do
                    for ((j=((i + 1)); j <= ((${#EBUILDS[@]} - 1)); ++j))
                    do
                        local EBUILD1="${EBUILDS[i]}"
                        local EBUILD2="${EBUILDS[j]}"
                        local COMPARISON_RESULT=$(compareVersions "${ATOM_CATEGORY}/${EBUILD1}" "${ATOM_CATEGORY}/${EBUILD2}")
                        # echo "Comparison result for ${EBUILD1} and ${EBUILD2}: ${COMPARISON_RESULT}" > /dev/tty
                        
                        if [[ ((${COMPARISON_RESULT} == -1)) ]]
                        then
                            # echo "Switch: $i <-> $j (${EBUILD1} <-> ${EBUILD2})" > /dev/tty
                            local tmp=${EBUILDS[i]}
                            EBUILDS[i]=${EBUILDS[j]}
                            EBUILDS[j]=$tmp
                        fi
                    done
                done
                
                # echo "Sorted: ${EBUILDS[@]}" > /dev/tty
                
                # Search for the preferred version
                # That is the first stable version or the first version of the same flavor
                for EBUILD in "${EBUILDS[@]}"; do
                    local EBUILD_FLAVOR=$(getFlavorFromFile "${PORTAGE_TREE_PATH}/${ATOM}/${EBUILD}.ebuild" "${TESTING}" "${STABLE}")
                    
                    # echo "${EBUILD} flavor: ${EBUILD_FLAVOR}" > /dev/tty
                    # echo "${ATOM} flavor: ${ATOM_FLAVOR}" > /dev/tty
                    
                    if [[ "${EBUILD_FLAVOR}" == "${STABLE}" || "${ATOM_FLAVOR}" == "${EBUILD_FLAVOR}" ]] ; then
                        local tmp=$(getCategoryPackageVersion "${ATOM_CATEGORY}/${EBUILD}")
                        # echo "1: $tmp" > /dev/tty
                        eval "${tmp/CPV=/EBUILD_CPV=}"
                        # echo "1: ${EBUILD_CPV[@]}" > /dev/tty
        
                        VER="${EBUILD_CPV[VERSION]}"
                        # echo "VER: ${VER}" > /dev/tty
                        break;
                    fi
                done
                
                # If the searched flavor was not found, peek the first available version
                if [[ -z "${VER}" ]] ; then
                    local tmp=$(getCategoryPackageVersion "${ATOM_CATEGORY}/"${EBUILDS[0]}"")
                    # echo "1: $tmp" > /dev/tty
                    eval "${tmp/CPV=/EBUILD_CPV=}"
                    # echo "1: ${EBUILD_CPV[@]}" > /dev/tty
    
                    VER="${EBUILD_CPV[VERSION]}"
                    # echo "VER: ${VER}" > /dev/tty
                fi
            fi
        fi
    fi

    # echo "VER: ${VER}" > /dev/tty
    # echo "" > /dev/tty
    
    echo "${VER}"
}


ROOT_PATH="${ROOT_PATH:-..}"
COLLECTION="${COLLECTION:-apps}"

# Remove debug file
if [[ -f debug ]] ; then
    rm debug
fi

# Ensure Gentoo overlay tree

REFRESH_TREE="${REFRESH_TREE:-false}"
PORTAGE_TREE_PATH="${PORTAGE_TREE_PATH:-../../portage/tree}"

if [[ -d "${PORTAGE_TREE_PATH}" && ${REFRESH_TREE} == "true" ]] ; then
    rm -r "${PORTAGE_TREE_PATH}"
fi

if [[ ! -d "${PORTAGE_TREE_PATH}" ]] ; then
    PORTAGE_HASH=$(curl --silent --location  https://github.com/mocaccinoOS/desktop/raw/master/packages/images/portage/definition.yaml | yq r -j - | jq -r '.labels."git.hash"' - 2>/dev/null)

    # --remote-name
    curl --silent --location --remote-header-name https://github.com/gentoo/gentoo/archive/${PORTAGE_HASH}.tar.gz -o tree.tar.gz

    mkdir -p "${PORTAGE_TREE_PATH}"
    tar xf ./tree.tar.gz -C "${PORTAGE_TREE_PATH}" --strip-components=1
    rm ./tree.tar.gz
fi


# Parse mOS community repo

# PACKAGES=$(cd ${ROOT_PATH}; luet tree pkglist -f -o json)
# | select(.name == "openrgb" or .name == "cfortran" or .name == "wine-staging" or .name == "terminatorx" or .name == "nnn" or .name == "hedgewars")
PACKAGES=$(yq r -j ${ROOT_PATH}/packages/${COLLECTION}/collection.yaml \
| jq -r '.packages[] 
| select(.labels != null and .labels."emerge.packages" != null) 
| .category + "/" + .name 
+ "," + .version 
+ "," + (.labels."emerge.packages" | sub(" "; ";"; "g")) 
+ "," + (.version | split("+") | .[0]) 
+ "," + if (.atoms != null) then [(.atoms[] | select(.accept_keywords != null) | .atom + "|" + .accept_keywords)] | join(";") else "" end
+ "," + if (.overlays != null) then [(.overlays[] | .name)] | join(";") else "" end')

# echo $PACKAGES > packages.list

echo > packages.info
echo > packages.up

for PKG in ${PACKAGES} ; do

    PACKAGE=(${PKG//,/ })

    PACKAGE_CATEGORY_NAME="${PACKAGE[0]}"
    PACKAGE_VERSION="${PACKAGE[1]}"
    ATOMS="${PACKAGE[2]//;/ }"
    ATOM_VERSION="${PACKAGE[3]}"
    ATOMS_FLAVORS="${PACKAGE[4]//;/ }"
    OVERLAYS="${PACKAGE[5]//;/ }"
    
    LINES=()

    # REVBUMP_CHAR="${REVBUMP_CHAR:-+}"

    CLOSEST_LEV=
    CLOSEST_ATOM=
    CLOSEST_ATOM_VER=

    PACKAGE_NAME=$( echo -e "${PACKAGE_CATEGORY_NAME}" | sed -e 's/\(.*\)\/\(.*\)/\2/' )

    for ATOM in ${ATOMS} ; do

        echo -e "${ATOM}"

#         STRIPPED_ATOM=($( echo -e "${ATOM}" | sed -e 's/[<>=:]*\(.*\)\/\(.*\)[:]*.*/\1 \2/' ))
#         MORE_STRIPPED_ATOM=($( echo -e "${ATOM}" | sed -e 's/[<>=:]*\(.*\)\/\(.*\)[:-].*/\1 \2/' ))
# 
#         MATCHED_ATOM="${STRIPPED_ATOM[0]}/${STRIPPED_ATOM[1]}"
#         VER=$(getLatestVersion "${ROOT_PATH}/packages/${COLLECTION}" "${PACKAGE_CATEGORY_NAME}" "${ATOMS_FLAVORS}" "${STRIPPED_ATOM[0]}" "${STRIPPED_ATOM[1]}" "${PORTAGE_TREE_PATH}" "${OVERLAYS}")
#         
#         if [[ -z "${VER}" ]] ; then
#             echo "AAA: ${STRIPPED_ATOM[@]}" >> /dev/tty
#             echo "BBB: ${MORE_STRIPPED_ATOM[@]}" >> /dev/tty
#             echo "ZZZ: ${ATOM}" >> /dev/tty
#             echo "XXX: ${MORE_STRIPPED_ATOM[0]}" >> /dev/tty
#             echo "YYY: ${MORE_STRIPPED_ATOM[1]}" >> /dev/tty
#             MATCHED_ATOM="${MORE_STRIPPED_ATOM[0]}/${MORE_STRIPPED_ATOM[1]}"
#             VER=$(getLatestVersion "${ROOT_PATH}/packages/${COLLECTION}" "${PACKAGE_CATEGORY_NAME}" "${ATOMS_FLAVORS}" "${MORE_STRIPPED_ATOM[0]}" "${MORE_STRIPPED_ATOM[1]}" "${PORTAGE_TREE_PATH}" "${OVERLAYS}")
#         fi
#         
#         if [[ -z "${VER}" ]] ; then
#             MATCHED_ATOM=
#         fi
# 
#         LINES+=("portage atom: ${MATCHED_ATOM} ${VER}")
# 
#         LEV=$(levenshtein "${STRIPPED_ATOM[1]}" "${PACKAGE_NAME}");
#         LEVM=$(levenshtein "${MORE_STRIPPED_ATOM[1]}" "${PACKAGE_NAME}");
# 
#         if [[ -z "${CLOSEST_LEV}" || $CLOSEST_LEV -gt $LEVM ]] ; then
#             CLOSEST_LEV=$LEVM
#             CLOSEST_ATOM="${MORE_STRIPPED_ATOM[0]}/${MORE_STRIPPED_ATOM[1]}"
#             CLOSEST_ATOM_VER=$VER
#         fi
#         if [[ $CLOSEST_LEV -gt $LEV ]] ; then
#             CLOSEST_LEV=$LEV
#             CLOSEST_ATOM="${STRIPPED_ATOM[0]}/${STRIPPED_ATOM[1]}"
#             CLOSEST_ATOM_VER=$VER
#         fi

        tmp=$(getCategoryPackageVersion "${ATOM}")
        # echo "1: $tmp" > /dev/tty
        eval "${tmp/CPV=/CPV_ATOM=}"
        # echo "1: ${CPV_ATOM[@]}" > /dev/tty
        
        ATOM_CATEGORY="${CPV_ATOM[CATEGORY]}"
        ATOM_NAME="${CPV_ATOM[PACKAGE_NAME]}"
        
        VER=$(getLatestVersion "${ROOT_PATH}/packages/${COLLECTION}" "${PACKAGE_CATEGORY_NAME}" "${ATOMS_FLAVORS}" "${ATOM_CATEGORY}" "${ATOM_NAME}" "${PORTAGE_TREE_PATH}" "${OVERLAYS}")

        MATCHED_ATOM="\U1FBC4"
        MATCHED_ATOM_VER="\U1FBC4"
        if [[ ! -z "${VER}" ]] ; then
            MATCHED_ATOM="${ATOM_CATEGORY}/${ATOM_NAME}"
            MATCHED_ATOM_VER="${VER}"
        fi

        LINES+=("portage atom: ${MATCHED_ATOM} ${VER}")
        
        LEV=$(levenshtein "${ATOM_NAME}" "${PACKAGE_NAME}");
        
        if [[ -z "${CLOSEST_LEV}" || $CLOSEST_LEV -gt $LEV ]] ; then
            CLOSEST_LEV=$LEV
            CLOSEST_ATOM="${MATCHED_ATOM}"
            CLOSEST_ATOM_VER=$MATCHED_ATOM_VER
        fi
    done

    UPGRADE=
    FILES="packages.info"
    if [[ -z ${CLOSEST_ATOM_VER} ]] ; then
        # No match, mark with 🯄
        UPGRADE=" \U1F86D \U1FBC4"
        FILES="packages.info packages.up"
    else
        if [[ ${ATOM_VERSION} != ${CLOSEST_ATOM_VER} ]] ; then
            UPGRADE=" \U1F86D ${CLOSEST_ATOM_VER}"
            FILES="packages.info packages.up"
        fi
    fi
    
    ATOMS_FLAVORS_FORMATTED="${ATOMS_FLAVORS//|/(}"
    if [[ ! -z "${ATOMS_FLAVORS_FORMATTED}" ]] ; then
        ATOMS_FLAVORS_FORMATTED="${ATOMS_FLAVORS_FORMATTED// /) })"
    fi
    
    LINES=("package: ${PACKAGE_CATEGORY_NAME}\npackage version: ${PACKAGE_VERSION}${UPGRADE}\natoms: ${ATOMS}\natom version: ${ATOM_VERSION}\natoms flavors: ${ATOMS_FLAVORS_FORMATTED}\noverlays: ${OVERLAYS}" "${LINES[@]}")
    
    for LINE in "${LINES[@]}" ; do
        echo -e "${LINE}" | tee -a $FILES > /dev/null
    done
    
    echo -e "" | tee -a $FILES > /dev/null
done

echo -e "\n\e\033[5;32;1mDone!\e[0m\n"
