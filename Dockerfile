FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG SKYFIRE_REF=main

ENV CC=gcc-14
ENV CXX=g++-14
ENV BOOST_ROOT=/opt/boost_1_91_0
ENV OPENSSL_ROOT_DIR=/opt/openssl-4.0.1
ENV LD_LIBRARY_PATH=/opt/openssl-4.0.1/lib64:/opt/openssl-4.0.1/lib

RUN apt-get update && \
    apt-get install -y software-properties-common ca-certificates && \
    add-apt-repository -y universe && \
    apt-get update && \
    apt-get install -y \
      build-essential gcc-14 g++-14 cmake ninja-build git wget \
      perl pkg-config bzip2 libbz2-dev libreadline-dev zlib1g-dev \
      default-libmysqlclient-dev libace-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/deps

RUN wget -q https://archives.boost.io/release/1.91.0/source/boost_1_91_0.tar.gz && \
    tar -xzf boost_1_91_0.tar.gz && \
    cd boost_1_91_0 && \
    ./bootstrap.sh --prefix=/opt/boost_1_91_0 && \
    ./b2 install --prefix=/opt/boost_1_91_0 --with-headers -j4

RUN wget -q https://www.openssl.org/source/openssl-4.0.1.tar.gz && \
    tar -xzf openssl-4.0.1.tar.gz && \
    cd openssl-4.0.1 && \
    ./Configure linux-x86_64 \
      --prefix=/opt/openssl-4.0.1 \
      --openssldir=/opt/openssl-4.0.1/ssl \
      shared enable-legacy && \
    make -j4 && \
    make install_sw install_ssldirs && \
    ldconfig

WORKDIR /src

RUN git clone https://github.com/ProjectSkyfire/SkyFire_548.git . && \
    git checkout "${SKYFIRE_REF}"

# Compatibility fix for std::setw/std::setfill when PCH is disabled.
RUN if ! grep -qE '^[[:space:]]*#include[[:space:]]*<iomanip>' \
      src/server/game/Server/Protocol/Opcodes.h; then \
      sed -i '/^[[:space:]]*#include[[:space:]]*"Common.h"/a #include <iomanip>' \
        src/server/game/Server/Protocol/Opcodes.h; \
    fi && \
    grep -qE '^[[:space:]]*#include[[:space:]]*<iomanip>' \
      src/server/game/Server/Protocol/Opcodes.h

RUN cmake -S . -B build/docker -G Ninja \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_INSTALL_PREFIX=/opt/skyfire-server \
      -DCMAKE_C_COMPILER=gcc-14 \
      -DCMAKE_CXX_COMPILER=g++-14 \
      -DBOOST_ROOT=/opt/boost_1_91_0 \
      -DOPENSSL_ROOT_DIR=/opt/openssl-4.0.1 \
      -DTOOLS=ON \
      -DAUTH_SERVER=ON \
      -DSCRIPTS=ON \
      -DNOPCH=1 \
    && cmake --build build/docker --parallel 4 \
    && cmake --install build/docker

RUN printf '%s\n' \
    '/opt/openssl-4.0.1/lib' \
    '/opt/openssl-4.0.1/lib64' \
    > /etc/ld.so.conf.d/skyfire-openssl.conf && \
    ldconfig

CMD ["/bin/bash"]
