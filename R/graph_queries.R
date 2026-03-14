#' Get a node from a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param id Node ID.
#' @export
dagri_node <- function(graph, id) {
  dagri_validate_graph(graph)

  if (!id %in% names(graph$nodes)) {
    abort_dagri("dagri_error_not_found", sprintf("Node %s not found.", id))
  }
  graph$nodes[[id]]
}

#' Get an edge from a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param id Edge ID.
#' @export
dagri_edge <- function(graph, id) {
  dagri_validate_graph(graph)

  if (!id %in% names(graph$edges)) {
    abort_dagri("dagri_error_not_found", sprintf("Edge %s not found.", id))
  }
  graph$edges[[id]]
}

#' Get a gate from a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param id Gate ID.
#' @export
dagri_gate <- function(graph, id) {
  dagri_validate_graph(graph)

  if (!id %in% names(graph$gates)) {
    abort_dagri("dagri_error_not_found", sprintf("Gate %s not found.", id))
  }
  graph$gates[[id]]
}

#' Get all nodes
#'
#' @param graph A \code{dagri_graph}.
#' @export
dagri_nodes <- function(graph) {
  dagri_validate_graph(graph)

  graph$nodes
}

#' Get all edges
#'
#' @param graph A \code{dagri_graph}.
#' @export
dagri_edges <- function(graph) {
  dagri_validate_graph(graph)

  graph$edges
}

#' Get all gates
#'
#' @param graph A \code{dagri_graph}.
#' @export
dagri_gates <- function(graph) {
  dagri_validate_graph(graph)

  graph$gates
}

#' Get upstream nodes
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_upstream <- function(graph, node_id) {
  dagri_validate_graph(graph)

  up_edges <- Filter(function(e) e$to == node_id, graph$edges)
  unique(vapply(up_edges, function(e) e$from, character(1)))
}

#' Get downstream nodes
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_downstream <- function(graph, node_id) {
  dagri_validate_graph(graph)

  down_edges <- Filter(function(e) e$from == node_id, graph$edges)
  unique(vapply(down_edges, function(e) e$to, character(1)))
}

dagri_dfs <- function(graph, start, neighbor_fn) {
  dagri_validate_graph(graph)
  visited <- character(0)
  stack <- dagri_neighbor_lookup(graph, start, neighbor_fn)
  while (length(stack) > 0) {
    curr <- stack[1]
    stack <- stack[-1]
    if (!curr %in% visited) {
      visited <- c(visited, curr)
      stack <- c(stack, dagri_neighbor_lookup(graph, curr, neighbor_fn))
    }
  }
  visited
}

dagri_neighbor_lookup <- function(graph, node_id, neighbor_fn) {
  if (identical(neighbor_fn, dagri_upstream)) {
    up_edges <- Filter(function(e) e$to == node_id, graph$edges)
    unique(vapply(up_edges, function(e) e$from, character(1)))
  } else if (identical(neighbor_fn, dagri_downstream)) {
    down_edges <- Filter(function(e) e$from == node_id, graph$edges)
    unique(vapply(down_edges, function(e) e$to, character(1)))
  } else {
    neighbor_fn(graph, node_id)
  }
}

#' Get all ancestors
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_ancestors <- function(graph, node_id) {
  dagri_dfs(graph, node_id, dagri_upstream)
}

#' Get all descendants
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_descendants <- function(graph, node_id) {
  dagri_dfs(graph, node_id, dagri_downstream)
}

#' Check path existence
#'
#' @param graph A \code{dagri_graph}.
#' @param from Source Node ID.
#' @param to Target Node ID.
#' @export
dagri_has_path <- function(graph, from, to) {
  dagri_validate_graph(graph)

  to %in% dagri_descendants(graph, from)
}

#' Get graph roots
#'
#' @param graph A \code{dagri_graph}.
#' @export
dagri_roots <- function(graph) {
  dagri_validate_graph(graph)

  all_nodes <- names(graph$nodes)
  if (length(all_nodes) == 0) {
    return(character(0))
  }
  has_inbound <- unique(vapply(graph$edges, function(e) e$to, character(1)))
  setdiff(all_nodes, has_inbound)
}

#' Get graph leaves
#'
#' @param graph A \code{dagri_graph}.
#' @export
dagri_leaves <- function(graph) {
  dagri_validate_graph(graph)

  all_nodes <- names(graph$nodes)
  if (length(all_nodes) == 0) {
    return(character(0))
  }
  has_outbound <- unique(vapply(graph$edges, function(e) e$from, character(1)))
  setdiff(all_nodes, has_outbound)
}

#' Get topological order
#'
#' @param graph A \code{dagri_graph}.
#' @param subset Optional subset of nodes.
#' @export
dagri_topo_order <- function(graph, subset = NULL) {
  dagri_validate_graph(graph)

  nodes_to_consider <- if (is.null(subset)) {
    names(graph$nodes)
  } else {
    dagri_validate_node_ids(graph, subset, arg = "subset")
  }
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

    for (v in dagri_neighbor_lookup(graph, u, dagri_downstream)) {
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
