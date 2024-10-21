FROM amazonlinux:2023

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# Install packages
RUN dnf update -y
RUN dnf install -y automake \
  cpio \
  gcc-c++ \
  git \
  gnutls \
  gnutls-devel \
  gnutls-utils \
  less \
  libtool \
  libtool-ltdl-devel \
  m4 \
  python3-pip \
  unzip \
  yum-utils \
  zip

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3 install -r requirements.txt
RUN rm -rf /root/.cache/pip

WORKDIR /tmp
RUN mkdir libprelude \
  && git clone https://github.com/Prelude-SIEM/libprelude.git \
  && cd libprelude \
  && ./autogen.sh \
  && ./configure \
  && make

# Download libraries we need to run in lambda
RUN dnf download -x \*i686 --archlist=aarch64 \
  clamav \
  clamav-lib \
  clamav-update \
  json-c \
  pcre2 \
  # libprelude \
  # gnutls \
  libtasn1 \
  lib64nettle \
  nettle
RUN rpm2cpio clamav-1*.rpm | cpio -idmv
RUN rpm2cpio clamav-lib*.rpm | cpio -idmv
RUN rpm2cpio clamav-update*.rpm | cpio -idmv
RUN rpm2cpio json-c*.rpm | cpio -idmv
RUN rpm2cpio pcre*.rpm | cpio -idmv
RUN rpm2cpio nettle* | cpio -idmv
RUN rpm2cpio lib* | cpio -idmv
RUN rpm2cpio *.rpm | cpio -idmv
RUN rpm2cpio libtasn1* | cpio -idmv

# Copy over the binaries and libraries
RUN cp /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/lib64/* /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /usr/local/lib/python3.7/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *

WORKDIR /opt/app
