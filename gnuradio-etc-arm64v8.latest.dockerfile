### Template for balena.io container builder.

#FROM resin/raspberrypi3-ubuntu:bionic AS gnuradio
#FROM balenalib/jetson-nano-ubuntu:latest-build AS gnuradio
FROM arm64v8/ubuntu AS gnuradio

ENV DEBIAN_FRONTEND noninteractive
ENV PYBOMBS_PREFIX=/pybombs

RUN echo "America/New_York" > /etc/timezone

RUN apt-get -q update \
  && apt-get -y -q install software-properties-common \
  && add-apt-repository ppa:bladerf/bladerf

RUN apt-get -q update \
  && apt-get -y -q install --no-install-recommends \
  build-essential \
  python-scipy \
  python-numpy \
  python-apt \
  bladerf-fpga-hostedxa4 \
  && apt-get -y -q install \
  multimon \
  sudo \
  apt-utils \
  sox \
  git \
  curl \
  wget \
  python-dev \
  python3-dev \
  tzdata \
  python-gps \
  gpsd \
  && rm -rf /var/lib/apt/lists/*

RUN dpkg-reconfigure -f noninteractive tzdata

RUN curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && python /tmp/get-pip.py \
  && echo "[global]\nno-cache-dir = 0" > /etc/pip.conf \
  && pip install git+https://github.com/gnuradio/pybombs.git \
  && rm -rf /root/.cache/

RUN pybombs auto-config \
  && pybombs recipes add-defaults \
  && sed -i -e "s/-DENABLE_GR_QTGUI=ON/-DENABLE_GR_QTGUI=OFF/g" \
     -e "s/-DENABLE_DOXYGEN=$builddocs/-DENABLE_DOXYGEN=OFF -DENABLE_SPHINX=OFF/g" \
     /root/.pybombs/recipes/gr-recipes/gnuradio.lwr 

#RUN dpkg --print-architecture | grep -l arm && \
#    printf 'vars:\n config_opt: "-DCMAKE_C_FLAGS='\''-mfpu=neon'\'' -DCMAKE_CXX_FLAGS='\''-mfpu=neon'\''" \
#    \nconfigure_static: cmake .. -DCMAKE_INSTALL_PREFIX=$prefix $config_opt \n' >> /root/.pybombs/recipes/gr-recipes/uhd.lwr \
#    || exit 0

RUN pybombs prefix init ${PYBOMBS_PREFIX} -a master \
  && sed -i 's/3.6/2.7/g' ${PYBOMBS_PREFIX}/setup_env.sh \
  && pybombs config default_prefix master && pybombs config makewidth $(nproc) \
  && pybombs config --env DEBIAN_FRONTEND noninteractive \
  && pybombs config --package libqwt-dev forceinstalled true \
  && pybombs config --package libqwt5-qt4 forceinstalled true \
  && pybombs config --package pygtk forceinstalled true \
  && pybombs config --package pyqt4 forceinstalled true \
  && pybombs config --package pyqt4-dev-tools forceinstalled true \
  && pybombs config --package pyqwt5 forceinstalled true \
  && pybombs config --package python-qwt5-qt4 forceinstalled true \
  && pybombs config --package qt4 forceinstalled true \
  && pybombs config --package qt5 forceinstalled true \
  && pybombs config --package qwt5 forceinstalled true \
  && pybombs config --package qwt6 forceinstalled true \
  && pybombs config --package wxpython forceinstalled true \
  && pybombs config --package soapysdr gitrev 349296050fc2d0d40e86b7834e9273599bfa387f \
  && pybombs config --package gr-iqbal gitbranch gr3.7 \
  && pybombs config --package uhd gitrev release_003_010_001_001 \
  && pybombs config --package gnuradio gitbranch maint-3.7

RUN apt-get update && apt-get install -y python-mako python-numpy python-requests python-cheetah libcppunit-dev \
    python-zmq libzmq3-dev liblog4cpp5-dev python-pyqt5 pyqt5-dev-tools pyqt5-dev python-click-plugins \
    python-cairo-dev python-lxml libasound2-dev libgmp-dev libgsl-dev swig3.0 libfftw3-dev libfftw3-3 cmake-data \
    cmake doxygen libboost-all-dev libusb-1.0-0-dev liborc-0.4-dev python-gtk2-dev

RUN pybombs -vv install mako numpy 
RUN apt-get update && pybombs -v install --deps-only uhd \
    && pybombs -v install --deps-only gnuradio 

RUN pybombs -vv install uhd 
RUN pybombs -vv install gnuradio 

RUN rm -rf /tmp/* /pybombs/share/doc /pybombs/lib/uhd/tests \
    && apt-get -y autoremove --purge && apt-get -y clean \
    && apt-get -y autoclean && rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "/bin/bash" ]

FROM gnuradio as dependencies

WORKDIR /pybombs/

RUN apt-get update && pybombs -v install --deps-only \
  soapysdr \
  soapyremote \
  soapybladerf \
  gr-osmosdr \
  bladeRF \
  gr-op25 \
  gr-lte \
  rtl_433 

RUN pybombs -v install \
  soapysdr \
  soapyremote \
  soapybladerf \
  gr-osmosdr \
  bladeRF \
  gr-op25 \
  gr-lte \
  rtl_433 

RUN (echo "vars:" ; echo "  config_opt: '-DENABLE_GRGSM_LIVEMON=OFF '" ) \
  >> /root/.pybombs/recipes/gr-etcetera/gr-gsm.lwr
RUN pybombs config --package libosmocore gitrev 0.11.0
RUN apt-get update && pybombs -v install --deps-only gr-gsm
#RUN pybombs -v install gr-gsm
RUN pybombs -v fetch gr-gsm

RUN (echo "vars:" ; echo "  config_opt: '-DCMAKE_CXX_FLAGS=\" -fpermissive -Wno-narrowing\" -DCMAKE_C_FLAGS=\" -fpermissive -Wno-narrowing\" '" ) \
  >> /root/.pybombs/recipes/gr-recipes/openlte.lwr

RUN apt-get update && pybombs -v install --deps-only openlte
RUN pybombs -v install openlte

COPY src/ /root/.pybombs/recipes/gr-etcetera/
RUN apt-get update && pybombs -v install --deps-only libbtbb && pybombs -v install libbtbb
RUN apt-get update && pybombs -v install --deps-only ubertooth && pybombs -v install ubertooth

RUN sed 's/@BLADERF_GROUP@/plugdev/g' ./src/bladeRF/host/misc/udev/88-nuand-bladerf1.rules.in > ./src/bladeRF/host/misc/udev/88-nuand-bladerf1.rules \
  && sed 's/@BLADERF_GROUP@/plugdev/g' ./src/bladeRF/host/misc/udev/88-nuand-bladerf2.rules.in > ./src/bladeRF/host/misc/udev/88-nuand-bladerf2.rules \
  && sed 's/@BLADERF_GROUP@/plugdev/g' ./src/bladeRF/host/misc/udev/88-nuand-bootloader.rules.in > ./src/bladeRF/host/misc/udev/88-nuand-bootloader.rules \
  && mkdir -p /etc/udev/rules.d/ \
  && cp ./src/bladeRF/host/misc/udev/88-nuand-bladerf1.rules /etc/udev/rules.d/ \
  && cp ./src/bladeRF/host/misc/udev/88-nuand-bladerf2.rules /etc/udev/rules.d/ \
  && cp ./src/bladeRF/host/misc/udev/88-nuand-bootloader.rules /etc/udev/rules.d/ \
  && cp ./src/ubertooth/host/build/misc/udev/40-ubertooth.rules /etc/udev/rules.d/ \
  && cp ./src/osmo-sdr/software/libosmosdr/osmosdr.rules /etc/udev/rules.d/ \
  && cp ./src/airspy/airspy-tools/52-airspy.rules /etc/udev/rules.d/ \
  && cp ./src/rtl-sdr/rtl-sdr.rules /etc/udev/rules.d/ \
  && cp ./src/hackrf/host/libhackrf/53-hackrf.rules /etc/udev/rules.d/ \
  && cp ./src/uhd/host/utils/uhd-usrp.rules /etc/udev/rules.d/


RUN apt-get update && apt-get install -y \
    build-essential \
    libmicrohttpd-dev \
    pkg-config \
    zlib1g-dev \
    libnl-3-dev \
    libnl-genl-3-dev \
    libcap-dev \
    libpcap-dev \
    libnm-dev \
    libdw-dev \
    libsqlite3-dev \
    libprotobuf-dev \
    libprotobuf-c-dev \
    protobuf-compiler \
    protobuf-c-compiler \
    libsensors4-dev \
    python3 \
    python3-setuptools \
    python3-protobuf \
    python3-usb \
    python3-numpy \
    python3-dev \
    python3-pip \
    python3-serial \
    librtlsdr0 \
    libusb-1.0-0-dev 


WORKDIR /pybombs/src

RUN . ${PYBOMBS_PREFIX}/setup_env.sh && ldconfig \
    && git clone https://www.kismetwireless.net/git/kismet.git && cd kismet \
    && CFLAGS="-I${PYBOMBS_PREFIX}/include" CXXFLAGS="-I${PYBOMBS_PREFIX}/include" \
       ./configure --prefix ${PYBOMBS_PREFIX} --with-suidgroup=dialout \
    && CFLAGS="-I${PYBOMBS_PREFIX}/include" CXXFLAGS="-I${PYBOMBS_PREFIX}/include" \
       make -j $(nproc) && make suidinstall && make forceconfigs

RUN find ${PYBOMBS_PREFIX} /etc/udev -name "*.rules"

COPY kismet_site.conf /usr/local/etc/kismet_site.conf

EXPOSE 2501
EXPOSE 3501

#RUN rm -rf /tmp/* && apt-get -y autoremove --purge \
#  && apt-get -y clean && apt-get -y autoclean && rm -rf ./src

ENV INITSYSTEM on

ENTRYPOINT [ "/bin/bash" ]
