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
#' Returns the unique node ids with an edge into `node_id`.
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_upstream <- function(graph, node_id) {
  dagri_validate_graph(graph)
  dagri_validate_single_node(graph, node_id)

  up_edges <- Filter(function(e) e$to == node_id, graph$edges)
  unique(vapply(up_edges, function(e) e$from, character(1)))
}

#' Get downstream nodes
#'
#' Returns the unique node ids with an edge out of `node_id`.
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_downstream <- function(graph, node_id) {
  dagri_validate_graph(graph)
  dagri_validate_single_node(graph, node_id)

  down_edges <- Filter(function(e) e$from == node_id, graph$edges)
  unique(vapply(down_edges, function(e) e$to, character(1)))
}

#' Depth-first traversal over a dagriculture graph
#'
#' Internal helper. Callers must validate the graph and pass a pre-built
#' adjacency `index`. Neighbors are read from `index` instead of scanning the
#' edge list.
#'
#' @param start Starting node ID.
#' @param direction One of `"forward"` (downstream, via `index$forward`) or
#'   `"reverse"` (upstream, via `index$reverse`).
#' @param index Adjacency index from [dagri_adjacency()].
#' @return Character vector of visited node ids (excluding `start`).
#' @keywords internal
dagri_dfs <- function(start, direction = c("forward", "reverse"), index) {
  direction <- match.arg(direction)
  neighbors <- if (direction == "forward") index$forward else index$reverse

  visited <- character(0)
  stack <- neighbors[[start]]
  while (length(stack) > 0) {
    curr <- stack[1]
    stack <- stack[-1]
    if (!curr %in% visited) {
      visited <- c(visited, curr)
      stack <- c(stack, neighbors[[curr]])
    }
  }
  visited
}

#' Get all ancestors
#'
#' Returns all node ids reachable from `node_id` by following edges upstream.
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_ancestors <- function(graph, node_id) {
  dagri_validate_graph(graph)
  dagri_validate_single_node(graph, node_id)
  index <- dagri_adjacency(graph)
  dagri_dfs(node_id, direction = "reverse", index)
}

#' Get all descendants
#'
#' Returns all node ids reachable from `node_id` by following edges downstream.
#'
#' @param graph A \code{dagri_graph}.
#' @param node_id Node ID.
#' @export
dagri_descendants <- function(graph, node_id) {
  dagri_validate_graph(graph)
  dagri_validate_single_node(graph, node_id)
  index <- dagri_adjacency(graph)
  dagri_dfs(node_id, direction = "forward", index)
}

#' Check path existence
#'
#' @param graph A \code{dagri_graph}.
#' @param from Source Node ID.
#' @param to Target Node ID.
#' @export
dagri_has_path <- function(graph, from, to) {
  dagri_validate_graph(graph)
  dagri_validate_single_node(graph, from)
  dagri_validate_single_node(graph, to)
  index <- dagri_adjacency(graph)

  to %in% dagri_dfs(from, direction = "forward", index)
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
#' @details Cycles are detected here: after the Kahn loop, any node that was not
#'   emitted (i.e. still has non-zero in-degree) lies on a cycle or downstream
#'   of one, and the function aborts with class `dagri_error_cycle`, naming
#'   the nodes that lie on a cycle in `details$cycle_nodes`. [dagri_add_edge()]
#'   prevents cycles at edit time, but consumers (e.g. bayesgrove) deserialize
#'   graphs from JSON, so a corrupted or hand-edited file can smuggle a cycle
#'   past the editing layer; this check ensures a planner never silently drops
#'   cycle-locked nodes from the order.
#'
#' @param graph A \code{dagri_graph}.
#' @param subset Optional subset of nodes.
#' @export
dagri_topo_order <- function(graph, subset = NULL) {
  dagri_validate_graph(graph)
  dagri_topo_order_impl(graph, subset, dagri_adjacency(graph))
}

#' Internal topological-order worker
#'
#' Pure worker shared by [dagri_topo_order()] and the planning/state internals.
#' Callers must validate the graph and build (or pass) the adjacency `index`.
#'
#' @param graph A \code{dagri_graph}.
#' @param subset Optional subset of nodes; validated via
#'   [dagri_validate_node_ids()] when non-NULL.
#' @param index Adjacency index from [dagri_adjacency()].
#' @return Character vector of node ids in topological order.
#' @keywords internal
dagri_topo_order_impl <- function(graph, subset = NULL, index) {
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
  # Count, per node, the incoming edges whose source is also in scope.
  # Build a from-of map once instead of looking up each edge's source.
  from_of <- vapply(graph$edges, function(e) e$from, character(1))
  for (nid in scope) {
    rev_edges <- index$reverse_edges[[nid]]
    if (length(rev_edges) == 0) {
      next
    }
    in_degree[nid] <- sum(from_of[rev_edges] %in% scope)
  }

  queue <- names(in_degree)[in_degree == 0]
  order <- character(0)

  while (length(queue) > 0) {
    u <- queue[1]
    queue <- queue[-1]
    order <- c(order, u)

    for (v in index$forward[[u]]) {
      if (v %in% nodes_to_consider) {
        in_degree[v] <- in_degree[v] - 1L
        if (in_degree[v] == 0) {
          queue <- c(queue, v)
        }
      }
    }
  }

  stuck <- setdiff(nodes_to_consider, order)
  if (length(stuck) > 0) {
    cycle_nodes <- dagri_nodes_on_cycle(stuck, index)
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

#' Nodes that lie on a cycle
#'
#' Internal helper for the cycle error in [dagri_topo_order_impl()]. The nodes
#' Kahn's algorithm cannot emit include every in-scope cycle and also the nodes
#' downstream of one, which are on no cycle. A node is on a cycle exactly when
#' it can reach itself; every in-scope cycle lies inside `stuck`, so the search
#' stays inside `stuck`. Runs only when a cycle has already been found.
#'
#' @param stuck Character vector of node ids Kahn's algorithm did not emit.
#' @param index Adjacency index from [dagri_adjacency()].
#' @return The ids in `stuck` that can reach themselves, in `stuck` order.
#' @keywords internal
dagri_nodes_on_cycle <- function(stuck, index) {
  reaches_itself <- function(start) {
    seen <- character(0)
    frontier <- intersect(index$forward[[start]], stuck)
    while (length(frontier) > 0) {
      if (start %in% frontier) {
        return(TRUE)
      }
      seen <- union(seen, frontier)
      frontier <- setdiff(intersect(unlist(index$forward[frontier]), stuck), seen)
    }
    FALSE
  }
  stuck[vapply(stuck, reaches_itself, logical(1))]
}
