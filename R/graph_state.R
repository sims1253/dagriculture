#' Recompute graph state
#'
#' @details Builds a single O(V+E) adjacency index via [dagri_adjacency()] and
#'   threads it through the topological sort and the per-node incoming-edge
#'   lookup, so the whole recomputation is O(V+E) rather than O(V*E).
#'
#' @param graph A \code{dagri_graph}.
#' @export
dagri_recompute_state <- function(graph) {
  dagri_validate_graph(graph)

  index <- dagri_adjacency(graph)
  topo <- dagri_topo_order(graph, index = index)

  for (n_id in topo) {
    up_edges <- graph$edges[index$reverse_edges[[n_id]]]

    is_upstream_blocked <- FALSE
    for (e in up_edges) {
      up_node_state <- graph$nodes[[e$from]]$state
      if (up_node_state != "ready") {
        is_upstream_blocked <- TRUE
        break
      }
    }

    if (is_upstream_blocked) {
      graph$nodes[[n_id]]$state <- "blocked"
      graph$nodes[[n_id]]$block_reason <- "upstream_blocked"
      next
    }

    is_gate_blocked <- FALSE
    for (e in up_edges) {
      gates_on_edge <- Filter(function(g) g$edge_id == e$id && g$status == "pending", graph$gates)
      if (length(gates_on_edge) > 0) {
        is_gate_blocked <- TRUE
        break
      }
    }

    if (is_gate_blocked) {
      graph$nodes[[n_id]]$state <- "blocked"
      graph$nodes[[n_id]]$block_reason <- "gate"
      next
    }

    graph$nodes[[n_id]]$state <- "ready"
    graph$nodes[[n_id]]$block_reason <- "none"
  }

  graph
}

#' Get eligible nodes
#'
#' Returns IDs of nodes whose state is "ready". Call \code{dagri_recompute_state()}
#' before using this function to ensure node states are current.
#'
#' @param graph A \code{dagri_graph}.
#' @export
dagri_eligible <- function(graph) {
  dagri_validate_graph(graph)

  if (length(graph$nodes) == 0) {
    return(character(0))
  }
  names(graph$nodes)[vapply(graph$nodes, function(n) n$state == "ready", logical(1))]
}

#' Get blocked nodes
#'
#' Returns a named list of blocked nodes mapped to their block reasons. Call
#' \code{dagri_recompute_state()} before using this function to ensure node
#' states are current.
#'
#' @param graph A \code{dagri_graph}.
#' @export
dagri_blocked <- function(graph) {
  dagri_validate_graph(graph)

  blocked_nodes <- Filter(function(n) n$state == "blocked", graph$nodes)
  res <- lapply(blocked_nodes, function(n) n$block_reason)
  if (length(res) == 0) {
    return(stats::setNames(list(), character(0)))
  }
  res
}

#' Get terminal nodes
#'
#' @details Builds a single O(V+E) adjacency index via [dagri_adjacency()] (or
#'   reuses a caller-supplied `index`), reads the target closure through it, and
#'   reads downstream neighbors from it, so the scan is O(V+E) rather than
#'   O(V*E).
#'
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @param index Optional pre-built adjacency index from [dagri_adjacency()].
#' @export
dagri_terminal <- function(graph, targets = NULL, index = NULL) {
  dagri_validate_graph(graph)

  if (is.null(index)) {
    index <- dagri_adjacency(graph)
  }

  scoped_targets <- dagri_target_closure(graph, targets, index = index)
  if (length(scoped_targets) == 0) {
    return(character(0))
  }

  terminal_nodes <- character(0)
  for (node_id in scoped_targets) {
    down <- intersect(index$forward[[node_id]], scoped_targets)
    if (length(down) == 0) {
      terminal_nodes <- c(terminal_nodes, node_id)
    }
  }

  unique(terminal_nodes)
}

#' Create an empty named list
#'
#' Utility for initializing empty named list results.
#'
#' @return An empty named list.
#' @keywords internal
dagri_empty_named_list <- function() {
  stats::setNames(list(), character(0))
}

