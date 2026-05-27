#!/bin/bash

# if [[ $(id -u) -ne 0 ]] ; then
#     echo -e "Must run as \e[5;31;1mroot\e[0m!"
#     exit 1
# fi

log_debug() {
    if [[ $DEBUG == "debug" && -n "$1" ]]; then
        echo -e "$DEBUG:" > /dev/tty
        echo -e "$DEBUG:" >> "${DEBUG_FILE}"
            
        local content
        for content in "$@"; do
            echo -e "  ${content}" > /dev/tty
            echo -e "  ${content}" >> "${DEBUG_FILE}"
        done
    fi
}

output() {
    local target_files="$1"
    local content="$2"

    log_debug $content

    local file

    for file in $target_files; do
        echo -e "$content" >> "$file"
    done
}

function levenshtein() {
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

    local ATOM="$1"

    local ATOM_REGEX='^([><=~!|*]+)?(([a-zA-Z0-9+][a-zA-Z0-9._+-]*)/)?([a-zA-Z0-9+][a-zA-Z0-9_+]*(-[a-zA-Z+][a-zA-Z0-9_+]*)*)(-([0-9][a-zA-Z0-9._+-]*))?(:([a-zA-Z0-9+][a-zA-Z0-9._+-]*))?(\.([a-zA-Z0-9._+-]+))?(([a-zA-Z0-9_+-]+))?(::([a-zA-Z0-9+][a-zA-Z0-9._+-]*))?(\[(.*)\])?$'

    declare -A CPV

    log_debug "Parsing the atom: ${ATOM}"

    if [[ $ATOM =~ $ATOM_REGEX ]]; then
        CPV[VERSION_SPECIFIER]="${BASH_REMATCH[1]}"
        CPV[CATEGORY]="${BASH_REMATCH[3]}"
        CPV[NAME]="${BASH_REMATCH[4]}"
        CPV[VERSION]="${BASH_REMATCH[7]}"
        
        # Isolate trailing layout blocks
        local REMAINDER="${ATOM#*"${CPV[NAME]}"}"
        [[ -n "${CPV[VERSION]}" ]] && REMAINDER="${REMAINDER#-"${CPV[VERSION]}"}"
        
        CPV[USE_FLAGS]=""
        if [[ "${REMAINDER}" =~ \[([^]]+)\]$ ]]; then
            CPV[USE_FLAGS]="${BASH_REMATCH[1]}"
            REMAINDER="${REMAINDER%\[*}"
        fi
        
        CPV[REPOSITORY]=""
        if [[ "${REMAINDER}" =~ ::([a-zA-Z0-9+][a-zA-Z0-9._+-]*) ]]; then
            CPV[REPOSITORY]="${BASH_REMATCH[1]}"
            REMAINDER="${REMAINDER%%::*}"
        fi
        
        CPV[SLOT]=""
        CPV[SLOT_MAJOR_DOTS]=""
        CPV[SLOT_MINOR_DOTS]=""
        CPV[SLOT_SUFFIX]=""
        if [[ "${REMAINDER}" =~ :([a-zA-Z0-9+_\.-]+) ]]; then
            local ATOM_SLOT="${BASH_REMATCH[1]}"
            
            CPV[SLOT]="${ATOM_SLOT}"
            
            # Isolate text suffix from the end (e.g., "slot" from "2.35slot")
            if [[ "${ATOM_SLOT}" =~ ([a-zA-Z_-]+)$ ]]; then
                CPV[SLOT_SUFFIX]="${BASH_REMATCH[1]}"
                ATOM_SLOT="${ATOM_SLOT%"${CPV[SLOT_SUFFIX]}"}"
            fi
            
            # Split remainder on dot to separate major slot and slot dots
            if [[ "${ATOM_SLOT}" == *.* ]]; then
                CPV[SLOT_MAJOR_DOTS]="${ATOM_SLOT%.*}"
                CPV[SLOT_MINOR_DOTS]="${ATOM_SLOT#*.}"
            else
                CPV[SLOT_MAJOR_DOTS]="${ATOM_SLOT}"
            fi
        fi

        CPV[VERSION_DOTS]=""
        CPV[VERSION_LETTER]=""
        CPV[VERSION_PATCH_TYPE]=""
        CPV[VERSION_PATCH_LEVEL]=""
        CPV[VERSION_REVISION_NUMBER]=""
        CPV[VERSION_PATCH_TYPE_PRIORITY]=""

        # Split version string from right to left
        if [[ -n "${CPV[VERSION]}" ]]; then
            local ATOM_VERSION="${CPV[VERSION]}"

            # Extract revision numbers (-rX)
            if [[ "${ATOM_VERSION}" =~ -r([0-9]+)$ ]]; then
                CPV[VERSION_REVISION_NUMBER]="${BASH_REMATCH[1]}"
                ATOM_VERSION="${ATOM_VERSION%-r*}"
            fi

            # Handle multi-suffix elements (e.g., _alpha1_pre20250509)
            if [[ "${ATOM_VERSION}" =~ _(alpha|beta|pre|rc|p)([0-9]*)$ ]]; then
                CPV[VERSION_PATCH_TYPE]="${BASH_REMATCH[1]}"
                CPV[VERSION_PATCH_LEVEL]="${BASH_REMATCH[2]}"
                
                local SUFFIX_TOKEN="${BASH_REMATCH[0]}"
                ATOM_VERSION="${ATOM_VERSION%"$SUFFIX_TOKEN"*}"
            fi

            # Clear out any remaining nested prefix components (like _alpha1)
            if [[ "$ATOM_VERSION" =~ _(alpha|beta|pre|rc|p)([0-9]*)$ ]]; then
                local NESTED_TOKEN="${BASH_REMATCH[0]}"
                ATOM_VERSION="${ATOM_VERSION%"$NESTED_TOKEN"*}"
            fi

            case "${CPV[VERSION_PATCH_TYPE]}" in
                alpha) CPV[VERSION_PATCH_TYPE_PRIORITY]=1 ;;
                beta)  CPV[VERSION_PATCH_TYPE_PRIORITY]=2 ;;
                pre)   CPV[VERSION_PATCH_TYPE_PRIORITY]=3 ;;
                rc)    CPV[VERSION_PATCH_TYPE_PRIORITY]=4 ;;
                p)     CPV[VERSION_PATCH_TYPE_PRIORITY]=5 ;;
            esac

            # Extract alpha suffix letter
            if [[ "$ATOM_VERSION" =~ ([a-z])$ ]]; then
                CPV[VERSION_LETTER]="${BASH_REMATCH[1]}"
                ATOM_VERSION="${ATOM_VERSION%[a-z]}"
            fi

            CPV[VERSION_DOTS]="${ATOM_VERSION}"
        fi
    else
        log_debug "ERROR: Structural validation failed for ${ATOM}."
    fi

    log_debug \
        "Atom parsed: ${ATOM}"\
        "  Matched: $(IFS=,; printf "%s" "${BASH_REMATCH[*]}")"\
        "  Matched: $(IFS=,; printf "%s" "${CPV[*]}")"\
        "  Version specifier: ${CPV[VERSION_SPECIFIER]}"\
        "  Category: ${CPV[CATEGORY]}"\
        "  Name: ${CPV[NAME]}"\
        "  Version: ${CPV[VERSION]}"\
        "  Version, dots: ${CPV[VERSION_DOTS]}"\
        "  Version, letter: ${CPV[VERSION_LETTER]}"\
        "  Version, patch type: ${CPV[VERSION_PATCH_TYPE]}"\
        "  Version, patch type priority: ${CPV[VERSION_PATCH_TYPE_PRIORITY]}"\
        "  Version, patch level: ${CPV[VERSION_PATCH_LEVEL]}"\
        "  Version, revision number: ${CPV[VERSION_REVISION_NUMBER]}"\
        "  Slot: ${CPV[SLOT]}"\
        "  Slot, major dots: ${CPV[SLOT_MAJOR_DOTS]}"\
        "  Slot, minor dots: ${CPV[SLOT_MINOR_DOTS]}"\
        "  Slot, suffix: ${CPV[SLOT_SUFFIX]}"\
        "  Repository Overlay: ${CPV[REPOSITORY]}"\
        "  USE Flags: ${CPV[USE_FLAGS]}\n"
    
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
    # Returned values
    # $1 < $2 --> -1
    # $1 == $2 --> 0
    # $1 > $2 --> 1
        
    log_debug \
        "Comparing versions: "\
        "  $1 "\
        "  $2"

    local tmp=$(getCategoryPackageVersion "$1")
    # echo "$tmp" > /dev/tty
    eval "${tmp/CPV=/CPV1=}"
    # echo "${CPV1[@]}" > /dev/tty
    
    local tmp=$(getCategoryPackageVersion "$2")
    # echo "2: $tmp" > /dev/tty
    eval "${tmp/CPV=/CPV2=}"
    # echo "2: ${CPV2[@]}" > /dev/tty
    
    # category and name must be the same, does not make sense to compare different atoms
    if [[ ${CPV1[CATEGORY]} != ${CPV2[CATEGORY]} || ${CPV1[NAME]} != ${CPV2[NAME]} ]] ; then
        echo "-2"
    fi
    
    # no logic based on version specifier, for now    
    KEYS=(VERSION_DOTS VERSION_LETTER VERSION_PATCH_TYPE_PRIORITY VERSION_PATCH_LEVEL VERSION_REVISION_NUMBER SLOT SLOT_MAJOR_DOTS SLOT_MINOR_DOTS, SLOT_SUFFIX REPOSITORY USE_FLAGS)
    
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

