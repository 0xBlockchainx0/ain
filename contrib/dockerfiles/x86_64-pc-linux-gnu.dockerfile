ARG TARGET=x86_64-pc-linux-gnu

# -----------
FROM ubuntu:18.04 as builder-base
ARG TARGET
LABEL org.defichain.name="defichain-builder-base"
LABEL org.defichain.arch=${TARGET}

RUN apt update && apt dist-upgrade -y

# Setup DeFiChain build dependencies. Refer to depends/README.md and doc/build-unix.md
# from the source root for info on the builder setup

RUN apt-get install -y apt-transport-https

RUN apt install -y software-properties-common build-essential libtool autotools-dev automake \
pkg-config bsdmainutils python3 libssl-dev libevent-dev libboost-system-dev \
libboost-filesystem-dev libboost-chrono-dev libboost-test-dev libboost-thread-dev \
libminiupnpc-dev libzmq3-dev libqrencode-dev wget \
curl cmake

# install clang 11
RUN wget https://apt.llvm.org/llvm.sh
RUN chmod +x llvm.sh
RUN ./llvm.sh 11

# For Berkeley DB - but we don't need as we do a depends build.
# RUN apt install -y libdb-dev

# -----------
FROM builder-base as depends-builder
ARG TARGET
LABEL org.defichain.name="defichain-depends-builder"
LABEL org.defichain.arch=${TARGET}

WORKDIR /work/depends
COPY ./depends .
# XREF: #depends-make
RUN make HOST=${TARGET} NO_QT=1 -j $(nproc)

# -----------
FROM builder-base as builder
ARG TARGET
LABEL org.defichain.name="defichain-builder"
LABEL org.defichain.arch=${TARGET}

WORKDIR /work

COPY --from=depends-builder /work/depends ./depends
COPY . .

RUN ./autogen.sh

# XREF: #make-configure
RUN ./configure CC=clang-11 CXX=clang++-11 --prefix=`pwd`/depends/${TARGET}

ARG BUILD_VERSION=

RUN make -j $(nproc)
RUN mkdir /app && make prefix=/ DESTDIR=/app install && cp /work/README.md /app/.

# -----------
### Actual image that contains defi binaries
FROM ubuntu:18.04
ARG TARGET
LABEL org.defichain.name="defichain"
LABEL org.defichain.arch=${TARGET}

WORKDIR /app

COPY --from=builder /app/. ./
