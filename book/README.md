# Lazy arrays in base R: the book

Worked examples for the proposed ALTREP `Extract_array_subset` method
(the [`array-subset`](../variants/array-subset) variant): what
`x[i, j, k]` costs on a lazy array today, and what it costs when R hands
the request over whole. Synthetic stores, Copernicus Marine Zarr, a
reference store over NetCDF on THREDDS, sharded Zarr V3 and Icechunk.

Each example is a script in `scripts/` that the book runs under stock and
patched R-devel in one container. Render it:

```sh
# from the top of this repository
docker run --rm -v "$PWD:/work" -w /work/book \
  ghcr.io/mdsumner/r-variants:book bash run.sh

# on Setonix
sbatch --account=$PAWSEY_PROJECT book/pawsey/render.slurm
```

The rendered book is `book/_book/index.html`. `rebuild.qmd` has the rest:
the image, the settings, running one script by hand, adding an example.
