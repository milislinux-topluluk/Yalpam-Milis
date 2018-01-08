#!/usr/bin/env bash
#
# _________        ____  ____________         _______ ___________________
# ______  /__________  |/ /___  ____/________ ___    |__  ____/___  ____/
# _  __  / __  ___/__    / ______ \  ___  __ \__  /| |_  /     __  __/
# / /_/ /  _  /    _    |   ____/ /  __  /_/ /_  ___ |/ /___   _  /___
# \__,_/   /_/     /_/|_|  /_____/   _  .___/ /_/  |_|\____/   /_____/
#                                    /_/           drxspace@gmail.com
#
#set -e
#set -x

[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"

source "$(dirname "$0")"/libfuncs &>/dev/null || {
	echo "Dosya eksik: libfuncs";
	exit 1;
}

[[ "$1" = "-m" ]] || [[ "$1" = "" ]] || [[ "$1" = "-a" ]] && {
	msg "Başlangıç ramdisk ortamı oluşturma" 12;
	sudo mkinitcpio -p linux;
	# Hafızada tamponlanan tüm verileri diske yaz
	sudo sync
	[[ $# -gt 1 ]] && shift
}

[[ "$1" = "-g" ]] || [[ "$1" = "" ]] || [[ "$1" = "-a" ]] && {
	msg "GRUB yapılandırma dosyası oluşturma" 10;
	if hash os-prober &>/dev/null; then
		msg "Diğer işletim sistemleri için sistemdeki diskleri araştırma" 12;
		sudo os-prober;
	fi
	exec sudo grub-mkconfig -o /boot/grub/grub.cfg;
}

exit $?