function getSlotFromFile() {
    local EBUILD=$1
    
    local SLOT=$(sed -En 's/SLOT="(.*)"/\1/p' "${EBUILD}")

    echo "${SLOT}"
}

function getPythonCompatFromFile() {
    local EBUILD=$1

    PYTHON_COMPAT=$(sed -En 's/PYTHON_COMPAT=(.*)/\1/p' "${EBUILD}" 2>/dev/null)

    echo "${PYTHON_COMPAT}"
}

function download_overlay() {
    local OVERLAY_NAME="${1:-}"
    local OVERLAYS_PATH="${2:-}"
    local COMMIT_HASH="${3:-}"

    # Validate mandatory arguments
    if [ -z "${OVERLAY_NAME}" ] || [ -z "${OVERLAYS_PATH}" ]; then
        echo "Usage: download_overlay <overlay_name> <overlays_path> [commit_hash]"
        return 1
    fi

    OVERLAY_PATH="${OVERLAYS_PATH}/${OVERLAY_NAME}"
    
    if [[ ! -d "${OVERLAY_PATH}" ]] ; then    
        log_debug "Fetching URL for overlay: '${OVERLAY_NAME}'..."

        # Fetch official list and parse the Git URL
        local REPO_URL
        REPO_URL=$(curl -s https://api.gentoo.org/overlays/repositories.xml | \
            grep -A 10 "<name>${OVERLAY_NAME}</name>" | \
            grep -m 1 '<source type="git">' | \
            sed -e 's/<source type="git">//' -e 's/<\/source>//' -e 's/^[ \t]*//')
        # REPO_URLrepo_url=$(curl -s "https://gentoo.org" | \
        # tr -d '\n\r' | \
        # sed 's/<repository/\n<repository/g' | \
        # grep -E "<name>${OVERLAY_NAME}</name>" | \
        # grep -m 1 -oE '<source type="git">[^<]+' | \
        # sed 's/<source type="git">//')

        if [ -z "$REPO_URL" ]; then
            log_debug "Error: Overlay '${OVERLAY_NAME}' not found in the official Gentoo list."
        else
            log_debug \
                "Found URL: ${REPO_URL}"\
                "Downloading repository into: ${OVERLAY_PATH}..."
            
            if [ -n "${COMMIT_HASH}" ]; then
                log_debug "Targeting specific commit: ${COMMIT_HASH}"
                git clone --depth 1 "${REPO_URL}" "${OVERLAY_PATH}" --revision="${COMMIT_HASH}"
                
            else
                git clone --depth 1 "${REPO_URL}" "${OVERLAY_PATH}"
            fi
            
            [[ -n "${OVERLAY_PATH}" && -d "${OVERLAY_PATH}" ]] && rm -rf "${OVERLAY_PATH}"/.git*
            
            # read -p "Press <Enter> to continue..."

            log_debug "Success! Repository ready at ${OVERLAY_PATH}"
        fi
    fi
}

