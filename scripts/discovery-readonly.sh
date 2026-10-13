#!/usr/bin/env bash
# Phase 0 read-only discovery for nas.internal.
#
# This script ONLY READS system state. It does not write files, start SMART
# self-tests, change configuration, install packages, or refresh apt indexes.
# All output goes to stdout; redirect it on YOUR machine (Git Bash), e.g.:
#
#   mkdir -p discovery-raw
#   ssh <admin>@nas.internal 'sudo bash -s' < scripts/discovery-readonly.sh \
#       > discovery-raw/discovery-$(date +%F).txt 2>&1
#
# See scripts/README.md for the root / sudo-with-password / console cases.
#
# The output contains serial numbers, MAC and IP addresses. It is kept in
# discovery-raw/ (git-ignored). Only a reviewed summary goes into docs/.

set -u

section() { printf '\n==================== %s ====================\n' "$*"; }
run() { printf '\n$ %s\n' "$*"; "$@" 2>&1; }
have() { command -v "$1" >/dev/null 2>&1; }

section "Identity / OS"
run date -Is
run hostnamectl
run cat /etc/os-release
run uname -a
run dpkg-query -W -f='${Package} ${Version}\n' openmediavault
dpkg-query -W -f='${Package} ${Version}\n' 'openmediavault-*' 2>/dev/null
run uptime
run timedatectl

section "CPU / memory / board"
run lscpu
run free -h
if have dmidecode; then
  run dmidecode -t system -t baseboard -t bios
  run dmidecode -t memory
fi

section "PCI devices (GPU, storage controllers, NICs)"
if have lspci; then run lspci -nnk; fi
run ls -l /dev/dri
run ls /sys/class/ata_port

section "Block devices"
run lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,TRAN,ROTA,PHY-SEC,LOG-SEC,FSTYPE,LABEL,UUID,MOUNTPOINTS
run ls -l /dev/disk/by-id/
# -c /dev/null: never read or write the blkid cache file under /run.
run blkid -c /dev/null
# -p: low-level probe of each whole disk (bypasses the cache; finds stale signatures).
for dev in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'); do
  run blkid -p -o full "$dev"
done
run fdisk -l
run findmnt --real
run df -hT
run cat /etc/fstab

section "SMART (read-only: -x prints data, it does NOT start tests)"
if have smartctl; then
  run smartctl --scan
  for dev in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'); do
    run smartctl -x "$dev"
  done
else
  echo "smartctl not installed"
fi

section "OMV plugin availability (existing apt cache only, no index refresh)"
run apt-cache policy openmediavault-luksencryption openmediavault-mergerfs openmediavault-snapraid openmediavault-compose openmediavault-sharerootfs

section "Network"
run ip -br link
run ip -br addr
run ip route
run cat /etc/resolv.conf
run ss -tulpn

section "Services"
run systemctl --failed --no-pager
run systemctl list-units --type=service --state=running --no-pager
if have docker; then run docker version; run docker ps -a; else echo "docker: not installed"; fi
if have tailscale; then run tailscale status; else echo "tailscale: not installed"; fi

section "SSH effective config (read-only)"
if have sshd; then
  sshd -T 2>/dev/null | grep -Ei '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication|permitemptypasswords|x11forwarding|allowgroups|allowusers|listenaddress) '
fi

section "Users and groups (no password data)"
run getent passwd
run getent group

section "APT sources / pending updates (no index refresh)"
run ls -l /etc/apt/sources.list.d/
run apt list --upgradable

section "Firewall state"
if have nft; then run nft list ruleset; fi
if have iptables; then run iptables -S; fi

section "Recent errors (this boot)"
run journalctl -p err -b --no-pager -n 100

section "Done"
