## Build dropbear

```
export TOOLCHAIN=/static/mipsel-linux-musl-cross/bin
export CROSS_COMPILE=$TOOLCHAIN/mipsel-linux-musl-
export PATH=$PATH:/static/mipsel-linux-musl-cross/bin

export CC=${CROSS_COMPILE}gcc
export AR=${CROSS_COMPILE}ar
export LDFLAGS="-static"

./configure \
	--host=mips-linux \
	--enable-static \
	--disable-lastlog \
	--disable-utmp --disable-utmpx \
	--disable-wtmp --disable-wtmpx \
	--disable-pututline --disable-pututxline \
	--enable-bundled-libtom \
	--with-zlib=/git/install
```
