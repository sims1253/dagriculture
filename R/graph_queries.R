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
#' Returns the unique node ids with an edge into `node_id`. This is a
#' single-neighbor query and uses a linear scan over `graph$edges`, so it is
#' O(E) per call. Traversal internals (`dagri_ancestors()`,
#' `dagri_descendants()`, `dagri_has_path()`, planning) instead build a single
#' O(V+E) adjacency index via [dagri_adjacency()] and thread it through the
#' walk.
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
#' Returns the unique node ids with an edge out of `node_id`. This is a
#' single-neighbor query and uses a linear scan over `graph$edges`, so it is
#' O(E) per call. Traversal internals (`dagri_ancestors()`,
#' `dagri_descendants()`, `dagri_has_path()`, planning) instead build a single
#' O(V+E) adjacency index via [dagri_adjacency()] and thread it through the
#' walk.
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_downstream <- function(graph, node_id) {
  dagri_validate_graph(graph)

  down_edges <- Filter(function(e) e$from == node_id, graph$edges)
  unique(vapply(down_edges, function(e) e$to, character(1)))
}

#' Depth-first traversal over a dagriculture graph
#'
#' Internal helper. Callers are responsible for validating the graph and for
#' building (and passing) an adjacency `index` when traversing a large graph;
#' without an index each neighbor lookup falls back to a linear scan over the
#' edge list.
#'
#' @param graph A \code{dagri_graph}.
#' @param start Starting node ID.
#' @param neighbor_fn Neighbor selector: `dagri_upstream` or `dagri_downstream`.
#' @param index Optional pre-built adjacency index from [dagri_adjacency()].
#' @return Character vector of visited node ids (excluding `start`).
#' @keywords internal
dagri_dfs <- function(graph, start, neighbor_fn, index = NULL) {
  visited <- character(0)
  stack <- dagri_neighbor_lookup(graph, start, neighbor_fn, index)
  while (length(stack) > 0) {
    curr <- stack[1]
    stack <- stack[-1]
    if (!curr %in% visited) {
      visited <- c(visited, curr)
      stack <- c(stack, dagri_neighbor_lookup(graph, curr, neighbor_fn, index))
    }
  }
  visited
}

