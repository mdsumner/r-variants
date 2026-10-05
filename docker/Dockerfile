# R-devel with a variant's patches, as a container image.
#
#   docker build -f docker/Dockerfile --build-arg VARIANT=array-subset -t r-variant .
#   docker run --rm -it r-variant
#
# Build args:
#   VARIANT     a directory under variants/            (default: baseline)
#   R_SVN_REF   commit, branch or tag of r-devel/r-svn (default: main)
#   MAKE_CHECK  true to run 'make check' while building (default: false)
FROM ubuntu:24.04

ARG VARIANT=baseline
ARG R_SVN_REF=main
ARG MAKE_CHECK=false

LABEL org.opencontainers.image.source="https://github.com/mdsumner/r-variants"
LABEL org.opencontainers.image.description="R-devel built with proposed changes (r-variants)"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC

# Build dependencies stay in the image, so packages with compiled code can
# be installed in it.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential gfortran git ca-certificates curl locales pkg-config \
      libreadline-dev libpcre2-dev liblzma-dev libbz2-dev zlib1g-dev \
      libicu-dev libcurl4-openssl-dev libblas-dev liblapack-dev \
      libpng-dev libjpeg-dev libtiff-dev libcairo2-dev \
 && localedef -i en_US -f UTF-8 en_US.UTF-8 \
 && rm -rf /var/lib/apt/lists/*

COPY scripts/build-r.sh /opt/r-variants/build-r.sh
COPY variants/${VARIANT}/ /opt/r-variants/variant/

RUN VARIANT_DIR=/opt/r-variants/variant R_SVN_REF="${R_SVN_REF}" \
    MAKE_CHECK="${MAKE_CHECK}" /opt/r-variants/build-r.sh

ENV PATH=/opt/R/variant/bin:$PATH
CMD ["R"]
