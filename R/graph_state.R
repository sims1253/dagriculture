#' Recompute graph state
#'
#' @param graph A \code{dagri_graph}.
#' @export
dagri_recompute_state <- function(graph) {
  dagri_validate_graph(graph)

  topo <- dagri_topo_order(graph)

  for (n_id in topo) {
    up_edges <- Filter(function(e) e$to == n_id, graph$edges)

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
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @export
dagri_terminal <- function(graph, targets = NULL) {
  dagri_validate_graph(graph)

  scoped_targets <- dagri_target_closure(graph, targets)
  if (length(scoped_targets) == 0) {
    return(character(0))
  }

  terminal_nodes <- character(0)
  for (node_id in scoped_targets) {
    down <- intersect(dagri_downstream(graph, node_id), scoped_targets)
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
      sprintf("Missing node(s): %s.", paste(unknown_ids, collapse = ", "))
    )
  }

  unique(node_ids)
}

#' Get the structural closure of target nodes
#'
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @export
dagri_target_closure <- function(graph, targets = NULL) {
  dagri_validate_graph(graph)

  if (is.null(targets)) {
    return(names(graph$nodes))
  }

  targets <- dagri_validate_node_ids(graph, targets, arg = "targets")
  all_targets <- character(0)
  for (target in targets) {
    all_targets <- unique(c(all_targets, target, dagri_ancestors(graph, target)))
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
      sprintf("Missing node(s): %s.", paste(unknown_ids, collapse = ", "))
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
#' @param graph A \code{dagri_graph}.
#' @param targets Target node IDs.
#' @param topo_order Topological ordering of nodes.
#' @param external_holds Named list mapping node IDs to hold reasons.
#' @return Named list of externally blocked nodes and their reasons.
#' @keywords internal
dagri_external_blocked <- function(graph, targets, topo_order, external_holds) {
  if (length(targets) == 0) {
    return(dagri_empty_named_list())
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

    upstream_blockers <- intersect(dagri_upstream(graph, node_id), names(external_blocked))
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
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @export
dagri_pending_gates <- function(graph, targets = NULL) {
  dagri_validate_graph(graph)

  scoped_targets <- dagri_target_closure(graph, targets)
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
        sprintf("Missing edge: %s.", gate$edge_id)
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
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @param external_holds Optional named list mapping node ids to external hold
#'   reason strings. These affect planning output without mutating graph state.
#' @export
dagri_plan <- function(graph, targets = NULL, external_holds = list()) {
  dagri_validate_graph(graph)

  external_holds <- dagri_validate_external_holds(graph, external_holds)

  targets <- dagri_target_closure(graph, targets)

  topo <- dagri_topo_order(graph, subset = targets)

  eligible_nodes <- intersect(targets, dagri_eligible(graph))

  all_blocked <- dagri_blocked(graph)
  blocked_list <- all_blocked[intersect(targets, names(all_blocked))]
  if (length(blocked_list) == 0) {
    blocked_list <- dagri_empty_named_list()
  }

  external_blocked <- dagri_external_blocked(graph, targets, topo, external_holds)

  list(
    targets = targets,
    topo_order = topo,
    eligible = eligible_nodes,
    blocked = blocked_list,
    external_blocked = external_blocked,
    terminal = dagri_terminal(graph, targets = targets),
    pending_gates = dagri_pending_gates(graph, targets = targets)
  )
}
