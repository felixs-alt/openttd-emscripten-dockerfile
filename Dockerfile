FROM trzeci/emscripten-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list
RUN apt-get update -y &&\
	apt-get install -y build-essential git autopoint automake libtool pkg-config wget unzip xz-utils

WORKDIR /
RUN mkdir extralibs
WORKDIR /
RUN apt update -y; apt install -y libgnutls30
RUN apt update -y ; apt-get install apt-transport-https ca-certificates -y ; update-ca-certificates
RUN git config --global http.sslverify false
WORKDIR /
RUN git clone https://git.tukaani.org/xz.git &&\
	cd xz &&\
	sudo apt-get install software-properties-common -y &&\
	sudo apt-add-repository universe &&\
	sudo apt-get update &&\
	sudo apt-get install -y doxygen &&\
	sudo apt-get install -y po4a &&\
	./autogen.sh &&\
	emconfigure ./configure --prefix=/extralibs --disable-threads --enable-assume-ram=32 &&\
	emmake make -j2 &&\
	emmake make install; exit 0

WORKDIR /
RUN git clone https://git.code.sf.net/p/libtimidity/libtimidity &&\
	cd libtimidity &&\
	autoreconf -fi &&\
	emconfigure ./configure --prefix=/extralibs --with-timidity-cfg="freepats/freepats.cfg" &&\
	emmake make -j2 &&\
	emmake make install

WORKDIR /
COPY sdl2.pc /extralibs/lib/pkgconfig/
RUN touch empty.c &&\
	emcc -s USE_SDL=2 empty.c -o /dev/null &&\
	cp -r /emsdk_portable/.data/cache/asmjs/ports-builds/sdl2/include/* /extralibs/include/

COPY zlib.pc /extralibs/lib/pkgconfig/
RUN emcc -s USE_ZLIB=1 empty.c -o /dev/null &&\
	rm empty.c &&\
	cp -r /emsdk_portable/.data/cache/asmjs/ports-builds/zlib/z*.h /extralibs/include/

WORKDIR /baseset

RUN wget --no-check-certificate https://cdn.openttd.org/opengfx-releases/7.1/opengfx-7.1-all.zip &&\
	unzip opengfx-7.1-all.zip &&\
	tar -xvf opengfx-7.1.tar &&\
	mv opengfx-7.1/* ./ &&\
	rm -rf opengfx-* *.txt

RUN wget --no-check-certificate https://cdn.openttd.org/opensfx-releases/1.0.3/opensfx-1.0.3-all.zip &&\
	unzip -j opensfx-1.0.3-all.zip &&\
	rm -rf opensfx-* *.txt

RUN wget --no-check-certificate https://cdn.openttd.org/openmsx-releases/0.4.2/openmsx-0.4.2-all.zip &&\
	unzip -j openmsx-0.4.2-all.zip &&\
	rm -rf openmsx-* *.txt

WORKDIR /
RUN wget --no-check-certificate http://freepats.zenvoid.org/freepats-20060219.tar.xz &&\
	tar -xvf freepats-20060219.tar.xz &&\
	rm -rf freepats-*
 
COPY pre.js /files/
COPY shell.html /files/
COPY openttd.cfg /files/

WORKDIR /workdir/source

CMD ./configure --without-zlib --without-lzo2 --without-sse --without-lzma --without-threads --enable-dedicated &&\
	make -j2 &&\
	emconfigure sh -c 'PKG_CONFIG_PATH=/extralibs/lib/pkgconfig ./configure --without-lzo2 --without-sse --without-threads --with-libtimidity --with-sdl=sdl2' &&\
	emmake make -j2 &&\
	mkdir -p /workdir/output /workdir/content &&\
	cp bin/openttd /workdir/openttd.bc &&\
	cp -r bin/* /workdir/content/ &&\
	rm /workdir/content/openttd &&\
	cp -r /freepats /workdir/content/ &&\
	cp -r /baseset /workdir/content/ &&\
	cp /files/openttd.cfg /workdir/content/ &&\
	emcc /workdir/openttd.bc -o /workdir/output/index.html -O2 -s "BINARYEN_TRAP_MODE='clamp'" -s USE_SDL=2 -s USE_ZLIB=1 -s STB_IMAGE=1 -s ALLOW_MEMORY_GROWTH=1 \
		--preload-file /workdir/content@/ --pre-js /files/pre.js --shell-file /files/shell.html
