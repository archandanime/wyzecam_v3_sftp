## Features

- SSH, SFTP and Rsync server without SD card(which guarantees stability)
- nano editor with shell script syntax highlighting
- Block firmware update
- Compatible with wz_mini_hacks
- Compatible with Entware if wz_mini_hacks is not used, with custom script at `/configs/entware.sh`
 
## How to install

1. Setup [wz_flash-helper](https://github.com/archandanime/wz_flash-helper/)

2. Backup all your partitions in case you need to rollback later

3. Place partition images from the Release page to `wz_flash-helper/restore/stock/` on your SD card

6. Setup dropbear key by:
- Extracting `stock_[SoC]_cfg.tar.gz` from `wz_flash-helper/backup/stock/` to your computer(anywhere)
- Add `dropbear/authorized_keys` with your SSH public key to the extracted directory
- Re-pack the archive and generate its .sha256sum file
- Place the archive and its .sha256sum file at your SD card top directory

4. Edit `wz_flash-helper/restore/stock.conf` with:

```
restore_stock_kernel="yes"
restore_stock_rootfs="yes"
restore_stock_app="yes"
restore_stock_kback="no"
restore_stock_aback="yes"
restore_stock_cfg="no"
restore_stock_para="no"
```
5. Edit `wz_flash-helper/scripts/extract_archive_file_to_partition.sh` with:

```
archive_file="/sdcard/stock_[SoC]_cfg.tar.gz"
partition_name="cfg"
matched_firmware="stock"
```

5. Reboot your camera and wait till the flasher program is finished

It seems that this firmware works well with Anroid app version `2.45.6.361` but not with newer versions, downgrade your mobile app to make it work if neccessary. Doing a factory reset using recovery bin file might make it work too.