#' Validate node IDs against a graph
#'
#' Checks that node IDs are valid character strings and exist in the graph.
#'
#' @param graph A \code{dagri_graph}.
#' @param node_ids Character vector of node IDs.
#' @param arg Argument name for error messages.
#' @return Unique, validated node IDs.
#' @keywords internal
dagri_validate_node_ids <- function(graph, node_ids, arg = "node_ids") {
  if (!is.character(node_ids)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf("`%s` must be a character vector of node ids.", arg)
    )
  }

  if (length(node_ids) == 0) {
    return(character(0))
  }

  if (anyNA(node_ids) || any(node_ids == "")) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf("`%s` must be a character vector of node ids.", arg)
    )
  }

  unknown_ids <- setdiff(node_ids, names(graph$nodes))
  if (length(unknown_ids) > 0) {
    abort_dagri(
      "dagri_error_not_found",
      sprintf("Missing node(s): %s.", paste(unknown_ids, collapse = ", ")),
      details = list(node_ids = unknown_ids)
    )
  }

  unique(node_ids)
}

#' Get the structural closure of target nodes
#'
#' @details When `index` is `NULL` and `targets` is non-NULL, an adjacency index
#'   is built once via [dagri_adjacency()] and reused across the per-target
#'   ancestor walks, so the closure is O(V+E + k*V) rather than O(k*(V+E)) from
#'   rebuilding the index per target. Callers that already hold an index (e.g.
#'   [dagri_plan()]) may pass it to share one index across the whole plan.
#'
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @param index Optional pre-built adjacency index from [dagri_adjacency()].
#' @export
dagri_target_closure <- function(graph, targets = NULL, index = NULL) {
  dagri_validate_graph(graph)

  if (is.null(targets)) {
    return(names(graph$nodes))
  }

  targets <- dagri_validate_node_ids(graph, targets, arg = "targets")
  if (is.null(index)) {
    index <- dagri_adjacency(graph)
  }

  all_targets <- character(0)
  for (target in targets) {
    all_targets <- unique(c(all_targets, target, dagri_dfs(graph, target, dagri_upstream, index)))
  }

  all_targets
}

#' Validate external holds
#'
#' Checks that external holds is a valid named list mapping node IDs to
#' single-character reason strings.
#'
#' @param graph A \code{dagri_graph}.
#' @param external_holds Named list mapping node IDs to reason strings.
#' @return Validated external holds list.
#' @keywords internal
dagri_validate_external_holds <- function(graph, external_holds) {
  if (!is.list(external_holds)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      "`external_holds` must be a named list mapping node ids to reason strings."
    )
  }

  if (length(external_holds) == 0) {
    return(dagri_empty_named_list())
  }

  hold_ids <- names(external_holds)
  if (is.null(hold_ids) || anyNA(hold_ids) || any(hold_ids == "")) {
    abort_dagri(
      "dagri_error_invalid_argument",
      "`external_holds` must be a named list mapping node ids to reason strings."
    )
  }

  unknown_ids <- setdiff(hold_ids, names(graph$nodes))
  if (length(unknown_ids) > 0) {
    abort_dagri(
      "dagri_error_not_found",
      sprintf("Missing node(s): %s.", paste(unknown_ids, collapse = ", ")),
      details = list(node_ids = unknown_ids)
    )
  }

  invalid_reason <- !vapply(
    external_holds,
    function(reason) is.character(reason) && length(reason) == 1 && !is.na(reason),
    logical(1)
  )
  if (any(invalid_reason)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      "Each external hold reason must be a single string.",
      details = list(node_ids = hold_ids[invalid_reason])
    )
  }

  external_holds
}

