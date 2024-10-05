#!/bin/bash

set -e

PREFIX="/usr"
BUILD=false
INSTALL=false
REFRESH=false

# Parse command line arguments
while (("$#")); do
    case "$1" in
    --prefix)
        PREFIX="$2"
        shift 2
        ;;
    --build)
        BUILD=true
        shift
        ;;
    --install)
        INSTALL=true
        shift
        ;;
    --refresh)
        REFRESH=true
        shift
        ;;
    *)
        echo "Error: Invalid argument"
        exit 1
        ;;
    esac
done

if [[ "${BUILD}" == "true" ]]; then
    if [[ -z "${SUDO_USER}" ]]; then
        THEUSER="${USER}"
        cargo build --release
    else
        THEUSER="${SUDO_USER}"
        echo "Detected as sudo. Build as normal user: ${SUDO_USER}"
        su "${SUDO_USER}" -c "cargo build --release"
    fi
fi

PREFIX="${PREFIX%/}"

if [[ "${INSTALL}" == "true" ]]; then
    echo "Install in '${PREFIX}'" &&
        mkdir -p "${PREFIX}" &&
        mkdir -p "${PREFIX}/bin" &&
        mkdir -p "${PREFIX}/lib/systemd/user" &&
        mkdir -p "${PREFIX}/env" &&
        install ./target/release/i3-autolayout "${PREFIX}/bin" &&
        sed "s#ExecStart=i3-autolayout#ExecStart=${PREFIX}/bin/i3-autolayout#g" \
            ./systemd/i3-autolayout.service \
            >"${PREFIX}/lib/systemd/user/i3-autolayout.service" &&
        sed "s#AUTOLAYOUT_BIN_DIR=%%%#AUTOLAYOUT_BIN_DIR=${PREFIX}/bin#g" \
            ./env/env \
            >"${PREFIX}/env/env"
fi

if [[ "${REFRESH}" == "true" ]]; then
    THEHOME=$(eval echo "~${THEUSER}")

    read -r -p "Source environment for user '${THEUSER}'? [y/N]: " ans
    case "${ans}" in
    [yY])
        line=". \"${PREFIX}/env/env\""
        envs=".profile .bashrc"

        for vv in ${envs}; do
            file="${THEHOME}/${vv}"
            if [[ -f "${file}" ]]; then
                if ! grep -Fxq "${line}" "${file}"; then
                    echo -e "\n${line}" >>"${file}"
                    echo "  Sourced file '${file}'"
                fi
            fi
        done
        ;;
    *) ;;
    esac
fi
