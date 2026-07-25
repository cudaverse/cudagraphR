# Changelog

## cudagraphR 0.1.2

- Named kNN observations now become graph vertex names, sparse adjacency
  dimnames, and community-membership names.

## cudagraphR 0.1.1

- Documented and tested composition with the bounded-memory batched
  [`cudalearnr::cuda_knn()`](https://cudaverse.github.io/cudalearnr/reference/cuda_knn.html)
  result.
- Mutual kNN graphs now require both directed neighbour relations
  instead of counting duplicate occurrences of an undirected key.
- Duplicate neighbours within one observation are rejected, and
  asymmetric reciprocal weights retain the stronger affinity.
