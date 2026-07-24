.graph_knn <- function(neighbors) {
  if (inherits(neighbors, "cuda_knn")) {
    index <- neighbors$index
    distance <- neighbors$distance
    source_device <- neighbors$device %||% "unknown"
  } else if (is.list(neighbors) &&
             all(c("index", "distance") %in% names(neighbors))) {
    index <- neighbors$index
    distance <- neighbors$distance
    source_device <- neighbors$device %||% "unknown"
  } else {
    stop(
      "`neighbors` must be a cuda_knn object or a list with index and distance.",
      call. = FALSE
    )
  }
  if (!is.matrix(index) || !is.matrix(distance) ||
      !identical(dim(index), dim(distance)) || nrow(index) < 2L ||
      ncol(index) < 1L) {
    stop("Neighbour index and distance must be same-sized matrices.",
         call. = FALSE)
  }
  if (anyNA(index) || any(index != as.integer(index)) ||
      any(index < 1L) || any(index > nrow(index))) {
    stop("Neighbour indices must identify valid graph vertices.",
         call. = FALSE)
  }
  if (anyNA(distance) || any(!is.finite(distance)) || any(distance < 0)) {
    stop("Neighbour distances must be finite and non-negative.",
         call. = FALSE)
  }
  row_index <- matrix(
    rep(seq_len(nrow(index)), each = ncol(index)),
    nrow = nrow(index),
    byrow = TRUE
  )
  if (any(index == row_index)) {
    stop("Neighbour indices cannot contain self-links.", call. = FALSE)
  }
  list(
    index = matrix(as.integer(index), nrow = nrow(index)),
    distance = distance,
    device = source_device
  )
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

.graph_weights <- function(distance, weighting, sigma) {
  if (weighting == "binary") {
    return(rep(1, length(distance)))
  }
  if (weighting == "distance") {
    return(1 / (1 + distance))
  }
  if (is.null(sigma)) {
    positive <- distance[distance > 0]
    sigma <- if (length(positive)) stats::median(positive) else 1
  }
  if (!is.numeric(sigma) || length(sigma) != 1L || is.na(sigma) ||
      !is.finite(sigma) || sigma <= 0) {
    stop("`sigma` must be a positive finite number.", call. = FALSE)
  }
  exp(-(distance^2) / (2 * sigma^2))
}

#' Build a sparse graph from nearest neighbours
#'
#' The input may have been computed on CUDA, but graph assembly itself is
#' currently performed on the CPU with a sparse `Matrix`.
#'
#' @param neighbors A `cudalearnr::cuda_knn()` result or compatible list.
#' @param weighting Edge weighting: binary, inverse-distance, or Gaussian.
#' @param symmetrize Keep the union or only mutual nearest-neighbour edges.
#' @param sigma Gaussian bandwidth. Defaults to the median positive distance.
#' @return A `cuda_graph` object.
#' @export
#' @examples
#' index <- matrix(c(2, 3, 1, 3, 1, 2), 3, byrow = TRUE)
#' distance <- matrix(c(1, 2, 1, 1, 2, 1), 3, byrow = TRUE)
#' cuda_knn_graph(list(index = index, distance = distance))
cuda_knn_graph <- function(neighbors,
                           weighting = c("binary", "distance", "gaussian"),
                           symmetrize = c("union", "mutual"),
                           sigma = NULL) {
  neighbors <- .graph_knn(neighbors)
  weighting <- match.arg(weighting)
  symmetrize <- match.arg(symmetrize)
  n <- nrow(neighbors$index)
  k <- ncol(neighbors$index)
  from <- rep(seq_len(n), each = k)
  to <- as.vector(t(neighbors$index))
  distance <- as.vector(t(neighbors$distance))
  weight <- .graph_weights(distance, weighting, sigma)

  low <- pmin(from, to)
  high <- pmax(from, to)
  key <- paste(low, high, sep = ":")
  split_weight <- split(weight, key)
  split_position <- split(seq_along(key), key)
  keep <- if (symmetrize == "mutual") {
    lengths(split_position) > 1L
  } else {
    rep(TRUE, length(split_position))
  }
  split_weight <- split_weight[keep]
  split_position <- split_position[keep]
  if (!length(split_weight)) {
    adjacency <- Matrix::sparseMatrix(
      i = integer(), j = integer(), x = numeric(), dims = c(n, n)
    )
  } else {
    edge_weight <- vapply(split_weight, max, numeric(1))
    first <- vapply(split_position, `[`, integer(1), 1L)
    edge_low <- low[first]
    edge_high <- high[first]
    adjacency <- Matrix::sparseMatrix(
      i = c(edge_low, edge_high),
      j = c(edge_high, edge_low),
      x = rep(edge_weight, 2L),
      dims = c(n, n)
    )
  }
  adjacency <- methods::as(adjacency, "dgCMatrix")
  structure(
    list(
      adjacency = adjacency,
      vertices = n,
      edges = length(split_weight),
      weighting = weighting,
      symmetrize = symmetrize,
      source_device = neighbors$device,
      backend = "Matrix"
    ),
    class = "cuda_graph"
  )
}

#' Extract a graph adjacency matrix
#'
#' @param graph A `cuda_graph`.
#' @return A symmetric sparse `Matrix::dgCMatrix`.
#' @export
as_adjacency_matrix <- function(graph) {
  if (!inherits(graph, "cuda_graph")) {
    stop("`graph` must be a cuda_graph object.", call. = FALSE)
  }
  graph$adjacency
}

.as_igraph <- function(graph) {
  if (!requireNamespace("igraph", quietly = TRUE)) {
    stop("Install the 'igraph' package to run graph clustering.",
         call. = FALSE)
  }
  if (!inherits(graph, "cuda_graph")) {
    stop("`graph` must be a cuda_graph object.", call. = FALSE)
  }
  igraph::graph_from_adjacency_matrix(
    graph$adjacency,
    mode = "undirected",
    weighted = TRUE,
    diag = FALSE
  )
}

.graph_resolution <- function(resolution) {
  if (!is.numeric(resolution) || length(resolution) != 1L ||
      is.na(resolution) || !is.finite(resolution) || resolution <= 0) {
    stop("`resolution` must be a positive finite number.", call. = FALSE)
  }
  resolution
}

.community_result <- function(fit, graph, igraph_graph, algorithm, resolution) {
  membership <- as.integer(igraph::membership(fit))
  structure(
    list(
      membership = membership,
      communities = length(fit),
      modularity = igraph::modularity(
        igraph_graph,
        membership = membership,
        weights = igraph::E(igraph_graph)$weight,
        resolution = resolution
      ),
      algorithm = algorithm,
      resolution = resolution,
      source_device = graph$source_device,
      backend = "igraph"
    ),
    class = "cuda_communities"
  )
}

#' Cluster a graph with Louvain
#'
#' Community detection currently runs on the CPU through `igraph`.
#'
#' @param graph A `cuda_graph`.
#' @param resolution Positive modularity resolution.
#' @return A `cuda_communities` object.
#' @export
cuda_louvain <- function(graph, resolution = 1) {
  resolution <- .graph_resolution(resolution)
  igraph_graph <- .as_igraph(graph)
  fit <- igraph::cluster_louvain(
    igraph_graph,
    weights = igraph::E(igraph_graph)$weight,
    resolution = resolution
  )
  .community_result(fit, graph, igraph_graph, "louvain", resolution)
}

#' Cluster a graph with Leiden
#'
#' Community detection currently runs on the CPU through `igraph`.
#'
#' @param graph A `cuda_graph`.
#' @param resolution Positive modularity resolution.
#' @param n_iterations Number of Leiden refinement iterations.
#' @return A `cuda_communities` object.
#' @export
cuda_leiden <- function(graph, resolution = 1, n_iterations = 2L) {
  resolution <- .graph_resolution(resolution)
  if (!is.numeric(n_iterations) || length(n_iterations) != 1L ||
      is.na(n_iterations) || n_iterations < 1 ||
      n_iterations != as.integer(n_iterations)) {
    stop("`n_iterations` must be a positive whole number.", call. = FALSE)
  }
  igraph_graph <- .as_igraph(graph)
  fit <- igraph::cluster_leiden(
    igraph_graph,
    objective_function = "modularity",
    weights = igraph::E(igraph_graph)$weight,
    resolution = resolution,
    n_iterations = as.integer(n_iterations)
  )
  .community_result(fit, graph, igraph_graph, "leiden", resolution)
}

#' @export
print.cuda_graph <- function(x, ...) {
  cat(sprintf(
    "<cuda_graph vertices=%s edges=%s weighting=%s source_device=%s backend=%s>\n",
    x$vertices, x$edges, x$weighting, x$source_device, x$backend
  ))
  invisible(x)
}

#' @export
print.cuda_communities <- function(x, ...) {
  cat(sprintf(
    "<cuda_communities groups=%s algorithm=%s resolution=%s backend=%s>\n",
    x$communities, x$algorithm, x$resolution, x$backend
  ))
  invisible(x)
}
