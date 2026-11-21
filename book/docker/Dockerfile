# The book image: stock and patched R-devel side by side, with the
# packages the examples use and Quarto.
#
#   docker build -f book/docker/Dockerfile -t r-variants-book .
#   docker run --rm -v "$PWD:/work" -w /work/book r-variants-book bash run.sh
#
# Patched R comes from the published array-subset image. Stock R is built
# here, from the same r-devel/r-svn commit that image records, so the two
# differ by the patch and nothing else.
#
# Build args:
#   PATCHED             the array-subset image
#   ALTARR_REF          altarr branch with the method      (exp/r-hook)
#   ZARO_REF            zaro branch                        (main)
#   QUARTO_VERSION      Quarto release                     (1.6.42)
#   WITH_ICECHUNK       false to leave out Rust and tabularberg (a long
#                       compile; chapter 6 has no table without them)
ARG PATCHED=ghcr.io/mdsumner/r-variants:array-subset

FROM ${PATCHED}

ARG ALTARR_REF=exp/r-hook
ARG ZARO_REF=main
ARG QUARTO_VERSION=1.6.42
ARG WITH_ICECHUNK=true

LABEL org.opencontainers.image.source="https://github.com/mdsumner/r-variants"
LABEL org.opencontainers.image.description="Stock and patched R-devel with altarr, zaro and Quarto (r-variants book)"

COPY scripts/build-r.sh /opt/r-variants/book/build-r.sh
COPY variants/baseline/ /opt/r-variants/book/baseline/
RUN ref="$(sed -n 's/^r_svn_commit: //p' /opt/R/variant/VARIANT.txt)" \
 && test -n "$ref" \
 && VARIANT_DIR=/opt/r-variants/book/baseline R_SVN_REF="$ref" \
    PREFIX=/opt/R/baseline bash /opt/r-variants/book/build-r.sh

RUN apt-get update \
 && apt-get install -y --no-install-recommends libssl-dev cmake libblosc-dev libuv1-dev \
 && curl -fsSL -o /tmp/quarto.deb \
      "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" \
 && apt-get install -y --no-install-recommends /tmp/quarto.deb \
 && rm -rf /tmp/quarto.deb /var/lib/apt/lists/*

# Quarto renders with the patched build.
RUN /opt/R/variant/bin/Rscript -e ' \
      install.packages(c("knitr", "rmarkdown"), Ncpus = parallel::detectCores()); \
      stopifnot(requireNamespace("knitr", quietly = TRUE), \
                requireNamespace("rmarkdown", quietly = TRUE))'

COPY book/docker/install-packages.sh /opt/r-variants/install-packages.sh
RUN ALTARR_REF="${ALTARR_REF}" ZARO_REF="${ZARO_REF}" WITH_ICECHUNK="${WITH_ICECHUNK}" \
    bash /opt/r-variants/install-packages.sh

ENV BOOK_R_STOCK=/opt/R/baseline/bin/Rscript \
    BOOK_R_PATCHED=/opt/R/variant/bin/Rscript
CMD ["R"]
