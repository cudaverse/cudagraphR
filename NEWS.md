# cudagraphR 0.1.1

- Documented and tested composition with the bounded-memory batched
  `cudalearnr::cuda_knn()` result.
- Mutual kNN graphs now require both directed neighbour relations instead of
  counting duplicate occurrences of an undirected key.
- Duplicate neighbours within one observation are rejected, and asymmetric
  reciprocal weights retain the stronger affinity.
