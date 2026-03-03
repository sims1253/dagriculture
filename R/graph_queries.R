#' Get a node from a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param node_id Node ID.
#' @export
groots_node <- function(graph, node_id) {
  if (!node_id %in% names(graph$nodes)) {
    abort_groots("groots_error_not_found", "Missing node.")
  }
  graph$nodes[[node_id]]
}

#' Get an edge from a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param edge_id Edge ID.
#' @export
groots_edge <- function(graph, edge_id) {
  if (!edge_id %in% names(graph$edges)) {
    abort_groots("groots_error_not_found", "Missing edge.")
  }
  graph$edges[[edge_id]]
}

#' Get a gate from a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param id Gate ID.
#' @export
groots_gate <- function(graph, id) {
  if (!id %in% names(graph$gates)) {
    abort_groots("groots_error_not_found", "Missing gate.")
  }
  graph$gates[[id]]
}

#' Get all nodes
#'
#' @param graph A \code{groots_graph}.
#' @export
groots_nodes <- function(graph) graph$nodes

#' Get all edges
#'
#' @param graph A \code{groots_graph}.
#' @export
groots_edges <- function(graph) graph$edges

#' Get all gates
#'
#' @param graph A \code{groots_graph}.
#' @export
groots_gates <- function(graph) graph$gates

#' Get upstream nodes
#'
#' @param graph A \code{groots_graph}.
#' @param node_id Node ID.
#' @export
groots_upstream <- function(graph, node_id) {
  up_edges <- Filter(function(e) e$to == node_id, graph$edges)
  unique(vapply(up_edges, function(e) e$from, character(1)))
}

#' Get downstream nodes
#'
#' @param graph A \code{groots_graph}.
#' @param node_id Node ID.
#' @export
groots_downstream <- function(graph, node_id) {
  down_edges <- Filter(function(e) e$from == node_id, graph$edges)
  unique(vapply(down_edges, function(e) e$to, character(1)))
}

#' Get all ancestors
#'
#' @param graph A \code{groots_graph}.
#' @param node_id Node ID.
#' @export
groots_ancestors <- function(graph, node_id) {
  visited <- character(0)
  stack <- groots_upstream(graph, node_id)
  while (length(stack) > 0) {
    curr <- stack[1]
    stack <- stack[-1]
    if (!curr %in% visited) {
      visited <- c(visited, curr)
      stack <- c(stack, groots_upstream(graph, curr))
    }
  }
  visited
}

#' Get all descendants
#'
#' @param graph A \code{groots_graph}.
#' @param node_id Node ID.
#' @export
groots_descendants <- function(graph, node_id) {
  visited <- character(0)
  stack <- groots_downstream(graph, node_id)
  while (length(stack) > 0) {
    curr <- stack[1]
    stack <- stack[-1]
    if (!curr %in% visited) {
      visited <- c(visited, curr)
      stack <- c(stack, groots_downstream(graph, curr))
    }
  }
  visited
}

#' Check path existence
#'
#' @param graph A \code{groots_graph}.
#' @param from Source Node ID.
#' @param to Target Node ID.
#' @export
groots_has_path <- function(graph, from, to) {
  to %in% groots_descendants(graph, from)
}

#' Get graph roots
#'
#' @param graph A \code{groots_graph}.
#' @export
groots_roots <- function(graph) {
  all_nodes <- names(graph$nodes)
  if (length(all_nodes) == 0) {
    return(character(0))
  }
  has_inbound <- unique(vapply(graph$edges, function(e) e$to, character(1)))
  setdiff(all_nodes, has_inbound)
}

#' Get graph leaves
#'
#' @param graph A \code{groots_graph}.
#' @export
groots_leaves <- function(graph) {
  all_nodes <- names(graph$nodes)
  if (length(all_nodes) == 0) {
    return(character(0))
  }
  has_outbound <- unique(vapply(graph$edges, function(e) e$from, character(1)))
  setdiff(all_nodes, has_outbound)
}

#' Get topological order
#'
#' @param graph A \code{groots_graph}.
#' @param subset Optional subset of nodes.
#' @export
groots_topo_order <- function(graph, subset = NULL) {
  nodes_to_consider <- if (is.null(subset)) names(graph$nodes) else subset
  if (length(nodes_to_consider) == 0) {
    return(character(0))
  }

  in_degree <- stats::setNames(integer(length(nodes_to_consider)), nodes_to_consider)
  for (e in graph$edges) {
    if (e$to %in% nodes_to_consider && e$from %in% nodes_to_consider) {
      in_degree[e$to] <- in_degree[e$to] + 1L
    }
  }

  queue <- names(in_degree)[in_degree == 0]
  order <- character(0)

  while (length(queue) > 0) {
    u <- queue[1]
    queue <- queue[-1]
    order <- c(order, u)

    for (v in groots_downstream(graph, u)) {
      if (v %in% nodes_to_consider) {
        in_degree[v] <- in_degree[v] - 1L
        if (in_degree[v] == 0) {
          queue <- c(queue, v)
        }
      }
    }
  }
  order
}
