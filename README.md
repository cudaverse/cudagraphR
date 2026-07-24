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

Distance and neighbour computation may run on CUDA upstream. In version 0.1.0,
graph assembly and community detection run on the CPU; the returned objects
record both the source device and graph backend.

## Installation

```r
# install.packages("pak")
pak::pak("cudaverse/cudagraphR")
```

## Example

```r
library(cudalearnr)
library(cudagraphR)

neighbors <- cuda_knn(matrix(rnorm(300), 100, 3), k = 10)
graph <- cuda_knn_graph(neighbors, weighting = "gaussian")
communities <- cuda_leiden(graph)

communities$membership
```

## License

MIT © Yaoxiang Li
