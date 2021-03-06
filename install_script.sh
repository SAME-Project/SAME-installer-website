#!/usr/bin/env bash

# SAME authors (c)

# Original copyright
# https://raw.githubusercontent.com/dapr/cli/master/install/install.sh
# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation and Dapr Contributors.
# Licensed under the MIT License.
# ------------------------------------------------------------

# SAME CLI location
: ${SAME_INSTALL_DIR:="/usr/local/bin"}

# sudo is required to copy binary to SAME_INSTALL_DIR for linux
: ${USE_SUDO:="false"}

# Http request CLI
SAME_HTTP_REQUEST_CLI=curl

# GitHub Organization and repo name to download release
# GITHUB_ORG=same-project
# GITHUB_REPO=same-cli
GITHUB_ORG=SAME-Project
GITHUB_REPO=SAMPLE-CLI-TESTER

# SAME CLI filename
SAME_CLI_FILENAME=same

SAME_CLI_FILE="${SAME_INSTALL_DIR}/${SAME_CLI_FILENAME}"

SAME_PUBLIC_KEY=`echo "$(cat <<-END
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEApfC/EM/FbSvyohVyrAiI
53hGnEP4pwaQDRUA0YTM30h4Qf9CIzApaR/Ce9dDJbP2Vzopc4rK53EiVoBnRsni
vbs4XdL50wUbzNS9MvdNyltzVYCICbIwgbTAqoDboDpS6k5SjUk9itp9hkt6mgrp
RDJgM8/9fYezuIu+mxFPRzy95401nzMdulenqFZ5GdyVG7CTGmxoETeIgqACP0te
8Q/zI39rUV6M6WUKvTK/mqLvWf8j8koFg1GHroGxjwa4wL6MBi5UBr3ZTBikTZba
RdTH6TBbB8SwMZrQEAQILMpZTk9Z6pou7FYwK71q+d4fIr3PGkWHmCXd9GoloyZ7
edIer55MwqT4+dfpAYHFtCj9+gynUiLE4syaI33Qx9i7knU60bWYIRJqq4/gcoQ7
c2SNEVvrVyDF/xjVc/2rWMZ0bNwXtRNK/dLx0RPINxZcV6dFF8LzLvfCnVdSgQBG
i1zY6rN+s0Ukg9MVrrJkWJ30T2+t5KBZ/I3fotsq0qc0iS6o+e8yangB1Ygh35Hz
GLcVDuOdmNdqxmwX+mvyEKaixyX6j0tmO7Y9leJBFOU6D862hKDoyv8wq/MUNhUm
1C/LxcC8dwD1BZo6DbKmwjlGvEyw5KytpYYotJvJzkT8BGy/vs0fiu1PZWQvaare
aVo2HbqxcOujLmExBGFJBIkCAwEAAQ==
-----END PUBLIC KEY-----
END
)"`

getSystemInfo() {
    ARCH=$(uname -m)
    case $ARCH in
        armv7*) ARCH="arm" ;;
        aarch64) ARCH="arm64" ;;
        x86_64) ARCH="amd64" ;;
    esac

    OS=$(echo `uname`|tr '[:upper:]' '[:lower:]')

    # Most linux distro needs root permission to copy the file to /usr/local/bin
    if [ "$OS" == "linux" ] && [ "$SAME_INSTALL_DIR" == "/usr/local/bin" ]; then
        USE_SUDO="true"
    fi
}

verifySupported() {
    local supported=(darwin-amd64 linux-amd64)
    local current_osarch="${OS}-${ARCH}"

    for osarch in "${supported[@]}"; do
        if [ "$osarch" == "$current_osarch" ]; then
            echo "Your system is ${OS}_${ARCH}"
            return
        fi
    done

    echo "No prebuilt binary for ${current_osarch}"
    exit 1
}

runAsRoot() {
    local CMD="$*"

    if [ $EUID -ne 0 -a $USE_SUDO = "true" ]; then
        CMD="sudo $CMD"
    fi

    $CMD
}

checkHttpRequestCLI() {
    if type "curl" > /dev/null; then
        SAME_HTTP_REQUEST_CLI=curl
    elif type "wget" > /dev/null; then
        SAME_HTTP_REQUEST_CLI=wget
    else
        echo "Either curl or wget is required"
        exit 1
    fi
}

checkExistingSame() {
    if [ -f "$SAME_CLI_FILE" ]; then
        echo -e "\nSAME CLI is detected:"
        $SAME_CLI_FILE --version
        echo -e "Reinstalling SAME CLI - ${SAME_CLI_FILE}..."
    else
        echo -e "No SAME detected. Installing fresh SAME CLI..."
    fi
}