#' Compute external block propagation
#'
#' Propagates external holds through the topological order, marking downstream
#' nodes as blocked by the nearest upstream hold.
#'
#' @details When `index` is `NULL` it is built once via [dagri_adjacency()];
#'   upstream neighbors are then read from `index$reverse` instead of scanning
#'   the edge list, so propagation is O(V+E) overall. Callers that already hold
#'   an index (e.g. [dagri_plan()]) may pass it to share one index across the
#'   whole plan.
#'
#' @param graph A \code{dagri_graph}.
#' @param targets Target node IDs.
#' @param topo_order Topological ordering of nodes.
#' @param external_holds Named list mapping node IDs to hold reasons.
#' @param index Optional pre-built adjacency index from [dagri_adjacency()].
#' @return Named list of externally blocked nodes and their reasons.
#' @keywords internal
dagri_external_blocked <- function(graph, targets, topo_order, external_holds, index = NULL) {
  if (length(targets) == 0) {
    return(dagri_empty_named_list())
  }

  if (is.null(index)) {
    index <- dagri_adjacency(graph)
  }

  holds_in_scope <- external_holds[intersect(names(external_holds), targets)]
  if (length(holds_in_scope) == 0) {
    return(dagri_empty_named_list())
  }

  topo_rank <- stats::setNames(seq_along(topo_order), topo_order)
  external_blocked <- dagri_empty_named_list()

  for (node_id in topo_order) {
    if (node_id %in% names(holds_in_scope)) {
      external_blocked[[node_id]] <- holds_in_scope[[node_id]]
      next
    }

    upstream_blockers <- intersect(index$reverse[[node_id]], names(external_blocked))
    if (length(upstream_blockers) == 0) {
      next
    }

    inherited_from <- upstream_blockers[[which.min(topo_rank[upstream_blockers])]]
    external_blocked[[node_id]] <- external_blocked[[inherited_from]]
  }

  if (length(external_blocked) == 0) {
    return(dagri_empty_named_list())
  }

  external_blocked
}

#' Get pending gates
#'
#' @details When `index` is supplied it is forwarded to [dagri_target_closure()]
#'   so the ancestor walk reuses a shared adjacency index.
#'
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @param index Optional pre-built adjacency index from [dagri_adjacency()].
#' @export
dagri_pending_gates <- function(graph, targets = NULL, index = NULL) {
  dagri_validate_graph(graph)

  if (is.null(index)) {
    index <- dagri_adjacency(graph)
  }

  scoped_targets <- dagri_target_closure(graph, targets, index = index)
  if (length(scoped_targets) == 0 || length(graph$gates) == 0) {
    return(character(0))
  }

  pending_gates <- character(0)
  for (gate in graph$gates) {
    if (gate$status != "pending") {
      next
    }

    edge <- graph$edges[[gate$edge_id]]
    if (is.null(edge)) {
      abort_dagri(
        "dagri_error_not_found",
        sprintf("Missing edge: %s.", gate$edge_id),
        details = list(edge_id = gate$edge_id)
      )
    }

    if (edge$to %in% scoped_targets) {
      pending_gates <- c(pending_gates, gate$id)
    }
  }

  pending_gates
}

#' Create a structural plan
#'
#' @details Builds one O(V+E) adjacency index via [dagri_adjacency()] near the
#'   top and shares it across [dagri_topo_order()] and
#'   [dagri_external_blocked()], so a single `dagri_plan()` call builds the
#'   index once and scans the edge list once per call.
#'
#'   The result carries S3 class `c("dagri_plan", "list")` so
#'   [print.dagri_plan()] dispatches; underneath it remains a plain named list
#'   with the fields documented below. Field access (`plan$targets`, etc.) and
#'   serialization are unchanged.
#'
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @param external_holds Optional named list mapping node ids to external hold
#'   reason strings. These affect planning output without mutating graph state.
#' @return A `dagri_plan` (a named list with S3 class
#'   \code{c("dagri_plan", "list")}) with components \code{targets},
#'   \code{topo_order}, \code{eligible}, \code{blocked}, \code{external_blocked},
#'   \code{terminal}, and \code{pending_gates}.
#' @export
dagri_plan <- function(graph, targets = NULL, external_holds = list()) {
  dagri_validate_graph(graph)

  external_holds <- dagri_validate_external_holds(graph, external_holds)

  index <- dagri_adjacency(graph)
  targets <- dagri_target_closure(graph, targets, index = index)

  topo <- dagri_topo_order(graph, subset = targets, index = index)

  eligible_nodes <- intersect(targets, dagri_eligible(graph))

  all_blocked <- dagri_blocked(graph)
  blocked_list <- all_blocked[intersect(targets, names(all_blocked))]
  if (length(blocked_list) == 0) {
    blocked_list <- dagri_empty_named_list()
  }

  external_blocked <- dagri_external_blocked(graph, targets, topo, external_holds, index = index)

  structure(
    list(
      targets = targets,
      topo_order = topo,
      eligible = eligible_nodes,
      blocked = blocked_list,
      external_blocked = external_blocked,
      terminal = dagri_terminal(graph, targets = targets, index = index),
      pending_gates = dagri_pending_gates(graph, targets = targets, index = index)
    ),
    class = c("dagri_plan", "list")
  )
}
