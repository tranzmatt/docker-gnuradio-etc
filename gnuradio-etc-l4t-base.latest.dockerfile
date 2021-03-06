FROM nvcr.io/nvidia/l4t-base:r32.3.1 AS gnuradio

ENV DEBIAN_FRONTEND noninteractive
ENV PYBOMBS_PREFIX=/pybombs

RUN echo "America/New_York" > /etc/timezone

RUN apt-get update \
    && apt-get -f -y install libhdf5-serial-dev hdf5-tools libhdf5-dev zlib1g-dev zip libjpeg8-dev python-h5py python3-h5py

RUN apt-get install -f -y python3-pip \
    && pip3 install -U pip \
    && pip3 install -U pip testresources setuptools \
    && pip3 install -U numpy==1.16.1 future==0.17.1 mock==3.0.5 \
       keras_preprocessing==1.0.5 keras_applications==1.0.8 gast==0.2.2 enum34 futures protobuf

RUN find /usr/include -name hdf5.h
RUN ls -l /usr/include/hdf5/serial/hdf5.h
RUN CFLAGS="-I/usr/include/hdf5/serial" LDFLAGS="-L/usr/lib/aarch64-linux-gnu/hdf5/serial" \
    pip install --no-binary=h5py h5py==2.9.0 

ARG JP_VERSION=43

RUN pip3 install --pre --extra-index-url https://developer.download.nvidia.com/compute/redist/jp/v$JP_VERSION tensorflow-gpu
RUN pip3 install --extra-index-url https://developer.download.nvidia.com/compute/redist/jp/v$JP_VERSION tensorflow-gpu
#RUN pip3 install --extra-index-url https://developer.download.nvidia.com/compute/redist/jp/v$JP_VERSION tensorflow-gpu==$TF_VERSION+nv$NV_VERSION

#RUN apt-get update && apt-get -y install nvidia-l4t-tools

#RUN nvpmodel -m 0



