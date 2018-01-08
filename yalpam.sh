#!/usr/bin/env bash
#
# _________        ____  ____________         _______ ___________________
# ______  /__________  |/ /___  ____/________ ___    |__  ____/___  ____/
# _  __  / __  ___/__    / ______ \  ___  __ \__  /| |_  /     __  __/
# / /_/ /  _  /    _    |   ____/ /  __  /_/ /_  ___ |/ /___   _  /___
# \__,_/   /_/     /_/|_|  /_____/   _  .___/ /_/  |_|\____/   /_____/
#                                    /_/           drxspace@gmail.com
#
#
set -e
#
set -x

export yalpamVersion="0.7.850"

export yalpamTitle="Milis Linux Paket Yöneticisi"
export yalpamName="yalpam"

# DISPLAY ve XAUTHORITY değişkenlerinin komut dosyasının çalıştığı ortamda ayarlandığından emin olun.
Encoding=UTF-8
LANG=en_US.UTF-8
[[ -z "$DISPLAY" ]] && {
	display=`/bin/ps -Afl | /bin/grep Xorg | /bin/grep -v grep | /usr/bin/awk '{print $16 ".0"}'`
	export DISPLAY=$display
}
[[ -z "$XAUTHORITY" ]] && [[ -e "$HOME/.Xauthority" ]] && export XAUTHORITY="$HOME/.Xauthority";

hash paplay 2>/dev/null && [[ -d /usr/share/sounds/freedesktop/stereo/ ]] && {
	export errorSnd="paplay /usr/share/yalpam/hata.ogg"
	export infoSnd="paplay /usr/share/yalpam/bilgi.ogg"
}

msg() {
	$(${errorSnd});
	if ! hash notify-send 2>/dev/null; then
		echo -e ":: \e[1m${1}\e[0m $2" 1>&2;
		[ "x$3" == "x" ] || exit $3;
	else
		notify-send "${yalpamTitle}" "<b>${1}</b> $2" -i face-worried;
		[ "x$3" == "x" ] || exit $(($3 + 5));
	fi
}

