# The book image: stock and patched R-devel side by side, with the
# packages the examples use and Quarto.
#
#   docker build -f book/docker/Dockerfile -t r-variants-book .
#   docker run --rm -v "$PWD:/work" -w /work/book r-variants-book bash run.sh
#
# Both builds of R come from the published variant images. Each was
# installed to /opt/R/variant, so the stock one is moved to
# /opt/R/baseline and the paths recorded in its text files are rewritten.
#
# Build args:
#   BASELINE, PATCHED   the two variant images
#   ALTARR_REF          altarr branch with the method      (exp/r-hook)
#   ZARO_REF            zaro branch                        (main)
#   QUARTO_VERSION      Quarto release                     (1.6.42)
#   WITH_ICECHUNK       true to install Rust and tabularberg (adds a long
#                       compile; chapter 6 has no table without it)
ARG BASELINE=ghcr.io/mdsumner/r-variants:baseline
ARG PATCHED=ghcr.io/mdsumner/r-variants:array-subset

FROM ${BASELINE} AS baseline

FROM ${PATCHED}

ARG ALTARR_REF=exp/r-hook
ARG ZARO_REF=main
ARG QUARTO_VERSION=1.6.42
ARG WITH_ICECHUNK=false

LABEL org.opencontainers.image.source="https://github.com/mdsumner/r-variants"
LABEL org.opencontainers.image.description="Stock and patched R-devel with altarr, zaro and Quarto (r-variants book)"

COPY --from=baseline /opt/R/variant /opt/R/baseline
RUN grep -rIl '/opt/R/variant' /opt/R/baseline \
      | xargs -r sed -i 's#/opt/R/variant#/opt/R/baseline#g' \
 && test "$(/opt/R/baseline/bin/Rscript -e 'cat(R.home())')" = "/opt/R/baseline/lib/R" \
 && test "$(/opt/R/variant/bin/Rscript -e 'cat(R.home())')" = "/opt/R/variant/lib/R"

RUN apt-get update \
 && apt-get install -y --no-install-recommends libssl-dev cmake \
 && curl -fsSL -o /tmp/quarto.deb \
      "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" \
 && apt-get install -y --no-install-recommends /tmp/quarto.deb \
 && rm -rf /tmp/quarto.deb /var/lib/apt/lists/*

COPY book/docker/install-packages.sh /opt/r-variants/install-packages.sh
RUN ALTARR_REF="${ALTARR_REF}" ZARO_REF="${ZARO_REF}" WITH_ICECHUNK="${WITH_ICECHUNK}" \
    bash /opt/r-variants/install-packages.sh

ENV BOOK_R_STOCK=/opt/R/baseline/bin/Rscript \
    BOOK_R_PATCHED=/opt/R/variant/bin/Rscript
CMD ["R"]
