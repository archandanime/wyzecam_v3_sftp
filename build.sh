#!/bin/bash
#

action="$1"
SoC="$2"

RECOVERY_BIN="demo_wcv3.bin"

EXTRACTED_ROOTFS_IMG="rootfs.img"
EXTRACTED_APP_IMG="app.img"

ROOTFS_DIR="rootfs"
APP_DIR="app"
ABACK_DIR="aback"

ROOTFS_SQSH_BLOCKSIZE="128K"
APP_SQSH_BLOCKSIZE="128K"
ABACK_SQSH_BLOCKSIZE="128K"

OUT_KERNEL_IMG="output/stock_${SoC}_kernel.bin"
OUT_ROOTFS_IMG="output/stock_${SoC}_rootfs.bin"
OUT_APP_IMG="output/stock_${SoC}_app.bin"
OUT_ABACK_IMG="output/stock_${SoC}_aback.bin"


function extract_recovery_bin() {
	echo -n "Copying recovery bin... "
	cp recovery_bin/$(ls recovery_bin | tail -n 1) $RECOVERY_BIN && echo "done" || { echo "failed" ; return 1 ; }

	echo
	echo "Extracting recovery bin"

	[ ! -f ${RECOVERY_BIN} ] && { echo "${RECOVERY_BIN} does not exist" ; return 1 ; }

	local kernel_start_addr="64"
	local rootfs_start_addr="2031680"
	local app_start_addr="6029376"
	local RECOVERY_BIN_size=`du -b ${RECOVERY_BIN} | cut -f1`

	local kernel_size=$(( $rootfs_start_addr - $kernel_start_addr))
	local rootfs_size=$(( $app_start_addr - $rootfs_start_addr ))
	local app_size=$(( $RECOVERY_BIN_size - $app_start_addr ))

	echo -n "    Extracting kernel image from recovery bin... "
	[ -f $OUT_KERNEL_IMG ] && { echo "$OUT_KERNEL_IMG exists" ; return 1 ; }
	dd if=${RECOVERY_BIN} of=$OUT_KERNEL_IMG bs=1 skip=$kernel_start_addr count=${kernel_size} status=none && echo "done" || { echo "failed" ; return 1 ; }

	echo -n "    Extracting rootfs image from recovery bin... "
	[ -f $EXTRACTED_ROOTFS_IMG ] && { echo "$EXTRACTED_ROOTFS_IMG exists" ; return 1 ; }
	dd if=${RECOVERY_BIN} of=$EXTRACTED_ROOTFS_IMG bs=1 skip=$rootfs_start_addr count=$rootfs_size status=none && echo "done" || { echo "failed" ; return 1 ; }

	echo -n "    Extracting app image from recovery bin... "
	[ -f $EXTRACTED_APP_IMG ] && { echo "$EXTRACTED_APP_IMG exists" ; return 1 ; }
	dd if=${RECOVERY_BIN} of=$EXTRACTED_APP_IMG bs=1 skip=$app_start_addr count=$app_size status=none && echo "done" || { echo "failed" ; return 1 ; }

	echo -n "    Decompressing rootfs image... "
	[ -d $ROOTFS_DIR ] && { echo "$ROOTFS_DIR directory exists" ; return 1 ; }
	unsquashfs -d $ROOTFS_DIR $EXTRACTED_ROOTFS_IMG >/dev/null && echo "done" || { echo "failed" ; return 1 ; }

	echo -n "    Decompressing app image... "
	[ -d $APP_DIR ] && { echo "$APP_DIR directory exists" ; return 1 ; }
	unsquashfs -d $APP_DIR $EXTRACTED_APP_IMG >/dev/null && echo "done" || { echo "failed" ; return 1 ; }
}