function getLatestVersion() {

    local ROOT_PATH=$1
    local OVERLAYS_PATH=$2
    local OVERLAYS=($3)
    local PACKAGE=$4
    local ATOMS_FLAVORS=($5)
    local ATOM_CATEGORY=$6
    local ATOM_NAME=$7
    local ATOM_SLOT=$8
    local ATOM_OVERLAY=$9

    local ATOM="${ATOM_CATEGORY}/${ATOM_NAME}"

    log_debug "Getting the latest version of ${ATOM}"
    
    local VER=
    local EFN=
    local OL=
    
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
    ALL_OVERLAYS=("${ATOM_OVERLAY:-gentoo}")
    if [[ "${#OVERLAYS[@]}" -gt 0 ]] ; then
        ALL_OVERLAYS=("${ALL_OVERLAYS[@]}" "${OVERLAYS[@]}")
    fi

    log_debug "Look into overlays: ${ALL_OVERLAYS[*]}"

    local BASE_URL="https://gpo.zugaina.org"

    for OVERLAY in ${ALL_OVERLAYS[@]} ; do
        log_debug "Looking for ${ATOM} in ${OVERLAY} overlay"
        
        OL="${OVERLAY}"
    
        if [[ "${OVERLAY}" == "gentoo" ]] ; then
            download_overlay "${OVERLAY}" "${OVERLAYS_PATH}" "${GENTOO_COMMIT_HASH}"
        else
            download_overlay "${OVERLAY}" "${OVERLAYS_PATH}"
        fi    
    
        local OVERLAY_PATH="${OVERLAYS_PATH}/${OVERLAY}"
    
        shopt -s globstar extglob nullglob
        local EBUILDS=(${OVERLAY_PATH}/${ATOM}/*.ebuild)
        EBUILDS=( "${EBUILDS[@]##*/}" )      # strip off directory names
        EBUILDS=( "${EBUILDS[@]%.ebuild}" )  # strip off extensions

        if [ ${#EBUILDS[@]} -gt 0 ] ; then
            log_debug \
                "Unsorted ebuilds:"\
                "${EBUILDS[@]/#/  }"

            # local FLAVORS=()
            # for EBUILD in "${EBUILDS}"; do
            #     FLAVORS+=($(getFlavorFromFile "${OVERLAY_PATH}/${ATOM}/${EBUILD}" "${TESTING}" "${STABLE}"))
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
            
            log_debug \
                "Sorted ebuilds:"\
                "${EBUILDS[@]/#/  }"
        
            log_debug \
                "Search for the preferred version"\
                "That is the first stable version or the first version of the same flavor"
            
            # Search for the preferred version
            # That is the first stable version or the first version of the same flavor
            for EBUILD in "${EBUILDS[@]}"; do
                local EBUILD_FLAVOR=$(getFlavorFromFile "${OVERLAY_PATH}/${ATOM}/${EBUILD}.ebuild" "${TESTING}" "${STABLE}")
                local EBUILD_SLOT=$(getSlotFromFile "${OVERLAY_PATH}/${ATOM}/${EBUILD}.ebuild")
                
                log_debug \
                    "  Ebuild flavor: ${EBUILD_FLAVOR}"\
                    "  Atom flavor: ${ATOM_FLAVOR}"\
                    "  Ebuild slot: ${EBUILD_SLOT}"\
                    "  Atom slot: ${ATOM_SLOT}"

                if [[ (( -z "${ATOM_SLOT}" ) || ( ! -z "${ATOM_SLOT}" && "${EBUILD_SLOT}" == "${ATOM_SLOT}"))
                    && ("${EBUILD_FLAVOR}" == "${STABLE}" || "${ATOM_FLAVOR}" == "${EBUILD_FLAVOR}") ]] ; then

                    log_debug "Analyze ${ATOM_CATEGORY}/${EBUILD}"
                    
                    local tmp=$(getCategoryPackageVersion "${ATOM_CATEGORY}/${EBUILD}")
                    # echo "${tmp}" > /dev/tty
                    eval "${tmp/CPV=/EBUILD_CPV=}"
                    # echo "${EBUILD_CPV[@]}" > /dev/tty
    
                    VER="${EBUILD_CPV[VERSION]}"
                    # echo "VER: ${VER}" > /dev/tty
                    EFN="${EBUILD}"
                    # echo "EFN: ${EFN}" > /dev/tty
                    
                    break
                fi
            done
            
            # If the searched flavor was not found, pick the first available version
            if [[ -z "${VER}" ]] ; then
                log_debug "The searched flavor was not found, pick the first available version"
            
                local tmp=$(getCategoryPackageVersion "${ATOM_CATEGORY}/"${EBUILDS[0]}"")
                # echo "${tmp}" > /dev/tty
                eval "${tmp/CPV=/EBUILD_CPV=}"
                # echo "${EBUILD_CPV[@]}" > /dev/tty

                VER="${EBUILD_CPV[VERSION]}"
                # echo "VER: ${VER}" > /dev/tty
                EFN="${EBUILD}"
                # echo "EFN: ${EFN}" > /dev/tty
            fi
            
            break
        fi
    done

    # echo "VER: ${VER}" > /dev/tty
    # echo "" > /dev/tty
    
    declare -A VERINFO
    
    VERINFO[VERSION]="${VER}"
    VERINFO[EBUILD_FILE_NAME]="${EFN}"
    VERINFO[OVERLAY]="${OL}"
    
    log_debug \
        "The latest version of ${ATOM} found in ${OL} is ${VER} (${EFN})"\
        "  Atom ${ATOM}"\
        "  Atom version: ${VER}"\
        "  Atom ebuild: ${EFN}"\
        "  Atom overlay: ${OL}"
    
    declare -p VERINFO
}

# Run: ./up.sh debug
DEBUG="$1"

REFRESH_OVERLAYS="${REFRESH_OVERLAYS:-true}"

ROOT_PATH="${ROOT_PATH:-../..}"

OVERLAYS_PATH="${OVERLAYS_PATH:-${ROOT_PATH}/overlays}"

if [[ -d "${OVERLAYS_PATH}" && ${REFRESH_OVERLAYS} == "true" ]] ; then
    rm -f -r "${OVERLAYS_PATH}"
fi

mkdir -p "${OVERLAYS_PATH}"

# Get the Gentoo tree hash used by mOS
GENTOO_COMMIT_HASH=
if [[ ${REFRESH_OVERLAYS} == "true" ]] ; then
    #GENTOO_COMMIT_HASH=$(curl --silent --location https://github.com/mocaccinoOS/desktop/raw/master/packages/images/portage/definition.yaml | yq r -j - | jq -r '.labels."git.hash"' - 2>/dev/null)
    GENTOO_COMMIT_HASH=$(curl --location https://github.com/mocaccinoOS/desktop/raw/master/packages/images/portage/definition.yaml | yq r -j - | jq -r '.labels."git.hash"' - 2>/dev/null)
else
    GENTOO_COMMIT_HASH=$(git -C "${OVERLAYS_PATH}/gentoo" rev-parse HEAD 2>/dev/null)
fi

if [[ -z "${GENTOO_COMMIT_HASH}" ]] ; then
    echo -e "\e\033[0;31;1mTree hash could not be retrieved.\e[0m"
    
    exit 1
else
    echo -e "\n\e\033[0;32;1mLooking for upgradable packages (${GENTOO_COMMIT_HASH}) ...\e[0m!\n"
fi

PACKAGES_REPORT_FILES_PATH="${PACKAGES_REPORT_FILES_PATH:-${ROOT_PATH}/reports}"
mkdir -p "${PACKAGES_REPORT_FILES_PATH}"

DEBUG_FILE="${PACKAGES_REPORT_FILES_PATH}/debug.log"
[[ $DEBUG == "debug" ]] && > "$DEBUG_FILE"

PACKAGES_INFO_FILE="${PACKAGES_REPORT_FILES_PATH}/packages.info"
PACKAGES_UP_FILE="${PACKAGES_REPORT_FILES_PATH}/packages.up"
ALL_FILES="${PACKAGES_INFO_FILE} ${PACKAGES_UP_FILE}"

mv "${PACKAGES_INFO_FILE}" "${PACKAGES_INFO_FILE}.prev"
mv "${PACKAGES_UP_FILE}" "${PACKAGES_UP_FILE}.prev"

> "${PACKAGES_INFO_FILE}"
> "${PACKAGES_UP_FILE}"

output "${ALL_FILES}" "\nPortage hash: ${GENTOO_COMMIT_HASH}\n"

COLLECTIONS=("layers" "apps")

for COLLECTION in ${COLLECTIONS[@]}; do
    
    output "${ALL_FILES}" "====================\nCOLLECTION: ${COLLECTION}\n====================\n"
    
    DEBUG_FILE="${PACKAGES_REPORT_FILES_PATH}/debug.log"
    
    # Remove debug file
    if [[ -f "${DEBUG_FILE}" ]] ; then
        rm -f "${DEBUG_FILE}"
    fi
    
    # Parse mOS community repo
    
    # PACKAGES=$(cd ${ROOT_PATH}; luet tree pkglist -f -o json)
    # | select(.name == "openrgb" or .name == "cfortran" or .name == "wine-staging" or .name == "terminatorx" or .name == "nnn" or .name == "hedgewars")
    PACKAGES=$(yq r -j ${ROOT_PATH}/community-repository/packages/${COLLECTION}/collection.yaml \
    | jq -r '.packages[] 
    | select(.labels != null and .labels."emerge.packages" != null and .category != "buildbase" and .category != "layerbase") 
    | .category + "/" + .name 
    + "," + .version 
    + "," + (.labels."emerge.packages" + " " + ( [.provides[] | .category + "/" + .name] | join(" ")) | gsub("\\s+";" ";"g") | split(" ") | unique | sort | join(";")) 
    + "," + (.version | split("+") | .[0]) 
    + "," + if (.atoms != null) then [(.atoms[] | select(.accept_keywords != null) | .atom + "|" + .accept_keywords)] | join(";") else "" end 
    + "," + if (.overlays != null) then [(.overlays[] | ( .enable // .add ))] | join(";") else "" end')
    
    # echo $PACKAGES > packages.list

    for PKG in ${PACKAGES} ; do
    
        log_debug \
            "Package info:"\
            "  $PKG"
    
        # PACKAGE=(${PKG//,/ }) # will collapse empty values
        IFS=',' read -r -a PACKAGE <<< "$PKG"
    
        PACKAGE_CATEGORY_NAME="${PACKAGE[0]}"
        PACKAGE_VERSION="${PACKAGE[1]}"
        ATOMS="${PACKAGE[2]//;/ }"
        ATOM_VERSION="${PACKAGE[3]}"
        ATOMS_FLAVORS="${PACKAGE[4]//;/ }"
        OVERLAYS="${PACKAGE[5]//;/ }"
        
        EBUILD=
        PYTHON_COMPAT=
        
        LINES=()
    
        CLOSEST_LEV=
        CLOSEST_ATOM=
        CLOSEST_ATOM_VER=
    
        PACKAGE_NAME=$( echo -e "${PACKAGE_CATEGORY_NAME}" | sed -e 's/\(.*\)\/\(.*\)/\2/' )

        for ATOM in ${ATOMS} ; do
    
            echo -e "${ATOM}"
    
            log_debug "Processing atom: ${ATOM}"
            
            tmp=$(getCategoryPackageVersion "${ATOM}")
            # echo "$tmp" > /dev/tty
            eval "${tmp/CPV=/CPV_ATOM=}"
            # echo "${CPV_ATOM[@]}" > /dev/tty
    
            ATOM_CATEGORY="${CPV_ATOM[CATEGORY]}"
            ATOM_NAME="${CPV_ATOM[NAME]}"
            ATOM_SLOT="${CPV_ATOM[SLOT]}"
            ATOM_OVERLAY="${CPV_ATOM[REPOSITORY]}"
    
            tmp=$(getLatestVersion "${ROOT_PATH}/packages/${COLLECTION}" "${OVERLAYS_PATH}" "${OVERLAYS}" "${PACKAGE_CATEGORY_NAME}" "${ATOMS_FLAVORS}" "${ATOM_CATEGORY}" "${ATOM_NAME}" "${ATOM_SLOT}" "${ATOM_OVERLAY}")
            # echo "$tmp" > /dev/tty
            eval "${tmp/VERINFO=/EBUILD_INFO=}"
            # echo "${EBUILD_INFO[@]}" > /dev/tty
            
            VER="${EBUILD_INFO[VERSION]}"
            EBUILD="${EBUILD_INFO[EBUILD_FILE_NAME]}"
            OVERLAY="${EBUILD_INFO[OVERLAY]}"
            
            ATOM_OVERLAY_PATH="${OVERLAYS_PATH}/${OVERLAY}"
            
            EBUILD_PATH="${ATOM_OVERLAY_PATH}/${ATOM_CATEGORY}/${ATOM_NAME}/${EBUILD}.ebuild"
            PYTHON_COMPAT=$(getPythonCompatFromFile ${EBUILD_PATH})

            log_debug \
                "Ebuild: ${EBUILD_PATH}"\
                "Python: ${PYTHON_COMPAT}"
    
            MATCHED_ATOM="\U1FBC4"
            MATCHED_ATOM_VER="\U1FBC4"
            if [[ ! -z "${VER}" ]] ; then
                MATCHED_ATOM="${ATOM_CATEGORY}/${ATOM_NAME}"
                MATCHED_ATOM_VER="${VER}"
            fi
    
            LINES+=("portage atom: ${MATCHED_ATOM} ${VER}")
            
            LEV=$(levenshtein "${ATOM_NAME}" "${PACKAGE_NAME}")
            
            if [[ -z "${CLOSEST_LEV}" || $CLOSEST_LEV -gt $LEV ]] ; then
                CLOSEST_LEV=$LEV
                CLOSEST_ATOM="${MATCHED_ATOM}"
                CLOSEST_ATOM_VER=$MATCHED_ATOM_VER
            fi

            if [[ $ATOM_NAME == "gimp" ]] ; then
                log_debug \
                    "Atom: $ATOM"\
                    "Package: $PACKAGE_NAME"\
                    "Category: $ATOM_CATEGORY"\
                    "Name: $ATOM_NAME"\
                    "Slot: $ATOM_SLOT"\
                    "Overlay: $ATOM_OVERLAY"\
                    "Version: $VER"\
                    "Ebuild: $EBUILD"\
                    "Python: $PYTHON_COMPAT"\
                    "Matched atom: $MATCHED_ATOM"\
                    "Matched atom version: $MATCHED_ATOM_VER"\
                    "Levenshtein value: $LEV"\
                    "Closest atom: $CLOSEST_ATOM"\
                    "Closest atom version: $CLOSEST_ATOM_VER"\
                    "Closest Levenshtein value: $CLOSEST_LEV"
            fi
        done

        UPGRADE=
        FILES="${PACKAGES_INFO_FILE}"
        if [[ -z ${CLOSEST_ATOM_VER} ]] ; then
            # No match, mark with 🯄
            UPGRADE=" \U1F86D \U1FBC4"
            FILES="${PACKAGES_INFO_FILE} ${PACKAGES_UP_FILE}"
        else
            if [[ ${ATOM_VERSION} != ${CLOSEST_ATOM_VER} ]] ; then
                UPGRADE=" \U1F86D ${CLOSEST_ATOM_VER}"
                FILES="${PACKAGES_INFO_FILE} ${PACKAGES_UP_FILE}"
            fi
        fi
        
        ATOMS_FLAVORS_FORMATTED="${ATOMS_FLAVORS//|/(}"
        if [[ ! -z "${ATOMS_FLAVORS_FORMATTED}" ]] ; then
            ATOMS_FLAVORS_FORMATTED="${ATOMS_FLAVORS_FORMATTED// /) })"
        fi
        
        LINES=("package: ${PACKAGE_CATEGORY_NAME}\npackage version: ${PACKAGE_VERSION}${UPGRADE}\natoms: ${ATOMS}\natom version: ${ATOM_VERSION}\natoms flavors: ${ATOMS_FLAVORS_FORMATTED}\noverlays: ${OVERLAYS}" "${LINES[@]}")
        if [[ ! -z "${PYTHON_COMPAT}" ]] ; then
            LINES+=("python: ${PYTHON_COMPAT}")
        fi
        
        for LINE in "${LINES[@]}" ; do
            #echo -e "${LINE}" | tee -a $FILES > /dev/null
            output "${FILES}" "${LINE}"
        done
        
        #echo -e "" | tee -a $FILES > /dev/null
        output "${FILES}" ""
    done

done

echo -e "\n\e\033[5;32;1mDone!\e[0m\n"
