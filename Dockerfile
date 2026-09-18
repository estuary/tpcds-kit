# Builds the TPC-DS data generator as a static Linux binary and ships it, with
# its distributions file, in an empty image for COPY --from in other builds.
FROM debian:trixie-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends gcc make libc6-dev && rm -rf /var/lib/apt/lists/*
COPY tools /src/tools
WORKDIR /src/tools
RUN make OS=LINUX LINUX_CFLAGS="-O2 -Wall -ffp-contract=off" LDFLAGS="-static" dsdgen tpcds.idx
# Guard against toolchain drift: customer at sf=1 must match the reference digest.
RUN test "$(./dsdgen -SCALE 1 -TABLE customer -_FILTER Y -DISTRIBUTIONS /src/tools/tpcds.idx 2>/dev/null | md5sum | cut -c1-32)" = a08066ed04041d3370f923a9a3969900 \
 && test "$(./dsdgen -SCALE 0.01 -TABLE store_sales -_ROWCOUNT Y -DISTRIBUTIONS /src/tools/tpcds.idx 2>/dev/null)" = 2400

FROM scratch
COPY --from=build /src/tools/dsdgen /dsdgen
COPY --from=build /src/tools/tpcds.idx /tpcds.idx
