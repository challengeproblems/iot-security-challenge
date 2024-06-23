{ pkgs, config, lib, ... }:
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
    util-linuxMinimal
    which
    rsync
    mktemp

    micropython
    esptool
    picocom
    rshell
    mpfshell
    parallel

    nixpkgs-fmt
    black
    isort

    thc-hydra
    nmap
    iftop
    gzip
    gocryptfs
    tcpdump
    file
    netcat
    unzip

    cachix
  ]);

  scripts.devenv_ready = {
    description = "Tests if the devenv is ready";
    exec = ''
      echo "[+] Devenv Ready!"
    '';
  };

  scripts.flash_erase = {
    description = "Set ESP32 flash to all 0x0 bytes";
    exec = ''
      set -exuo pipefail

      tty="''${1:-$(util_get_first_usbtty)}"
      esptool.py \
        --port "''${tty}" \
        erase_flash
    '';
  };

  scripts.util_get_first_usbtty = {
    description = "Get the first available /dev/ttyUSB*";
    exec = ''
      pattern="/dev/ttyUSB*"
      ttys=( $pattern )
      printf '%q' "''${ttys[0]}"
    '';
  };

  scripts.util_getchip = {
    description = "Get the chip info for the connected ESP32";
    exec = ''
      set -euo pipefail

      tty="''${1:-$(util_get_first_usbtty)}"
      esptool.py \
        --port "''${tty}" \
        read_mac \
      | sed -nre 's/Chip is ([^ ]+).*/\1/p' \
      | tr '[:upper:]' '[:lower:]'
    '';
  };

  scripts.flash = {
    description = "Flash your ESP32 with clean Micropython firmware";
    exec = ''
      set -exuo pipefail

      tty="''${1:-$(util_get_first_usbtty)}"
      (
        cd "''${DEVENV_ROOT}"
        set -x

        chip_id="''$(util_getchip "''${tty}")"

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
  };

  scripts.repl = {
    description = "Start an interactive read eval print loop from the connected ESP32";
    exec = ''
      set -exuo pipefail

      tty="''${1:-$(util_get_first_usbtty)}"
      picocom \
        -b115200 \
        "''${tty}"
    '';
  };

  scripts.repl_peek = {
    description = "Show serial logs from the connected ESP32";
    exec = ''
      set -exuo pipefail

      tty="''${1:-$(util_get_first_usbtty)}"
      sleep infinity | repl "''${tty}"
    '';
  };

  scripts.fs = {
    description = "Browse the file system from the connected ESP32";
    exec = ''
      set -exuo pipefail

      tty="''${1:-$(util_get_first_usbtty)}"
      tty_name="''$(basename "''${tty}")"
      mpfshell \
        "''${tty_name}"
    '';
  };

  scripts.alltty = {
    description = "Run a command on all connected ESP32's";
    exec = ''
      set -exuo pipefail

      export ALLTTY=true
      parallel \
        --env ALLTTY \
        --will-cite \
        --tagstring "[{/.}]" \
        --line-buffer \
        --halt now,fail=1 \
        "''${@} {}" ::: /dev/ttyUSB*
    '';
  };

  scripts.upload = {
    description = "Upload the content of your src/ directory to the connected ESP32";
    exec = ''
      set -exuo pipefail

      tty="''${1:-$(util_get_first_usbtty)}"
      (
        cd "''${DEVENV_ROOT}"
        rshell \
          --port "''${tty}" \
          --file ./flash.cmds
      )
    '';
  };

  scripts.upload_lab = {
    description = "Upload a lab in labs/ to the connected ESP32";
    exec = ''
      set -euo pipefail

      lab="''${1?Missing lab as first parameter}"
      tty="''${2:-$(util_get_first_usbtty)}"
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
  };

  scripts.firmware_mk = {
    description = "Build the OTA firmware from src/";
    exec = ''
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

        util_freezefs \
          --target=/ \
          --on-import=extract \
          --overwrite=always \
          --compress \
          "''${fw_tmp}" \
          "ota_firmware.py"
      )
    '';
  };

  scripts.flash_final_lab = {
    description = "Do all steps required to get the final lab on the ESP32";
    exec = ''
      set -exuo pipefail

      tty="''${1:-$(util_get_first_usbtty)}"

      if ! firmware_mount_check; then
        firmware_mount
        trap firmware_umount EXIT
      fi


      flash_erase "''${tty}"
      flash "''${tty}"

      upload "''${tty}"
    '';
  };

  scripts.alltty_flash_final_lab = {
    description = "For all connected tty: Do all steps required to get the final lab on the ESP32";
    exec = ''
      set -euo pipefail

      firmware_mount
      trap firmware_umount EXIT

      alltty flash_final_lab
    '';
  };

  scripts.lab_portmap = {
    description = "Scan ports on the firmware";
    exec = ''
      set -exuo pipefail

      (
        cd "''${DEVENV_ROOT}"
        nmap 192.168.4.1
      )
    '';
  };

  scripts.lab_bforce = {
    description = "Bruteforce passwords for the firmware's webui";
    exec = ''
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
  };

  scripts.cachix_push = {
    description = "Push nix artifacts to cachix";
    exec = ''
      set -exuo pipefail

      (
        cd "''${DEVENV_ROOT}"
        cachix push "${CACHIX_CACHE}" "''${DEVENV_PROFILE}"
      )
    '';
  };

  scripts.devenv_uninstall = {
    description = "Print instructions on how to uninstall nix";
    exec = ''
      echo "[*] See: https://nix.dev/manual/nix/2.22/installation/uninstall#multi-user"
    '';
  };

  scripts.util_freezefs = {
    description = "https://github.com/bixb922/freezefs";
    exec = ''
      python -m freezefs "''${@}"
    '';
  };

  scripts.lab_dns_amp = {
    description = "Run the dns amplification attack";
    exec = ''
      set -exuo pipefail

      (
        cd "''${DEVENV_ROOT}"
        sudo python dns_amp.py "''${@}"
      )
    '';
  };

  scripts.lab_monitor_network = {
    description = "Show network statistics";
    exec = ''
      set -exuo pipefail

      interface="''${1?Missing interface argument}"
      (
        cd "''${DEVENV_ROOT}"
        sudo iftop -i "''${interface}"
      )
    '';
  };

  scripts.util_zlib_uncompress = {
    description = "Uncompress zlib data from stdin";
    exec = ''
      printf "\x1f\x8b\x08\x00\x00\x00\x00\x00" \
      | cat - "''${1}" \
      | gzip -dc
    '';
  };

  scripts.devenv_reset_update = {
    description = "Reset and update the devenv";
    exec = ''
      echo "============= WARNING =============="
      echo "This will reset and update your devenv"
      echo "You will loose all your changes in ''${DEVENV_ROOT}"
      echo "Hit ENTER to continue"
      echo "[ENTER]"
      read

      set -exuo pipefail
      (
        cd "''${DEVENV_ROOT}"
        git reset --hard origin/master
        git clean -f -f -d -x
        git pull
      )
    '';
  };

  scripts.firmware_mount_check = {
    description = "Checks if the secret firmware directory is mounted";
    exec = ''
      set -exuo pipefail

      dir="''${1:-src/}"
      (
        cd "''${DEVENV_ROOT}"
        findmnt -M "''${dir}" &>/dev/null
      )
    '';
  };

  scripts.firmware_mount = {
    description = "Mount the secret firmware directory";
    exec = ''
      set -exuo pipefail

      dir="''${1:-src/}"
      (
        cd "''${DEVENV_ROOT}"
        if ! firmware_mount_check "''${dir}"; then
          gocryptfs -nonempty src_encrypted/ "''${dir}"
        fi
      )
    '';
  };

  scripts.firmware_umount = {
    description = "Unmount the secret firmware directory";
    exec = ''
      set -exuo pipefail

      dir="''${1:-src/}"
      (
        cd "''${DEVENV_ROOT}"
        if firmware_mount_check "''${dir}"; then
          fusermount -u "''${dir}"
        fi
      )
    '';
  };

  scripts.firmware_extract_to_src = {
    description = "Extract a fresh copy of the original firmware to src/";
    exec = ''
      set -euo pipefail

      echo "============= WARNING =============="
      echo "This will overwrite all your changes in src/"
      echo "Hit ENTER to continue"
      echo "[ENTER]"
      read

      fw_tmp="$(mktemp -d)"

      atexit(){
        firmware_umount "''${fw_tmp}"
      }

      if ! firmware_mount_check "''${fw_tmp}"; then
        firmware_mount "''${fw_tmp}"
        trap atexit EXIT
      fi

      (
        cd "''${DEVENV_ROOT}"

        rsync \
          --archive \
          --verbose \
          "''${fw_tmp}/" \
          src/
      )
    '';
  };

  scripts.devenv_help = {
    description = "Print this help";
    exec = ''
      echo
      echo Helper scripts you can run to make your development richer:
      echo
      sed -e 's| |XXXXXX|g' -e 's|=| |' <<EOF | column -t | sed -e 's|^|- |' -e 's|XXXXXX| |g'
      ${lib.generators.toKeyValue {} (lib.mapAttrs (name: value: value.description) config.scripts)}
      EOF
      echo
    '';
  };

  scripts.lint_code = {
    description = "Lint and fix python source code";
    exec = ''
      set -exuo pipefail

      dir="''${1:-src/}"
      (
        cd "''${DEVENV_ROOT}"

        isort "''${dir}"
        black "''${dir}"
      )
    '';
  };

  scripts.inspect_command = {
    description = "Inspects a command, example inspect_command COMMAND";
    exec = ''
      set -euo pipefail

      cmd="''${1?Missing command as first parameter}"
      (
        cd "''${DEVENV_ROOT}"

        cmd_path="''$(which "''${cmd}" 2>/dev/null || true)"
        if [ -z "''${cmd_path}" ]; then
          1>&2 echo "[!] Unknown command ''${cmd}"
          exit 1
        fi

        echo "============ Code for ''${cmd} =============="
        cat "''${cmd_path}"
        echo "============================================="
      )
    '';
  };

  enterShell = ''
    devenv_help
  '';

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
