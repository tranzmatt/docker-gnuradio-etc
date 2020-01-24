### Template for balena.io container builder.

FROM resin/raspberrypi3-ubuntu:bionic AS gnuradio

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
  && rm -rf /var/lib/apt/lists/*

RUN dpkg-reconfigure -f noninteractive tzdata

RUN curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && python /tmp/get-pip.py \
  && echo "[global]\nno-cache-dir = 0" > /etc/pip.conf \
  && pip install git+git://github.com/gnuradio/pybombs.git \
  && rm -rf /root/.cache/

RUN pybombs auto-config \
  && pybombs recipes add-defaults \
  && sed -i -e "s/-DENABLE_GRC=ON/-DENABLE_GRC=OFF/g" -e "s/-DENABLE_GR_QTGUI=ON/-DENABLE_GR_QTGUI=OFF/g" -e "s/-DENABLE_DOXYGEN=$builddocs/-DENABLE_DOXYGEN=OFF/g" \
     /root/.pybombs/recipes/gr-recipes/gnuradio.lwr 

#RUN dpkg --print-architecture | grep -l arm && \
#    printf 'vars:\n config_opt: "-DCMAKE_C_FLAGS='\''-mfpu=neon'\'' -DCMAKE_CXX_FLAGS='\''-mfpu=neon'\''" \
#    \nconfigure_static: cmake .. -DCMAKE_INSTALL_PREFIX=$prefix $config_opt \n' >> /root/.pybombs/recipes/gr-recipes/uhd.lwr \
#    || exit 0

COPY neon.patch /tmp
RUN dpkg --print-architecture | grep -l arm && \
    cat /tmp/neon.patch >> /root/.pybombs/recipes/gr-recipes/uhd.lwr || exit 0
RUN dpkg --print-architecture | grep -l arm && \
    sed -i 's/-DINSTALL_UDEV_RULES=OFF/-DINSTALL_UDEV_RULES=OFF -DCMAKE_C_FLAGS=" -mfpu=neon" -DCMAKE_CXX_FLAGS=" -mfpu=neon"/g' \
    /root/.pybombs/recipes/gr-recipes/bladeRF.lwr || exit 0
RUN dpkg --print-architecture | grep -l arm && \
    cat /tmp/neon.patch >> /root/.pybombs/recipes/gr-recipes/gr-op25.lwr || exit 0
  
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
  && pybombs config --package gnuradio gitbranch v3.7.13.5 \
  && pybombs config --package gr-iqbal gitbranch gr3.7 \
  && pybombs config --package gnuradio gitbranch maint-3.7

RUN apt-get update && apt-get install -y python-mako python-numpy python-requests python-cheetah libcppunit-dev 
RUN pybombs -vv install mako numpy 
RUN apt-get update && pybombs -v install --deps-only gnuradio && rm -rf /var/lib/apt/lists/* && rm -rf /pybombs/src
RUN apt-get update && pybombs -v install --deps-only uhd && rm -rf /var/lib/apt/lists/* && rm -rf /pybombs/src
RUN pybombs -vv install uhd
RUN pybombs -vv install gnuradio && rm -rf /pybombs/src/ /pybombs/share/doc /pybombs/lib/uhd/tests

RUN rm -rf /tmp/* && apt-get -y autoremove --purge \
  && apt-get -y clean && apt-get -y autoclean

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
  && rm -rf /var/lib/apt/lists/* && rm -rf /pybombs/src

RUN pybombs -v install \
  soapysdr \
  soapyremote \
  soapybladerf \
  gr-osmosdr \
  bladeRF \
  gr-op25 \
  gr-lte \
  && sed 's/@BLADERF_GROUP@/plugdev/g' ./src/bladeRF/host/misc/udev/88-nuand-bladerf1.rules.in > ./src/bladeRF/host/misc/udev/88-nuand-bladerf1.rules \
  && sed 's/@BLADERF_GROUP@/plugdev/g' ./src/bladeRF/host/misc/udev/88-nuand-bladerf2.rules.in > ./src/bladeRF/host/misc/udev/88-nuand-bladerf2.rules \
  && sed 's/@BLADERF_GROUP@/plugdev/g' ./src/bladeRF/host/misc/udev/88-nuand-bootloader.rules.in > ./src/bladeRF/host/misc/udev/88-nuand-bootloader.rules \
  && mkdir -p /etc/udev/rules.d/ \
  && cp ./src/bladeRF/host/misc/udev/88-nuand-bladerf1.rules /etc/udev/rules.d/ \
  && cp ./src/bladeRF/host/misc/udev/88-nuand-bladerf2.rules /etc/udev/rules.d/ \
  && cp ./src/bladeRF/host/misc/udev/88-nuand-bootloader.rules /etc/udev/rules.d/ \
  && rm -rf ./src/


RUN apt-get update && pybombs -v install --deps-only \
  rtl_433
RUN pybombs -v install \
  rtl_433

RUN apt-get update && pybombs -v install --deps-only \
  hackrf
RUN pybombs -v install \
  hackrf

RUN rm -rf /tmp/* && apt-get -y autoremove --purge \
  && apt-get -y clean && apt-get -y autoclean

ENV INITSYSTEM on

ENTRYPOINT [ "/bin/bash" ]
