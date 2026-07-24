example_knn <- function() {
  list(
    index = matrix(
      c(2, 3, 1, 3, 4, 1, 3, 2),
      nrow = 4,
      byrow = TRUE
    ),
    distance = matrix(
      c(1, 2, 1, 1.5, 0.5, 2, 0.5, 1.5),
      nrow = 4,
      byrow = TRUE
    ),
    device = "cpu"
  )
}

test_that("kNN graphs are sparse, symmetric, and weighted", {
  graph <- cuda_knn_graph(example_knn(), weighting = "distance")
  adjacency <- as_adjacency_matrix(graph)

  expect_s3_class(graph, "cuda_graph")
  expect_s4_class(adjacency, "dgCMatrix")
  expect_identical(dim(adjacency), c(4L, 4L))
  expect_equal(as.matrix(adjacency), t(as.matrix(adjacency)))
  expect_true(all(adjacency@x > 0 & adjacency@x <= 1))
  expect_identical(graph$source_device, "cpu")
})

test_that("mutual graph keeps reciprocal neighbours", {
  graph <- cuda_knn_graph(example_knn(), symmetrize = "mutual")
  expect_lt(graph$edges, cuda_knn_graph(example_knn())$edges)
  expect_equal(as.matrix(graph$adjacency), t(as.matrix(graph$adjacency)))
})

test_that("cudalearnr results compose when available", {
  skip_if_not_installed("cudalearnr")
  set.seed(1)
  neighbors <- cudalearnr::cuda_knn(
    matrix(rnorm(36), 12, 3),
    k = 3,
    device = "cpu"
  )
  graph <- cuda_knn_graph(neighbors)
  expect_identical(graph$vertices, 12L)
})

test_that("Louvain and Leiden return memberships", {
  skip_if_not_installed("igraph")
  graph <- cuda_knn_graph(example_knn())
  set.seed(1)
  louvain <- cuda_louvain(graph)
  set.seed(1)
  leiden <- cuda_leiden(graph)

  expect_s3_class(louvain, "cuda_communities")
  expect_s3_class(leiden, "cuda_communities")
  expect_length(louvain$membership, 4)
  expect_length(leiden$membership, 4)
})

test_that("invalid graph inputs fail clearly", {
  bad <- example_knn()
  bad$index[1, 1] <- 1
  expect_error(cuda_knn_graph(bad), "self-links")
  expect_error(cuda_knn_graph(example_knn(), sigma = -1), NA)
  expect_error(cuda_knn_graph(
    example_knn(), weighting = "gaussian", sigma = -1
  ), "positive finite")
  expect_error(cuda_louvain(
    cuda_knn_graph(example_knn()), resolution = 0
  ), "positive finite")
})
