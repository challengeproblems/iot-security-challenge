#!/usr/bin/env bash
set -euo pipefail

NIXOS_CHANNEL="24.05"
NIX_CHANNEL="https://github.com/NixOS/nixpkgs/tarball/nixos-${NIXOS_CHANNEL}"
NIX_DAEMON="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"

CACHIX_CACHE="duckpond"

GIT_REPO_NAME="iot-security-challenge"
GIT_REPO_SRC="https://github.com/Enteee/${GIT_REPO_NAME}.git"
GIT_REPO_DST_FOLDER="${HOME}"
GIT_REPO_DST="${GIT_REPO_DST_FOLDER}/${GIT_REPO_NAME}"

ADD_USER_GROUP="dialout"

DISK_CHECK="/"
MIN_DISK_SPACE=5368709120 # 5 GiB

#
# Utils
#

check_cmd(){
    local cmd
    cmd="${1?Missing command}"
    if ! command -v "${cmd}" &>/dev/null; then
        1>&2 echo "[!] install '${cmd}' to run this script"
        exit 1
    fi
}

check_disk(){
  local disk_avilable
  disk_avilable="$(($(stat -f --format="%a*%S" "${DISK_CHECK}")))"
  if [[ "${disk_avilable}" -lt "${MIN_DISK_SPACE}" ]];then
        1>&2 echo "[!] required ${MIN_DISK_SPACE} bytes on ${DISK_CHECK}, got: ${disk_avilable}"
        exit 1
  fi
}

#
# Commands
#

user_ack(){
  cat <<EOF
==================================================
==== !!!! READ THIS BEFORE YOU CONTINUE !!!! =====
==================================================
This script will:
1) Install nix:    https://nixos.org/download/
2) Install devenv: https://devenv.sh/getting-started/
3) Install cachix: https://docs.cachix.org/installation
4) Install direnv: https://direnv.net/docs/installation.html
5) Add the user '${USER}' to the group '${ADD_USER_GROUP}'
6) Clone/Pull the repo at '${GIT_REPO_SRC}' to '${GIT_REPO_DST}'
7) Install all dependencies
8) reboot your system

Hints:
- This script can be run mutltiple times, if anything fails just try re-running the script.
- This script might require you to type your sudo password a few times
- Downloading all the artifacts might take some time

Hit ENTER to proceed, CTRL+C to abort
EOF
echo -n "[ENTER]"
read -r
}

check_system(){
    check_disk
    check_cmd git
    check_cmd curl
    check_cmd sudo
    check_cmd tee
    check_cmd usermod
    check_cmd cat
    if [[ ! -w "${GIT_REPO_DST_FOLDER}" ]]; then
        1>&2 echo "[!] ${GIT_REPO_DST_FOLDER} must be writable"
        exit 1
    fi
}


install_nix(){
    if [[ -f "/etc/nix/nix.conf" ]]; then
        echo "[.] nix is already installed"
        return
    fi
    echo "[*] installing nix"

    sh <(curl -L https://nixos.org/nix/install) --daemon --yes
}

install_devenv(){
    if command -v devenv &>/dev/null; then
        echo "[.] devenv is already installed"
        return
    fi
    echo "[*] installing devenv"

    nix-env -iA devenv -f "${NIX_CHANNEL}"
}

install_devenv_conf(){
    local nixconf
    nixconf="/etc/nix/nix.conf"

    local to_add
    to_add="trusted-users = root ${USER}"
    if grep -q "${to_add}" "${nixconf}"; then
        echo "[.] devenv already configured"
        return
    fi
    echo "[*] configuring devenv"

    echo "${to_add}" | sudo tee -a "${nixconf}"
    sudo systemctl restart nix-daemon
}

install_cachix(){
    if command -v cachix &>/dev/null; then
        echo "[.] cachix is already installed"
        return
    fi
    echo "[*] installing cachix"

    nix-env -iA cachix -f "${NIX_CHANNEL}"
}

configure_cachix(){
    echo "[*] configure cachix"
    cachix use "${CACHIX_CACHE}"
}

install_direnv(){
    if command -v direnv &>/dev/null; then
        echo "[.] direnv is already installed"
        return
    fi
    echo "[*] install direnv"

    nix-env -iA direnv -f "${NIX_CHANNEL}"
}

install_direnv_hook(){
    local bashrc
    bashrc="${HOME}/.bashrc"
    local to_add
    # shellcheck disable=SC2016
    to_add='eval "$(direnv hook bash)"'

    if grep -q "${to_add}" "${bashrc}"; then
        echo "[.] direnv is already hooked"
        return
    fi
    echo "[*] hooking direnv"

    echo "${to_add}" >> "${bashrc}"
}

clone_repo(){
    if [[ -d "${GIT_REPO_DST}" ]]; then
        echo "[.] repo already cloned"
        return
    fi
    echo "[*] cloning repo"

    git clone \
      "${GIT_REPO_SRC}" \
      "${GIT_REPO_DST}"
}

pull_repo(){
    echo "[*] pulling repo"
    (
        cd "${GIT_REPO_DST}"
        git pull || true
    )
}

install_dependencies(){
    echo "[*] installing dependencies"
    (
        cd "${GIT_REPO_DST}"
        direnv allow
        devenv shell devenv_ready
    )
}

adding_user_to_dialout(){
    echo "[*] adding user to dialout group"
    sudo usermod -a -G "${ADD_USER_GROUP}" "${USER}"
}

main(){
    check_system

    user_ack

    install_nix

    if ! command -v "nix" &>/dev/null; then
      # shellcheck disable=SC1090
      source "${NIX_DAEMON}"
    fi

    install_devenv
    install_devenv_conf

    install_cachix
    configure_cachix

    install_direnv
    install_direnv_hook
    eval "$(direnv hook bash)"

    adding_user_to_dialout

    clone_repo
    pull_repo

    install_dependencies

    cat<<EOF
[*] Installation complete!
==================================================
============ !!!! FINAL NOTES !!!! ===============
==================================================
When you hit ENTER your system will reboot
After reboot, open a new terminal and navigate to: ${GIT_REPO_DST}
EOF
    echo -n "[ENTER]"
    read -r
    sudo reboot
}
main
