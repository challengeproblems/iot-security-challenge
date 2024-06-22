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
    gocryptfs

    thc-hydra
    nmap
    iftop
    gzip
    unzip

    cachix
  ]);

  scripts.devenv_ready = {
    description = "Tests if the devenv is ready";
    exec = ''
      echo "[+] Devenv Ready!"
    '';
  };

  scripts.erase_flash = {
    description = "Set esp32 flash to all 0x0";
    exec = ''
      set -exuo pipefail

      tty="''${1:-/dev/ttyUSB0}"
      esptool.py \
        --port "''${tty}" \
        erase_flash
    '';
  };

  scripts.getchip = {
    description = "Get the chip info for the connected esp32";
    exec = ''
      set -euo pipefail

      tty="''${1:-/dev/ttyUSB0}"
      esptool.py \
        --port "''${tty}" \
        read_mac \
      | sed -nre 's/Chip is ([^ ]+).*/\1/p' \
      | tr '[:upper:]' '[:lower:]'
    '';
  };

  scripts.flash = {
    description = "Flash your esp32 with clean Micropython firmware";
    exec = ''
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
  };

  scripts.repl = {
    description = "Start an interactive read eval print loop from the connected esp32";
    exec = ''
      set -exuo pipefail

      tty="''${1:-/dev/ttyUSB0}"
      picocom \
        -b115200 \
        "''${tty}"
    '';
  };

  scripts.repl_peek = {
    description = "Show serial logs from the connected esp32";
    exec = ''
      set -exuo pipefail

      tty="''${1:-/dev/ttyUSB0}"
      sleep infinity | repl "''${tty}"
    '';
  };

  scripts.fs = {
    description = "Browse the file system from the connected esp32";
    exec = ''
      set -exuo pipefail

      tty="''${1:-/dev/ttyUSB0}"
      tty_name="''$(basename "''${tty}")"
      mpfshell \
        "''${tty_name}"
    '';
  };

  scripts.alltty = {
    description = "Run a command on all connected esp32's";
    exec = ''
      set -exuo pipefail

      parallel \
        --will-cite \
        --tagstring "[{/.}]" \
        --line-buffer \
        --halt now,fail=1 \
        "''${@} {}" ::: /dev/ttyUSB*
    '';
  };

  scripts.upload = {
    description = "Upload the content of your src/ directory to the connected esp32";
    exec = ''
      set -exuo pipefail

      tty="''${1:-/dev/ttyUSB0}"
      (
        cd "''${DEVENV_ROOT}"
        rshell \
          --port "''${tty}" \
          --file ./flash.cmds
      )
    '';
  };

  scripts.upload_lab = {
    description = "Upload a lab in labs/ to the connected esp32";
    exec = ''
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
  };

  scripts.mkfirmware = {
    description = "Build the ota firmware from the content of src/";
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

        freezefs \
          --target=/ \
          --on-import=extract \
          --overwrite=always \
          --compress \
          "''${fw_tmp}" \
          "ota_firmware.py"
      )
    '';
  };

  scripts.clean_setup = {
    description = "Do all steps required to get the firmware on the esp32";
    exec = ''
      set -exuo pipefail

      tty="''${1:-/dev/ttyUSB0}"

      erase_flash "''${tty}"
      flash "''${tty}"
      mkfirmware "''${tty}"
      upload "''${tty}"
    '';
  };

  scripts.portmap = {
    description = "Scan ports on the firmware";
    exec = ''
      set -exuo pipefail

      (
        cd "''${DEVENV_ROOT}"
        nmap 192.168.4.1
      )
    '';
  };

  scripts.bforce = {
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

  scripts.uninstall_nix = {
    description = "Print instructions on how to uninstall nix";
    exec = ''
      echo "[*] See: https://nix.dev/manual/nix/2.22/installation/uninstall#multi-user"
    '';
  };

  scripts.freezefs = {
    description = "https://github.com/bixb922/freezefs";
    exec = ''
      python -m freezefs "''${@}"
    '';
  };

  scripts.dns_amp = {
    description = "Run the dns amplification attack";
    exec = ''
      set -exuo pipefail

      (
        cd "''${DEVENV_ROOT}"
        sudo python dns_amp_solved.py "''${@}"
      )
    '';
  };

  scripts.monitor_network = {
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

  scripts.zlib_uncompress = {
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
      echo "You will loose all your changes"
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

  scripts.mount_firmware = {
    description = "Mount the secret firmware directory";
    exec = ''
      set -exuo pipefail
      (
        cd "''${DEVENV_ROOT}"
        gocryptfs -nonempty src_encrypted/ src/
      )
    '';
  };

  scripts.unmount_firmware = {
    description = "Unmount the secret firmware directory";
    exec = ''
      set -exuo pipefail
      (
        cd "''${DEVENV_ROOT}"
        umount src/
      )
    '';
  };

  scripts.devenv_help = {
    description = "Print this help";
    exec = ''
      echo
      echo Helper scripts you can run to make your development richer:
      echo
      ${pkgs.gnused}/bin/sed -e 's| |••|g' -e 's|=| |' <<EOF | ${pkgs.util-linuxMinimal}/bin/column -t | ${pkgs.gnused}/bin/sed -e 's|^|- |' -e 's|••| |g'
      ${lib.generators.toKeyValue {} (lib.mapAttrs (name: value: value.description) config.scripts)}
      EOF
      echo
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
