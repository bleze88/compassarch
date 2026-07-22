#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="compass-arch"
iso_label="COMPASS_ARCH"
iso_publisher="Compass Arch Project <https://example.invalid>"
iso_application="Compass Arch Live/Install DVD"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  # Exécuté par Calamares (shellprocess@fixmkinitcpio, voir settings.conf) -
  # mkarchiso ne préserve PAS le bit exécutable des fichiers d'overlay lors
  # de la copie (cp --no-preserve=mode), d'où cette entrée explicite. Voir
  # docs/ARCHITECTURE.md "Boot : mkinitcpio, Plymouth et GRUB".
  ["/usr/local/bin/fix-target-mkinitcpio.sh"]="0:0:755"
)
