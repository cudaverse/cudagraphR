# cudagraphR 0.2.0

- Graph assembly and community detection now expose the shared stage-level
  provenance schema and explicitly report CPU computation independently from
  an upstream CUDA kNN source.
- Graphs retain their kNN source provenance; community results retain both
  graph and upstream provenance.
- Gaussian graphs record the effective bandwidth chosen when `sigma = NULL`,
  and Leiden results record the effective `n_iterations`.
- Compatible neighbour lists now validate their optional device metadata.

# cudagraphR 0.1.2

- Named kNN observations now become graph vertex names, sparse adjacency
  dimnames, and community-membership names.

# cudagraphR 0.1.1

- Documented and tested composition with the bounded-memory batched
  `cudalearnr::cuda_knn()` result.
- Mutual kNN graphs now require both directed neighbour relations instead of
  counting duplicate occurrences of an undirected key.
- Duplicate neighbours within one observation are rejected, and asymmetric
  reciprocal weights retain the stronger affinity.