getLatestRelease() {
    local sameReleaseUrl="https://api.github.com/repos/${GITHUB_ORG}/${GITHUB_REPO}/releases"
    local latest_release=""

    if [ "$SAME_HTTP_REQUEST_CLI" == "curl" ]; then
        latest_release=$(curl -s $sameReleaseUrl | grep \"tag_name\" | grep -v rc | awk 'NR==1{print $2}' |  sed -n 's/\"\(.*\)\",/\1/p')
    else
        latest_release=$(wget -q --header="Accept: application/json" -O - $sameReleaseUrl | grep \"tag_name\" | grep -v rc | awk 'NR==1{print $2}' |  sed -n 's/\"\(.*\)\",/\1/p')
    fi

    ret_val=$latest_release
}
# --- create temporary directory and cleanup when done ---
setup_tmp() {
    SAME_TMP_ROOT=$(mktemp -dt dapr-install-XXXXXX)
    SAME_TMP_ROOT=$(mktemp -d 2>/dev/null || mktemp -d -t 'same-install.XXXXXXXXXX')
    cleanup() {
        code=$?
        set +e
        trap - EXIT
        rm -rf ${SAME_TMP_ROOT}
        exit $code
    }
    trap cleanup INT EXIT
}

downloadFile() {
    LATEST_RELEASE_TAG=$1

    SAME_CLI_ARTIFACT="${SAME_CLI_FILENAME}_${LATEST_RELEASE_TAG}_${OS}_${ARCH}.tar.gz"
    SAME_SIG_ARTIFACT="${SAME_CLI_ARTIFACT}.signature.sha256"

    DOWNLOAD_BASE="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download"

    CLI_DOWNLOAD_URL="${DOWNLOAD_BASE}/${LATEST_RELEASE_TAG}/${SAME_CLI_ARTIFACT}"
    SIG_DOWNLOAD_URL="${DOWNLOAD_BASE}/${LATEST_RELEASE_TAG}/${SAME_SIG_ARTIFACT}"

    CLI_TMP_FILE="$SAME_TMP_ROOT/$SAME_CLI_ARTIFACT"
    SIG_TMP_FILE="$SAME_TMP_ROOT/$SAME_SIG_ARTIFACT"

    echo "Downloading $CLI_DOWNLOAD_URL ..."
    if [ "$SAME_HTTP_REQUEST_CLI" == "curl" ]; then
        curl -SsLN "$CLI_DOWNLOAD_URL" -o "$CLI_TMP_FILE"
    else
        wget -q -O "$CLI_TMP_FILE" "$CLI_DOWNLOAD_URL"
    fi

    if [ ! -f "$CLI_TMP_FILE" ]; then
        echo "failed to download $CLI_DOWNLOAD_URL ..."
        exit 1
    fi

    echo "Downloading sig file $SIG_DOWNLOAD_URL ..."
    if [ "$SAME_HTTP_REQUEST_CLI" == "curl" ]; then
        curl -SsLN "$SIG_DOWNLOAD_URL" -o "$SIG_TMP_FILE"
    else
        wget -q -O "$SIG_TMP_FILE" "$SIG_DOWNLOAD_URL"
    fi

    if [ ! -f "$SIG_TMP_FILE" ]; then
        echo "failed to download $SIG_DOWNLOAD_URL ..."
        exit 1
    fi

}

verifyTarBall() {
    #echo "ROOT: $SAME_TMP_ROOT"
    #echo "Public Key: $SAME_PUBLIC_KEY"
    echo "$SAME_PUBLIC_KEY" > "$SAME_TMP_ROOT/SAME_public_file.pem"
    openssl base64 -d -in $SIG_TMP_FILE -out $SIG_TMP_FILE.decoded
    if openssl dgst -sha256 -verify "$SAME_TMP_ROOT/SAME_public_file.pem" -signature $SIG_TMP_FILE.decoded $CLI_TMP_FILE ; then
        return
    else
        echo "Failed to verify signature of tarball."
        exit 1
    fi
}

expandTarball() {
    echo "Extracting and verifying signature..."
    # echo "Extract tar file - $CLI_TMP_FILE to $SAME_TMP_ROOT"
    tar xzf $CLI_TMP_FILE -C $SAME_TMP_ROOT
}

verifyBin() {
    openssl base64 -d -in $SAME_TMP_ROOT/same.signature.sha256 -out $SAME_TMP_ROOT/same.signature.sha256.decoded
    if openssl dgst -sha256 -verify "$SAME_TMP_ROOT/SAME_public_file.pem" -signature $SAME_TMP_ROOT/same.signature.sha256.decoded $SAME_TMP_ROOT/same; then
        return
    else
        echo "Failed to verify signature of same binary."
        exit 1
    fi
}


installFile() {
    local tmp_root_same_cli="$SAME_TMP_ROOT/$SAME_CLI_FILENAME"

    if [ ! -f "$tmp_root_same_cli" ]; then
        echo "Failed to unpack Same CLI executable."
        exit 1
    fi

    chmod o+x $tmp_root_same_cli
    runAsRoot cp "$tmp_root_same_cli" "$SAME_INSTALL_DIR"

    if [ -f "$SAME_CLI_FILE" ]; then
        echo "$SAME_CLI_FILENAME installed into $SAME_INSTALL_DIR successfully."

        $SAME_CLI_FILE --version
    else
        echo "Failed to install $SAME_CLI_FILENAME"
        exit 1
    fi
}

fail_trap() {
    result=$?
    if [ "$result" != "0" ]; then
        echo "Failed to install SAME CLI"
        echo "For support, go to https://github.com/${GITHUB_ORG}/${GITHUB_REPO}"
    fi
    cleanup
    exit $result
}

cleanup() {
    if [[ -d "${SAME_TMP_ROOT:-}" ]]; then
        rm -rf "$SAME_TMP_ROOT"
    fi
}

installCompleted() {
    echo -e "\nTo get started with SAME, please visit https://github.com/${GITHUB_ORG}/${GITHUB_REPO}"
}

# -----------------------------------------------------------------------------
# main
# -----------------------------------------------------------------------------
trap "fail_trap" EXIT

getSystemInfo
verifySupported
checkExistingSame
checkHttpRequestCLI

if [ -z "$1" ]; then
    echo "Getting the latest SAME CLI..."
    getLatestRelease
else
    ret_val=v$1
fi

echo "Installing $ret_val SAME CLI..."

setup_tmp
downloadFile $ret_val
verifyTarBall
expandTarball
verifyBin
installFile
cleanup

installCompleted
