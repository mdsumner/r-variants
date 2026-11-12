# Values at (x, y, t) points from a chunked array

One value per point: the cell containing (x, y) at the time step nearest
t (or interpolated). The cost of this job is set by how many distinct
chunks the points fall in, not by the number of points. altarr makes that
the default: `x[cbind(i, j, k)]` hands every point to the lazy array at
once, altarr plans the distinct chunks, and the store's fetch gets them in
one batch.

This works on stock R. Base R passes a matrix subscript to ALTREP whole,
so the `baseline` and `array-subset` images behave the same here. The
array-subset hook matters for the rectangular reads next to this one: a
full time series at a station, `x[i, j, ]`, or a box around each point.

## Run it

From the root of this repository:

```sh
# offline: cost model and a synthetic lazy array, no network needed
docker run --rm -v "$PWD:/work" -w /work/examples/xyt-points \
  ghcr.io/mdsumner/r-variants:baseline bash run.sh

# plus 300 points from the live CMEMS global waves Zarr
docker run --rm -v "$PWD:/work" -w /work/examples/xyt-points \
  ghcr.io/mdsumner/r-variants:baseline bash run.sh live VHM0 300

# plus the same with chunk decoding on a mizu pool
docker run --rm -v "$PWD:/work" -w /work/examples/xyt-points \
  ghcr.io/mdsumner/r-variants:baseline bash run.sh mizu VHM0 300 4
```

`install.R` installs altarr and zaro from GitHub and blosc (and mizu for
the last one) from CRAN on first run.

## Files

| File | What it does |
| --- | --- |
| `cost.R` | Base R model, no data read: chunks touched by four read strategies, for three point sets and three chunk layouts |
| `xyt_extract.R` | `xyt_extract(x, coords, px, py, pt, method)`: nearest or linear (8-value stencil), one `x[idx]` call either way; works on plain arrays too |
| `offline.R` | A synthetic lazy array with the CMEMS chunk layout; planned vs per-point fetch calls, and the stencil |
| `cmems.R` | 300 points from CMEMS `GLOBAL_MULTIYEAR_WAV_001_032` (0.2 degree, 3-hourly) through `zaro_array()` |
| `cmems_mizu.R` | The same, fetching in the main process and decoding chunks on a [mizu](https://github.com/shikokuchuo/mizu) task pool; times fetch and decode separately |

## What the cost model says

BRAN2023-sized array (3600 x 1500 x 5479 days, int16), uncompressed MB of
the chunks each strategy touches:

| Points | Chunk layout (t x y x x) | Per point | Per layer | Full series | Planned |
| --- | --- | --- | --- | --- | --- |
| 1000 random xyt | 1 x 300 x 300 | 180 | 180 | 59173 | 180 |
| | 365 x 30 x 30 | 657 | 657 | 9766 | 652 |
| track, 1000 fixes over 250 days | 1 x 300 x 300 | 180 | 45 | 986 | 45 |
| | 365 x 30 x 30 | 657 | 205 | 116 | 7 |
| 50 stations x 730 days | 1 x 300 x 300 | 6570 | 3942 | 29587 | 3942 |
| | 365 x 30 x 30 | 23981 | 23981 | 526 | 99 |

- Planning is never worse than the best alternative, and is one batch.
- With map-shaped chunks it matches a layer-by-layer read in bytes; the
  gain is one batch instead of one read per time step.
- When chunks span time, only a planned read can use it: tracks and
  stations drop by 6x to 40x.
- Randomly scattered points cost about one chunk each whatever you do.
  Smaller chunks, or Zarr v3 shards with small inner chunks, are the
  levers there.
- Linear interpolation is nearly free when planned (corners share
  chunks), except time interpolation on one-step-per-chunk layouts, which
  doubles the chunk count.

## The CMEMS store, and doing it by hand

The geoChunked waves store has chunks of 17720 time steps x 8 lat x 4 lon
(about 2.3 MB each as float32, blosc lz4). 300 random Southern Ocean
points over 90 days fall in 271 distinct chunks, so 271 GETs is the floor
for any reader.

A layer-oriented reader such as terra can reach that floor too, by
grouping points by chunk key, reading each group's contiguous layer range
as one slab, picking each point's layer, and running groups across worker
processes ([an example](https://gist.github.com/mdsumner/73366667ed1bcf9a6b9ff9b77cde459d)).
With altarr and zaro that grouping is what `x[idx]` already does, and the
concurrency is one capped curl pool in one process. What the terra route
keeps is CRS, cell geometry and time handling for free; here the
coordinate to index step is a few lines because the grid is regular.

## Where mizu fits

Once the batch is planned and fetched, what is left is decoding every
chunk on R's main thread. `cmems_mizu.R` keeps the HTTP in the main
process and maps the decode over a mizu pool, which moves vectors
through shared memory, so decoded chunks come back without serializing
through sockets. It prints fetch and decode time for both, so you can see
whether decode is worth spreading for a given store: with lz4 and a few
hundred chunks HTTP usually dominates; with zlib or zstd, or thousands of
chunks, decode starts to show.