function modify_partitions() {
	echo
	echo "Modifying rootfs and app"
	chmod 644 $ROOTFS_DIR/etc/shadow

	echo -n "    Copying rootfs_overlay... "
	cp -rT rootfs_overlay $ROOTFS_DIR && echo "done" || { echo "failed" ; return 1 ; }
	chmod 400 $ROOTFS_DIR/etc/shadow

	local rootfs_ver=$(cat $ROOTFS_DIR/usr/app.ver | grep appver= | cut -d '=' -f2)
	local app_ver=$(cat $APP_DIR/bin/app.ver | grep appver= | cut -d '=' -f2)
	echo "     + rootfs version: $rootfs_ver"
	echo "     + app version: $app_ver"

	echo -n "    Writing new rootfs and app version... "
	sed -i "s/$rootfs_ver/sftp_$rootfs_ver/g" $ROOTFS_DIR/usr/app.ver || { echo "failed" ; return 1 ; }
	sed -i "s/$app_ver/sftp_$app_ver/g" $APP_DIR/bin/app.ver && echo "done" || { echo "failed" ; return 1 ; }

	local new_rootfs_ver=$(cat $ROOTFS_DIR/usr/app.ver | grep appver= | cut -d '=' -f2)
	local new_app_ver=$(cat $APP_DIR/bin/app.ver | grep appver= | cut -d '=' -f2)
	echo "     + new rootfs version: $new_rootfs_ver"
	echo "     + new app version: $new_app_ver"

	echo "    Disabling mtd-utils to block firmware update"
	for mtd_utils in flashcp flash_erase flash_eraseall; do
		mtd_utils_files=$( find . -name $mtd_utils \( -type f -o -type l \) )
		for mtd_utils_file in $mtd_utils_files; do
			echo "     + $mtd_utils_file"
			rm $mtd_utils_file
			echo -e "#!/bin/sh\nexit 0" > $mtd_utils_file
			chmod +x $mtd_utils_file
		done
	done

	echo "    Creating /usr/local/bin to mount aback"
	mkdir -p $ROOTFS_DIR/usr/local/bin
}

function repack_partitions() {
	echo
	echo -n "Repacking rootfs... "
	mksquashfs $ROOTFS_DIR $OUT_ROOTFS_IMG -comp xz -all-root -b $ROOTFS_SQSH_BLOCKSIZE >/dev/null && echo "done" || { echo "failed" ; return 1 ; }
	echo "    + $(du $EXTRACTED_ROOTFS_IMG)"
	echo "    + $(du $OUT_ROOTFS_IMG)"

	echo
	echo -n "Repacking app..."
	mksquashfs $APP_DIR $OUT_APP_IMG -comp xz -all-root -b $APP_SQSH_BLOCKSIZE >/dev/null && echo "done" || { echo "failed" ; return 1 ; }
	echo "    + $(du $EXTRACTED_APP_IMG)"
	echo "    + $(du $OUT_APP_IMG)"

	echo
	echo -n "Repacking aback..."
	mksquashfs $ABACK_DIR $OUT_ABACK_IMG -comp xz -all-root -b $ABACK_SQSH_BLOCKSIZE >/dev/null && echo "done" || { echo "failed" ; return 1 ; }
	echo "    + $(du $OUT_APP_IMG)"
	echo "    + $(du $OUT_ABACK_IMG)"
}

function generate_checksum() {
	echo
	echo "Generating sha256sum files"
	for outfile in $OUT_KERNEL_IMG $OUT_ROOTFS_IMG $OUT_APP_IMG $OUT_ABACK_IMG; do
		echo -n "    For $outfile... " && echo "done" || { echo "failed" ; return 1 ; }
		( cd $(dirname $outfile) && sha256sum $(basename $outfile) > $(basename $outfile).sha256sum )
	done
}

function clean() {
	rm -rf $RECOVERY_BIN $EXTRACTED_ROOTFS_IMG $EXTRACTED_APP_IMG $EXTRACTED_ROOTFS_IMG $EXTRACTED_APP_IMG $ROOTFS_DIR $APP_DIR output
}

function show_syntax() {
		echo "Syntax: ./build.sh <create/clean> <SoC>"
}

[ ! -d output ] && mkdir output

case "${1}" in
	"create")
		if [[ ! "$SoC" == "t31a" ]] && [[ ! "$SoC" == "t31x" ]]; then
			echo "Invalid SoC, only t31a and t31x are supported"
			show_syntax
			exit 1
		fi

		extract_recovery_bin || exit 1
		modify_partitions || exit 1
		repack_partitions || exit 1
		generate_checksum || exit 1
		;;
	"clean")
		clean
		;;
	*)
		show_syntax
		;;
esac
