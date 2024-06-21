{ pkgs, ... }:
let
  CACHIX_CACHE = "duckpond";
in
{

  # https://devenv.sh/basics/
  cachix = {
    pull = "${CACHIX_CACHE}";
    push = "${CACHIX_CACHE}";
  };

  # https://devenv.sh/packages/
  packages = (with pkgs; [
    git
    gnused
    coreutils
    rsync

    micropython
    esptool
    picocom
    rshell
    mpfshell
    parallel

    nixpkgs-fmt
    black

    iw
    wirelesstools

    thc-hydra
    nmap
    iftop
    gzip
    unzip

    cachix
  ]);

  scripts.devenv_ready.exec = ''
    echo "[+] Devenv Ready!"
  '';

  scripts.erase_flash.exec = ''
    set -exuo pipefail

    tty="''${1:-/dev/ttyUSB0}"
    esptool.py \
      --port "''${tty}" \
      erase_flash
  '';

  scripts.getchip.exec = ''
    set -euo pipefail

    tty="''${1:-/dev/ttyUSB0}"
    esptool.py \
      --port "''${tty}" \
      read_mac \
    | sed -nre 's/Chip is ([^ ]+).*/\1/p' \
    | tr '[:upper:]' '[:lower:]'
  '';

  scripts.flash.exec = ''
    set -exuo pipefail

    tty="''${1:-/dev/ttyUSB0}"
    (
      cd "''${DEVENV_ROOT}"
      set -x

      chip_id="''$(getchip "''${tty}")"

      declare -A chip_name=( \
        ["esp32-c3"]="esp32-c3" \
        ["esp32-d0wd"]="esp32" \
        ["esp32-d0wd-v3"]="esp32" \
      )

      declare -A chip_fw=( \
        ["esp32-c3"]="${./firmware/ESP32_GENERIC_C3-20240602-v1.23.0.bin}" \
        ["esp32-d0wd"]="${./firmware/ESP32_GENERIC-20240602-v1.23.0.bin}" \
        ["esp32-d0wd-v3"]="${./firmware/ESP32_GENERIC-20240602-v1.23.0.bin}" \
      )

      declare -A chip_addr=( \
        ["esp32-c3"]="0x0" \
        ["esp32-d0wd"]="0x1000" \
        ["esp32-d0wd-v3"]="0x1000" \
      )

      esptool.py \
        --chip "''${chip_name["''$chip_id"]}" \
        --port "''${tty}" \
        --baud 460800 \
        write_flash \
          --compress \
          "''${chip_addr["''$chip_id"]}" \
          "''${chip_fw["''$chip_id"]}"
    )
  '';

  scripts.repl.exec = ''
    set -exuo pipefail

    tty="''${1:-/dev/ttyUSB0}"
    picocom \
      -b115200 \
      "''${tty}"
  '';

  scripts.repl_peek.exec = ''
    set -exuo pipefail

    tty="''${1:-/dev/ttyUSB0}"
    sleep infinity | repl "''${tty}"
  '';

  scripts.fs.exec = ''
    set -exuo pipefail

    tty="''${1:-/dev/ttyUSB0}"
    tty_name="''$(basename "''${tty}")"
    mpfshell \
      "''${tty_name}"
  '';

  scripts.alltty.exec = ''
    set -exuo pipefail

    parallel \
      --will-cite \
      --tagstring "[{/.}]" \
      --line-buffer \
      --halt now,fail=1 \
      "''${@} {}" ::: /dev/ttyUSB*
  '';

  scripts.upload.exec = ''
    set -exuo pipefail

    tty="''${1:-/dev/ttyUSB0}"
    (
      cd "''${DEVENV_ROOT}"
      rshell \
        --port "''${tty}" \
        --file ./flash.cmds
    )
  '';

  scripts.upload_lab.exec = ''
    set -euo pipefail

    lab="''${1?Missing lab as first parameter}"
    tty="''${2:-/dev/ttyUSB0}"
    (
      cd "''${DEVENV_ROOT}"
      if [[ ! -e "labs/''${lab}" ]]; then
        1>&2 echo "[!] Lab: ''${lab} does not exist"
        exit 1
      fi
      echo "''${lab}" > labs/labselector.txt
      rshell \
        --port "''${tty}" \
        --file ./flash_lab.cmds
    )
  '';

  scripts.mkfirmware.exec = ''
    set -exuo pipefail

    (
      cd "''${DEVENV_ROOT}/src"
      fw_tmp="$(mktemp -d)"

      atexit(){
        rm -rf "''${fw_tmp}"
      }
      trap atexit EXIT

      PYTHONDONTWRITEBYTECODE=1 \
        python fw_meta.py

      rsync \
        --archive \
        --verbose \
        --exclude="ota_firmware.py" \
        *.py *.json www \
        "''${fw_tmp}"

      freezefs \
        --target=/ \
        --on-import=extract \
        --overwrite=always \
        --compress \
        "''${fw_tmp}" \
        "ota_firmware.py"
    )
  '';

  scripts.clean_setup.exec = ''
    set -exuo pipefail

    tty="''${1:-/dev/ttyUSB0}"

    erase_flash "''${tty}"
    flash "''${tty}"
    mkfirmware "''${tty}"
    upload "''${tty}"
  '';

  scripts.doalll.exec = ''
    set -exuo pipefail

    tty="''${1:-/dev/ttyUSB0}"

    clean_setup "''${tty}"
    repl "''${tty}"
  '';

  scripts.portmap.exec = ''
    set -exuo pipefail

    (
      cd "''${DEVENV_ROOT}"
      set -x
      nmap 192.168.4.1
    )
  '';

  scripts.bforce.exec = ''
    set -exuo pipefail

    (
      cd "''${DEVENV_ROOT}"
      set -x
      hydra \
        -I \
        -t 1 \
        -l admin \
        -P "${./10000_common_passwords}" \
        http-get://192.168.4.1
    )
  '';

  scripts.cachix_push.exec = ''
    set -exuo pipefail

    (
      cd "''${DEVENV_ROOT}"
      cachix push "${CACHIX_CACHE}" "''${DEVENV_PROFILE}"
    )
  '';

  scripts.uninstall_nix.exec = ''
    set -exuo pipefail

    (
      cd "''${DEVENV_ROOT}"
      echo "[*] See: https://nix.dev/manual/nix/2.22/installation/uninstall#multi-user"
    )
  '';

  scripts.freezefs.exec = ''
    python -m freezefs "''${@}"
  '';

  scripts.dns_amp.exec = ''
    set -exuo pipefail

    (
      cd "''${DEVENV_ROOT}"
      sudo python dns_amp_solved.py "''${@}"
    )
  '';

  scripts.monitor_network.exec = ''
    set -exuo pipefail

    (
      cd "''${DEVENV_ROOT}"
      sudo iftop "''${@}"
    )
  '';

  scripts.zlib_uncompress.exec = ''
    printf "\x1f\x8b\x08\x00\x00\x00\x00\x00" \
    | cat - "''${1}" \
    | gzip -dc
  '';


  #enterShell = ''
  #'';

  # https://devenv.sh/languages/
  languages.nix.enable = true;
  languages.python = {
    enable = true;
    poetry = {
      enable = true;
      activate.enable = true;
    };
  };

  # https://devenv.sh/pre-commit-hooks/
  pre-commit.hooks = {
    black.enable = true;
    isort.enable = true;
    nixpkgs-fmt.enable = true;
    shellcheck.enable = true;
  };

  # https://devenv.sh/processes/
  # processes.ping.exec = "ping example.com";

  # See full reference at https://devenv.sh/reference/options/
}
