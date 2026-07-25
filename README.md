# cudagraphR

`cudagraphR` is the graph layer of the **cudaverse**. It turns
GPU-aware nearest-neighbour results into sparse R graphs and provides a stable
community-detection interface for omics workflows.

## Current capabilities

- union and mutual kNN graph construction;
- binary, inverse-distance, and Gaussian edge weights;
- sparse symmetric `Matrix` adjacency;
- Louvain and Leiden clustering through `igraph`;
- direct composition with `cudalearnr::cuda_knn()`.

Distance and neighbour computation may run on CUDA upstream. In version 0.1.2,
graph assembly and community detection run on the CPU; the returned objects
record both the source device and graph backend.

## Installation

```r
# install.packages("pak")
pak::pak(c(
  "cudaverse/cudagraphR",
  "cudaverse/cudalearnr"
))
```

This installs graph construction and the optional upstream kNN integration.
Community detection additionally requires `igraph`:

```r
pak::pak("igraph")
```

## Build a graph

```r
library(cudalearnr)
library(cudagraphR)

neighbors <- cuda_knn(
  matrix(rnorm(300), 100, 3),
  k = 10,
  batch_size = 32
)
graph <- cuda_knn_graph(neighbors, weighting = "gaussian")

graph
as_adjacency_matrix(graph)
```

Graph construction does not require `igraph`. Once the optional package is
installed, cluster the same graph:

```r
communities <- cuda_leiden(graph)
communities$membership
```

When the kNN input has observation row names, those identifiers are preserved
as graph adjacency dimnames and as names on community memberships. This keeps
clusters aligned with the original rows even after results are reordered or
joined with metadata.

See the cudaverse
[end-to-end workflow](https://github.com/cudaverse/.github/blob/main/WORKFLOW.md)
for the full counts-to-neighbours-to-graph path and its matrix orientation.

For installation, device verification, source-device interpretation, and
common failures, see the cudaverse
[GPU setup and troubleshooting guide](https://github.com/cudaverse/.github/blob/main/GPU_SETUP.md).

## License

MIT © Yaoxiang Li
