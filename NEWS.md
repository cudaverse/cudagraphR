# cudagraphR 0.1.1

- Mutual kNN graphs now require both directed neighbour relations instead of
  counting duplicate occurrences of an undirected key.
- Duplicate neighbours within one observation are rejected, and asymmetric
  reciprocal weights retain the stronger affinity.
