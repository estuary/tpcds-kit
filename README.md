# tpcds-kit

## Estuary fork

This is [Estuary](https://estuary.dev)'s fork of [gregrahn/tpcds-kit](https://github.com/gregrahn/tpcds-kit).
It exists to drive the `source-tpc-ds` capture connector in
[estuary/connectors](https://github.com/estuary/connectors), which runs `dsdgen`
as a subprocess in stdout mode. The generator source remains subject to the TPC
legal notice in [EULA.txt](EULA.txt) and at the top of every source file; the
fork redistributes it with that notice intact, as DuckDB and Trino do.

Changes on top of upstream, one commit each (diff `master` against upstream's
`master` to see them all):

1. `print`: the stdout option was registered as `_FILTER` but checked as
   `FILTER`, so stdout mode never engaged.
2. `print`: after selecting stdout the handle was overwritten by the table's
   NULL file pointer ("Failed to open output file"). Also flush rather than
   fclose stdout so a parent and its child table can both close it.
3. `parallel`: `-PARALLEL`/`-CHILD` only chunked tables of 1M rows or more and
   silently emitted nothing for other children of smaller tables. An explicit
   `-PARALLEL` now chunks every table. Chunked output concatenates
   byte-identically to unchunked output.
4. `driver`: hidden `-_ROWCOUNT Y` flag prints the row count of `-TABLE` at
   `-SCALE` and exits, following the existing hidden-flag convention.
5. `build`: prototypes for three K&R-style definitions so the tree compiles
   under gcc 14 and current clang without `-std=gnu89`.
6. `scale`: fractional scale factors below 1, ported from DuckDB's tpcds
   extension. Every table starts from its 1GB row count and is multiplied by
   the fraction (floor of one row), except the fixed-size tables (date_dim,
   time_dim, catalog_page, ship_mode, income_band and similar). Row counts at
   sf=0.01 match `dsdgen(sf=0.01)` in DuckDB for every directly generated
   table. Row *content* follows upstream dsdgen; DuckDB's embedded copy
   diverges from upstream in text and null generation, so DuckDB's shipped
   answer sets do not describe this output.
7. `params`: string parameters up to 4095 characters (paths were strcpy'd into
   80-byte buffers).
8. `driver`: a command line over 200 characters produced a NULL dereference in
   `ReportError`; it is now a warning and the recorded string is truncated.
9. `parallel`: when a chunk's first row fell exactly on a day boundary,
   `skipDays` placed it on the following day and shifted that day's rows, so
   chunked output differed from a serial run. Rare at 1GB and above, frequent
   below. Chunks now concatenate byte-identically at every scale.

### Container image

[`Dockerfile`](Dockerfile) builds `dsdgen` as a static Linux binary and ships
it with `tpcds.idx` in an empty image, published on every push to `master` as
`ghcr.io/estuary/dsdgen:<7-char commit sha>` and `:latest` for linux/amd64 and
linux/arm64. Consume it with `COPY --from`:

```dockerfile
COPY --from=ghcr.io/estuary/dsdgen:<sha> /dsdgen /tpcds.idx /usr/local/bin/
```

Stream a table to stdout, always passing the distributions file explicitly:

```
dsdgen -SCALE 0.01 -TABLE store_sales -PARALLEL 4 -CHILD 1 -_FILTER Y -DISTRIBUTIONS /usr/local/bin/tpcds.idx
```

The three returns tables are emitted by their sales parent's process,
interleaved on stdout; tell them apart by field count.

## Upstream README

The official TPC-DS tools can be found at [tpc.org](http://www.tpc.org/tpc_documents_current_versions/current_specifications.asp).

This version is based on v2.10.0 and has been modified to:

* Allow compilation under macOS (commit [2ec45c5](https://github.com/gregrahn/tpcds-kit/commit/2ec45c5ed97cc860819ee630770231eac738097c))
* Address obvious query template bugs like
  * query22a: [#31](https://github.com/gregrahn/tpcds-kit/issues/31)
  * query77a: [#43](https://github.com/gregrahn/tpcds-kit/issues/43)
* Rename `s_web_returns` column `wret_web_site_id` to `wret_web_page_id` to match specification. See [#22](https://github.com/gregrahn/tpcds-kit/issues/22) & [#42](https://github.com/gregrahn/tpcds-kit/issues/42).

To see all modifications, diff the files in the master branch to the version branch. Eg: `master` vs `v2.10.0`.

## Setup

### Linux

Make sure the required development tools are installed:

Ubuntu:
```
sudo apt-get install gcc make flex bison byacc git
```

CentOS/RHEL:
```
sudo yum install gcc make flex bison byacc git
```

Then run the following commands to clone the repo and build the tools:

```
git clone https://github.com/gregrahn/tpcds-kit.git
cd tpcds-kit/tools
make OS=LINUX
```

### macOS

Make sure the required development tools are installed:

```
xcode-select --install
```

Then run the following commands to clone the repo and build the tools:

```
git clone https://github.com/gregrahn/tpcds-kit.git
cd tpcds-kit/tools
make OS=MACOS
```

## Using the TPC-DS tools

### Data generation

Data generation is done via `dsdgen`.  See `dsdgen -help` for all options.  If you do not run `dsdgen` from the `tools/` directory then you will need to use the option `-DISTRIBUTIONS /.../tpcds-kit/tools/tpcds.idx`. The output directory (specified via the `-DIR` option) must exist prior to running `dsdgen`. 

### Query generation

Query generation is done via `dsqgen`.   See `dsqgen -help` for all options.

The following command can be used to generate all 99 queries in numerical order (`-QUALIFY`) for the 10TB scale factor (`-SCALE`) using the Netezza dialect template (`-DIALECT`) with the output going to `/tmp/query_0.sql` (`-OUTPUT_DIR`).

```
dsqgen \
-DIRECTORY ../query_templates \
-INPUT ../query_templates/templates.lst \
-VERBOSE Y \
-QUALIFY Y \
-SCALE 10000 \
-DIALECT netezza \
-OUTPUT_DIR /tmp
```