#' Resolve a node's immediate neighbors
#'
#' Internal helper used by [dagri_dfs()]. When a pre-built `index` is supplied,
#' it returns the relevant map directly (O(1)); otherwise it falls back to a
#' linear scan over the edge list for compatibility. For a custom
#' `neighbor_fn`, `index` is ignored and `neighbor_fn` is called.
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @param neighbor_fn Neighbor selector: `dagri_upstream` or `dagri_downstream`.
#' @param index Optional pre-built adjacency index from [dagri_adjacency()].
#' @return Character vector of neighbor node ids.
#' @keywords internal
dagri_neighbor_lookup <- function(graph, node_id, neighbor_fn, index = NULL) {
  if (!is.null(index)) {
    if (identical(neighbor_fn, dagri_upstream)) {
      return(index$reverse[[node_id]])
    } else if (identical(neighbor_fn, dagri_downstream)) {
      return(index$forward[[node_id]])
    }
  }

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
#' Returns all node ids reachable from `node_id` by following edges upstream.
#'
#' @details Builds a single O(V+E) adjacency index via [dagri_adjacency()] and
#'   threads it through the traversal, so the walk is O(V+E) overall rather than
#'   O(V*E) from a per-step edge scan.
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_ancestors <- function(graph, node_id) {
  dagri_validate_graph(graph)
  index <- dagri_adjacency(graph)
  dagri_dfs(graph, node_id, dagri_upstream, index)
}

#' Get all descendants
#'
#' Returns all node ids reachable from `node_id` by following edges downstream.
#'
#' @details Builds a single O(V+E) adjacency index via [dagri_adjacency()] and
#'   threads it through the traversal, so the walk is O(V+E) overall rather than
#'   O(V*E) from a per-step edge scan.
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_descendants <- function(graph, node_id) {
  dagri_validate_graph(graph)
  index <- dagri_adjacency(graph)
  dagri_dfs(graph, node_id, dagri_downstream, index)
}

#' Check path existence
#'
#' @details Validates the graph once, builds a single O(V+E) adjacency index,
#'   and runs the downstream walk directly, so this is O(V+E) per call. The
#'   walk is performed inline (rather than delegating to `dagri_descendants()`)
#'   so the graph is validated exactly once at this public boundary.
#'
#' @param graph A \code{dagri_graph}.
#' @param from Source Node ID.
#' @param to Target Node ID.
#' @export
dagri_has_path <- function(graph, from, to) {
  dagri_validate_graph(graph)
  index <- dagri_adjacency(graph)

  to %in% dagri_dfs(graph, from, dagri_downstream, index)
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
#' @details Uses Kahn's algorithm. When `index` is `NULL` the adjacency index is
#'   built once via [dagri_adjacency()] and threaded through the in-degree
#'   decrement loop, so the sort is O(V+E) overall. Callers that already hold
#'   an index (e.g. [dagri_recompute_state()], [dagri_plan()]) may pass it to
#'   avoid a redundant rebuild.
#'
#'   Cycles are detected here: after the Kahn loop, any node that was not
#'   emitted (i.e. still has non-zero in-degree) participates in a cycle, and
#'   the function aborts with class `dagri_error_cycle`, naming the
#'   cycle-participating nodes in `details$cycle_nodes`. [dagri_add_edge()]
#'   prevents cycles at edit time, but consumers (e.g. bayesgrove) deserialize
#'   graphs from JSON, so a corrupted or hand-edited file can smuggle a cycle
#'   past the editing layer; this check ensures a planner never silently drops
#'   cycle-locked nodes from the order. This is an explicit per-call check
#'   (O(V+E)) rather than part of [dagri_validate_graph()], because it is only
#'   needed for topological operations.
#'
#' @param graph A \code{dagri_graph}.
#' @param subset Optional subset of nodes.
#' @param index Optional pre-built adjacency index from [dagri_adjacency()].
#' @export
dagri_topo_order <- function(graph, subset = NULL, index = NULL) {
  dagri_validate_graph(graph)

  caller_supplied_index <- !is.null(index)
  if (is.null(index)) {
    index <- dagri_adjacency(graph)
  }

  nodes_to_consider <- if (is.null(subset)) {
    names(graph$nodes)
  } else {
    dagri_validate_node_ids(graph, subset, arg = "subset")
  }
  if (length(nodes_to_consider) == 0) {
    return(character(0))
  }

  in_degree <- stats::setNames(integer(length(nodes_to_consider)), nodes_to_consider)
  scope <- nodes_to_consider
  if (caller_supplied_index) {
    # Count, per node, the incoming edges whose source is also in scope.
    # Build a from-of map once so this stays O(V+E).
    from_of <- vapply(graph$edges, function(e) e$from, character(1))
    for (nid in scope) {
      rev_edges <- index$reverse_edges[[nid]]
      if (length(rev_edges) == 0) {
        next
      }
      in_degree[nid] <- sum(from_of[rev_edges] %in% scope)
    }
  } else {
    for (e in graph$edges) {
      if (e$to %in% scope && e$from %in% scope) {
        in_degree[e$to] <- in_degree[e$to] + 1L
      }
    }
  }

  queue <- names(in_degree)[in_degree == 0]
  order <- character(0)

  while (length(queue) > 0) {
    u <- queue[1]
    queue <- queue[-1]
    order <- c(order, u)

    for (v in dagri_neighbor_lookup(graph, u, dagri_downstream, index)) {
      if (v %in% nodes_to_consider) {
        in_degree[v] <- in_degree[v] - 1L
        if (in_degree[v] == 0) {
          queue <- c(queue, v)
        }
      }
    }
  }

  cycle_nodes <- setdiff(nodes_to_consider, order)
  if (length(cycle_nodes) > 0) {
    abort_dagri(
      "dagri_error_cycle",
      sprintf(
        "Graph contains a cycle involving nodes: %s.",
        paste(cycle_nodes, collapse = ", ")
      ),
      details = list(cycle_nodes = cycle_nodes)
    )
  }

  order
}