# -----------------------------------------------------------------------------]
__CNKDISTRO__=$(sed -n '/^ID=/s/ID=//p' /etc/*release 2>/dev/null)

# Sadece Milis Linux dağıtımında çalışır
# Seninkini aşağıya ekleyebilirsin
__CNKARCHES__="arch|'Milis Linux'| |"

DIR="$(dirname "$0")"
if [[ ! ${__CNKDISTRO__} =~ ${__CNKARCHES__} ]]; then
	msg "$__CNKDISTRO__" "Sadece Milis Linux için." 8
fi
# -----------------------------------------------------------------------------]

# Prerequisites
# Check to see if all needed tools are present
if ! hash yad 2>/dev/null; then
	msg "yad" "command not found." 10
elif ! hash mps 2>/dev/null; then
	msg "mps" "komutu bulunamadı." 20
elif [[ -z "$(yad --version | grep 'GTK+ 2')" ]]; then
	msg "yad" "komutu, desteklenmeyen bir GTK + platform sürümünü kullanıyor.\n<i>GUI doğru çalışmayabilir.</i>"
elif ! hash xterm 2>/dev/null; then
	msg "xterm" "komutu bulunamadı." 30
fi

fkey=$(($RANDOM * $$))

export frealtemp=$(mktemp -u --tmpdir realtemp.XXXXXXXX)
export frunningPIDs=$(mktemp -u --tmpdir runningPIDs.XXXXXXXX)
export fpipepkgssys=$(mktemp -u --tmpdir pkgssys.XXXXXXXX)
export fpipepkgslcl=$(mktemp -u --tmpdir pkgslcl.XXXXXXXX)
mkfifo "${fpipepkgssys}" "${fpipepkgslcl}"

export GDK_BACKEND=x11	# https://groups.google.com/d/msg/yad-common/Jnt-zCeCVg4/Gwzx-O-2BQAJ

export xtermOptionsGreen="-geometry 128x24 -fa 'Monospace' -fs 9 -bg SeaGreen"
export xtermOptionsBlue="-geometry 128x24 -fa 'Monospace' -fs 9 -bg RoyalBlue"
export xtermOptionsRed="-geometry 128x24 -fa 'Monospace' -fs 9 -bg red3"
# -rightbar -sb

# -- export IAdmin="pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY"
export IAdmin="sudo"

declare -a runningPIDs=()

# ---[ Task functions ]--------------------------------------------------------|

doupdate() {
	local args
	echo "5:@disable@"
	[[ "$2" = "TRUE" ]] && args=$args" -m"
	[[ "$3" = "TRUE" ]] && args=$args" -u"
	[[ "$4" = "TRUE" ]] && args=$args" -p"
	xterm ${xtermOptionsBlue} -e "yup $args" && doscan4pkgs
	echo "1:TRUE"
	echo "2:FALSE"
	echo "3:TRUE"
	echo "4:TRUE"
	echo '5:@bash -c "doupdate %1 %2 %3 %4"'
	return
}
export -f doupdate

doadvanced() {
	local theCommand=
	local argsyup=
	local argssys=
	echo "11:@disable@"
	[[ "$1" = "TRUE" ]] && argsyup=$argsyup" -r"
	[[ "$2" = "TRUE" ]] && argsyup=$argsyup" -o"
	[[ "$3" = "TRUE" ]] && argssys=$argssys" -m"
	[[ "$4" = "TRUE" ]] && argssys=$argssys" -g"
	[[ "$argsyup" ]] && theCommand=${theCommand}"yup $argsyup; "
	[[ "$argssys" ]] && theCommand=${theCommand}"update-sys $argssys;"
	[[ "$theCommand" ]] && {
		xterm ${xtermOptionsRed} -e "${theCommand}"
		echo "7:FALSE"
		echo "8:FALSE"
		echo "9:FALSE"
		echo "10:FALSE"
	} || $(${infoSnd})
	echo '11:@bash -c "doadvanced %7 %8 %9 %10"'
	return
}
export -f doadvanced

# ---[ Eylem işlevleri ]------------------------------------------------------|

doreinstpkg() {
	kill -s USR1 $YAD_PID # Close caller window
	xterm ${xtermOptionsGreen} -e "[[ \"${1}\" == \"mps\" ]] && { $IAdmin $1 kur $2; } || { $1 odkp $2; }"
	doscan4pkgs
	return
}
export -f doreinstpkg

doremovepkg() {
	kill -s USR1 $YAD_PID # Close caller window
	xterm ${xtermOptionsRed} -e "$IAdmin $1 sil $2" && doscan4pkgs
	return
}
export -f doremovepkg

function instbtn_onclick ()
{
	[[ "$1" ]] && [[ "$1" != "<Bir veya daha fazla paket adı yazın>" ]] && {
		echo -n "$1" > ${frealtemp}
		kill -s USR1 $YAD_PID
	} || {
		$(${errorSnd})
		echo "2:<Bir veya daha fazla paket adı yazın>"
	}
}
export -f instbtn_onclick

doinstpkg() {
	local ret=
	local packagenames=
	kill -s USR1 $YAD_PID # Close caller window
	yad	--form --class="WC_YALPAM" --geometry=+230+140 --width=460 --fixed \
		--skip-taskbar --borders=6 \
		--title="Paket adı girin..." \
		--image="/usr/share/icons/Adwaita/48x48/emblems/emblem-package.png" \
		--no-buttons --columns=2 --focus-field=2 \
		--field=$"Buraya, <i> boşluk </i> karakteriyle ayrılmış bir veya daha fazla paket adı girin:":lbl '' \
		--field='' '' \
		--field="gtk-cancel":fbtn 'bash -c "kill -s USR2 $YAD_PID"' \
		--field="gtk-ok":fbtn '@bash -c "instbtn_onclick %2"' &>/dev/null & local pid=$!

	sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
	local ret=$?
	[[ -e ${frunningPIDs} ]] && sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
	packagenames=$(<${frealtemp})

	fxtermstatus=$(mktemp -u --tmpdir xtermstatus.XXXXXXXX)
	[[ $ret -eq 0 ]] && [[ "${packagenames}" ]] && {
		xterm ${xtermOptionsBlue} -e "[[ \"${1}\" == \"mps\" ]] && { $IAdmin $1 kur ${packagenames}; } || { $1 kur ${packagenames}; };" # echo $?" >${fxtermstatus}
		[[ $(<$fxtermstatus) -eq 0 ]] && doscan4pkgs || $(${errorSnd})
	}
	rm -f ${fxtermstatus}
	return
}
export -f doinstpkg

docrawl() {
	kill -s USR1 $YAD_PID # Close caller window
	[[ -x $BROWSER ]] || BROWSER=$(command -v xdg-open 2>/dev/null || command -v gnome-open 2>/dev/null)
	[[ "$1" == "mps" ]] && {
		URL="https://www.archlinux.org/packages/?sort=&q=${2}&maintainer=&flagged=";
	} || {
		URL="https://aur.archlinux.org/packages/?O=0&SeB=n&K=${2}&outdated=&SB=n&SO=a&PP=50&do_Search=Go";
	}
	exec "$BROWSER" "$URL"
	return
}
export -f docrawl

doexecpkg() {
	hash $1 &>/dev/null && {
		kill -s USR1 $YAD_PID; # Close caller window
		exec ${1};
	} || $(${errorSnd})
	return
}
export -f doexecpkg

doshowinfo() {
	kill -s USR1 $YAD_PID # Close caller window
	local pkgnfo=$()
	mps -b $1 | sed 's/\\[1;32m/ /g' | sed 's/\\[0;39m/ /g' | sed 's/\\[1;31m/ /g' | sed '/^[[:blank:]]*$/d' | \
	yad 	--text-info --class="WC_YALPAM" --borders=6 --text-align="left" \
		--geometry=+230+140 --width=480 --height=484 --fixed --skip-taskbar \
		--title="Seçilen Paket Hakkında Bilgi" \
		--margins=3 --fore="#333333" --back="#ffffff" --show-uri \
		--image="dialog-information" --image-on-top --fontname="Monospace Regular 9" \
		--text=$"<span font_weight='bold'>Paket Bilgisini Göster</span>\n\
Bu iletişim kutusu, seçilen yüklü pakete ilişkin <i>Sürüm</i>, <i>Tanım</i>, <i>Paketçi</i> gibi belirli bilgileri görüntüler: <b><i>${1}</i></b>" \
		--buttons-layout="center" \
		--button=$"Kapat!application-exit!Bu pencereyi kapatır":0 &>/dev/null & local pid=$!
	sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
	[[ -e ${frunningPIDs} ]] && sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
	return
}
export -f doshowinfo

# Talimatı görüntüle
domanpage() {
	kill -s USR1 $YAD_PID # Close caller window
	local pkgnfo=$()
	mps talimat $1 | sed 's/\\[1;32m/ /g' | sed 's/\\[0;39m/ /g' | sed 's/\\[1;31m/ /g' | sed '/^[[:blank:]]*$/d' | \
	yad 	--text-info --class="WC_YALPAM" --borders=6 --text-align="left" \
		--geometry=+230+140 --width=480 --height=484 --fixed --skip-taskbar \
		--title="Seçilen Paketin Talimat Bilgisi" \
		--margins=3 --fore="#333333" --back="#ffffff" --show-uri \
		--image="dialog-information" --image-on-top --fontname="Monospace Regular 9" \
		--text=$"<span font_weight='bold'>Paketin Talimat Bilgisini Göster</span>\n\
Bu iletişim kutusu, seçilen paketin <i>Talimat</i> bilgileri görüntüler: <b><i>${1}</i></b>" \
		--buttons-layout="center" \
		--button=$"Kapat!application-exit!Bu pencereyi kapatır":0 &>/dev/null & local pid=$!
	sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
	[[ -e ${frunningPIDs} ]] && sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
	return
}
export -f domanpage

doaction() {
	export -f doscan4pkgs

	export manager=$1
	export package=$3

	yad	--form --class="WC_YALPAM" --geometry=+230+140 --width=500 --fixed \
		--borders=6 --skip-taskbar --title="Eylem seçin:" \
		--image="dialog-information" --image-on-top \
		--text=$"<span font_weight='bold'>Paket İşlemleri</span>\n\
Seçilen pakete ait seçeneklerden birini tıklayarak uygulamak için aşağıdaki listeden istediğiniz işlemi seçin." \
		--field="":lbl '' \
		--field=$" <span color='#206EB8'>Seçilen Paketi Kur</span>!view-refresh":btn 'bash -c "doreinstpkg $manager $package"' \
		--field=$" <span color='#206EB8'>Seçilen Paketi Kaldır</span>!edit-delete":btn 'bash -c "doremovepkg $manager $package"' \
		--field=$" <span color='#206EB8'>Seçilen Gruptaki Paketleri Kur</span>!go-down":btn 'bash -c "doinstpkg $manager"' \
		--field="":lbl '' \
		--field=$" <span color='#206EB8'>Seçilen paketi <i>çalıştırmayı</i> deneyin</span>!system-run":btn 'bash -c "doexecpkg $package"' \
		--field="":lbl '' \
		--field=$" <span color='#206EB8'>Arch Linux Sitesinde Paket Bilgisi</span>!go-home":btn 'bash -c "docrawl $manager $package"' \
		--field=$" <span color='#206EB8'>Seçilen Paket Hakkında Bilgi</span>!dialog-information":btn 'bash -c "doshowinfo $package"' \
		--field=$"<span color='#206EB8'>Seçilen paketin <i>talimatını</i> görüntüleyin</span>!help-contents":btn 'bash -c "domanpage $package"' \
		--field="":lbl '' \
		--buttons-layout="center" \
		--button=$" _Kapat!application-exit!Bu pencereyi kapatır...":0 &>/dev/null & local pid=$!
	sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
	[[ -e ${frunningPIDs} ]] && sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
	return
}
export -f doaction

# ---[ Düğmelerin İşlevleri ]-------------------------------------------------|

doabout() {
	yad	--form --class="WC_YALPAM" --geometry=+230+140 --text-align="left" --fixed \
		--borders=6 --skip-taskbar --title="${yalpamTitle} Hakkında" \
		--image="system-software-install" --image-on-top \
		--text=$"<span font_weight='bold'>${yalpamTitle} v${yalpamVersion}</span>\nProgramcı: John A Ginis (a.k.a. <a href='https://github.com/drxspace'>drxspace</a>)\n\n(Cihan Alkan tarafından Milis Linux için uyarlandı)<span font_size='small'></span>" \
		--field="":lbl '' \
		--field=$"<b><i>Yalpam'ı</i></b> kendi <i>kişisel</i> ihtiyaçlarımı gidermek için hazırladım. Milis Linux paketlerini yönetmek için bir yardımcı araçtır.\nBu uygulama hazırlanırken <a href='https://github.com/v1cont/yad'>yad</a> v$(yad --version) kullanılmıştır. <a href='https://plus.google.com/+VictorAnanjevsky'>Victor Ananjevsky'nin </a>kişisel bir projesi olan harika aracı kullanıyorsunuz.\n\nBu uygulamanın Arch Linux için olan orjinalini AUR depolarından kurabilirsiniz.Bu sürüm <i>Milis Linux</i> için uyarlanmıştır, başka dağıtımlarda çalışmaz.\n\nSevincimi <i>sizinle</i> paylaşmaya karar verdim, çünkü bu uygulama işlerinizi kolaylaştıracaktır... \nEğlenin ve hayatınıza sevinç katın...\nJohn":lbl '' \
		--field="":lbl '' \
		--buttons-layout="center" \
		--button=$"Kapat!application-exit!Bu pencereyi kapatır":0 &>/dev/null & local pid=$!
	sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
	[[ -e ${frunningPIDs} ]] && sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
	return
}
export -f doabout

dosavepkglists() {
	local dirname=$(yad --file --class="WC_YALPAM" --directory --filename="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}/" \
			    --geometry=640x480+210+140 --skip-taskbar \
			    --button="gtk-cancel":1 \
			    --button="gtk-ok":0 \
			    --title="İki paket listesini kaydetmek için dizini seçin...")
	if [[ "${dirname}" ]]; then
		mps -Qqe |\
			grep -vx "$(cut -d ' ' -f3 /depo/paketler/paket.vt | awk -F'-x86' '{print $1}' | awk -F'#' '{print $1" "$2}')" |\
			grep -vx "$(mps gruplar)" > "${dirname}"/SYSTEMpkgs-$(date -u +"%g%m%d").txt
		mps gruplar > "${dirname}"/LOCALAURpkgs-$(date -u +"%g%m%d").txt
	fi
	return
}
export -f dosavepkglists

doscan4pkgs() {
	echo -e '\f' >> "${fpipepkgssys}"
    cut -d ' ' -f3 /depo/paketler/paket.vt | awk -F'-x86' '{print $1}' | awk -F'#' '{print $1" "$2}' |\
		grep -vx "$(mps gruplar temel)" |\
	#	grep -vx "$(mps gruplar temel)" | sort |\
		awk '{printf "%d\n%s\n%s\n", ++i, $1, $2}' |\
		tee -a "${fpipepkgssys}" |\
		yad --progress --pulsate --auto-close --no-buttons --width=340 --align="center" --center --borders=6 --skip-taskbar --title="Paketler sorgulanıyor" --text-align="center" --text=$"Lütfen bekleyin. <i>Milis Linux Deposu</i> paketleri sorgulanıyor..."

	echo -e '\f' >> "${fpipepkgslcl}"
    /usr/share/yalpam/kullanici-paketleri |\
#	cut -d ' ' -f3 /depo/paketler/paket.vt | awk -F'-x86' '{print $1}' | awk -F'#' '{print $1" "$2}' | sort | 
        awk '{printf "%d\n%s\n%s\n", ++i, $1, $2}' |\
		tee -a "${fpipepkgslcl}" |\
		yad --progress --pulsate --auto-close --no-buttons --width=340 --align="center" --center --borders=6 --skip-taskbar --title="Paketler sorgulanıyor" --text-align="center" --text=$"Lütfen bekleyin. <i>LKullanıcı Deposu</i> paketleri sorgulanıyor..."
	return
}
export -f doscan4pkgs

# -----------------------------------------------------------------------------|

exec 3<> ${fpipepkgssys}
exec 4<> ${fpipepkgslcl}

echo 'openedFormPIDs=()' > ${frunningPIDs}

yad --plug="${fkey}" --tabnum=1 --list --grid-lines="hor" \
    --dclick-action='bash -c "doaction mps %s %s %s"' \
    --text=$"<i>Milis Linux Deposu</i> Paketleri:\n<span font_size='small'>Daha fazla işlem için bir pakete çift tıklayın.</span>" \
    --search-column=2 --expand-column=2 --focus-field=1 \
    --column='№':num --column='Paket Adı' --column='Paket Sürümü' <&3 &>/dev/null &

yad --plug="${fkey}" --tabnum=2 --list --grid-lines="hor" \
    --dclick-action='bash -c "doaction mps %s %s %s"' \
    --text=$"<i>Kullanıcı Deposu</i> Paketleri:\n<span font_size='small'>Daha fazla işlem için bir pakete çift tıklayın.</span>" \
    --search-column=2 --expand-column=2 --focus-field=1 \
    --column='№':num --column='Paket Adı' --column='Paket Sürümü' <&4 &>/dev/null &

doscan4pkgs

yad --plug="${fkey}" --tabnum=3 --form --focus-field=2 \
    --field=$"Mps veritabanını yenile:chk" 'TRUE' \
    --field=$"Mps sunucularını yenile:chk" 'TRUE' \
    --field=$"Paketleri güncelle:chk" 'TRUE' \
    --field=$"Önbellekteki kullanılmayan paketleri temizle:chk" 'TRUE' \
    --field=$" <span color='#206EB8'>Yenile [ [Geri Al] [Güncelle] [Temizle] ]</span>!/usr/share/icons/Adwaita/16x16/apps/system-software-update.png:fbtn" '@bash -c "doupdate %1 %2 %3 %4"' \
    --field="":lbl '' \
    --field=$"Mps GnuPG anahtarlarını yenile:chk" 'FALSE' \
    --field=$"Mps veritabanını optimize et:chk" 'FALSE' \
    --field=$"Başlangıç ramdisk ortamı oluştur:chk" 'FALSE' \
    --field=$"GRUB yapılandırma dosyası oluştur:chk" 'FALSE' \
    --field=$" <span color='#C41E1E'>[GnuPG] [Optimize] [Ramdisk] [Grub]</span>!/usr/share/icons/Adwaita/16x16/categories/preferences-system.png:fbtn" '@bash -c "doadvanced %7 %8 %9 %10"' &>/dev/null &

yad --key="${fkey}" --notebook --class="WC_YALPAM" --name="yalpam" --geometry=480x640+200+100 \
    --borders=6 --tab-borders=3 --active-tab=1 --focus-field=1 \
    --window-icon="system-software-install" --title=$"${yalpamTitle} v${yalpamVersion}" \
    --image="system-software-install" --image-on-top \
    --text=$"<span font_weight='bold'>Kurulu Paketlerin Listesi</span>\n\
Bunlar, <i>Temel Paketler</i> dışındaki resmi depodaki paketlerin listesidir. Ayrıca, <i>Kullanıcı Paketleri</i> gibi yerel olarak kurulu paketleri bulacaksınız." \
    --tab=" <i>Milis Linux Paketleri</i>" \
    --tab=" <i>Kullanıcı Paketleri</i>" \
    --tab=" Günlük/Faydalı Görevler" \
    --button=$"<span color='#206EB8'>Listeleyi Güncelle</span>!system-search!Yüklü paketler için veritabanlarını tarar:bash -c 'doscan4pkgs'" \
    --button=$"Kaydet...!document-save!Paket listelerini daha sonra kullanmak üzere diske kaydeder:bash -c 'dosavepkglists'" \
    --button="Hakkında...!help-about:bash -c 'doabout'" \
    --button="Çıkış!application-exit":0 &>/dev/null

# -----------------------------------------------------------------------------|

_trapfunc_() {
	exec 3>&-
	exec 4>&-

	source ${frunningPIDs}
	runningPIDs=${openedFormPIDs[@]}
	[[ "${runningPIDs}" ]] && {
		kill -s 15 ${runningPIDs[@]}
	#	[[ "${#runningPIDs[@]}" -ge 1 ]] && eval "kill -15 ${runningPIDs[@]}"
		sleep 5
	}
	rm -f ${fpipepkgssys} ${fpipepkgslcl} ${frunningPIDs} ${frealtemp}
}
trap '_trapfunc_' EXIT

# -----------------------------------------------------------------------------|

exit $?
