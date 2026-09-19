#' Recompute graph state
#'
#' @details O(V+E).
#'
#' @param graph A \code{dagri_graph}.
#' @export
dagri_recompute_state <- function(graph) {
  dagri_validate_graph(graph)
  dagri_recompute_state_impl(graph, dagri_adjacency(graph))
}

#' Recompute graph state against a pre-built adjacency index
#'
#' Pure worker shared by [dagri_recompute_state()] and [dagri_plan()]. Returns a
#' new graph value with `state`/`block_reason` rewritten in topological order.
#'
#' @param graph A \code{dagri_graph}.
#' @param index Adjacency index from [dagri_adjacency()].
#' @return A new \code{dagri_graph} value with derived node states.
#' @keywords internal
dagri_recompute_state_impl <- function(graph, index) {
  topo <- dagri_topo_order_impl(graph, index = index)

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

    pending_gates <- dagri_pending_gates_for_edges(index, index$reverse_edges[[n_id]])
    if (length(pending_gates) > 0) {
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
#' Returns IDs of nodes whose stored state is "ready". Reflects the last
#' [dagri_recompute_state()] pass; call it again after structural or gate
#' changes. [dagri_plan()] recomputes state internally and is always current.
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
#' Returns a named list of nodes whose stored state is "blocked" mapped to their
#' block reasons. Reflects the last [dagri_recompute_state()] pass; call it again
#' after structural or gate changes. [dagri_plan()] recomputes state internally
#' and is always current.
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
#' @details O(V+E).
#'
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @export
dagri_terminal <- function(graph, targets = NULL) {
  dagri_validate_graph(graph)

  index <- dagri_adjacency(graph)
  scoped_targets <- dagri_target_closure(graph, targets, index = index)
  dagri_terminal_impl(scoped_targets, index)
}

#' Terminal nodes within an already-scoped target closure
#'
#' Pure worker shared by [dagri_terminal()] and [dagri_plan()]: a node is
#' terminal when none of its downstream neighbors are inside `scoped_targets`.
#'
#' @param scoped_targets Character vector of node ids (a target closure).
#' @param index Adjacency index from [dagri_adjacency()].
#' @return Character vector of terminal node ids.
#' @keywords internal
dagri_terminal_impl <- function(scoped_targets, index) {
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
#' @details O(V+E).
#'
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @param index Optional pre-built adjacency index from [dagri_adjacency()].
#' @keywords internal
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
    all_targets <- unique(c(
      all_targets,
      target,
      dagri_dfs(target, direction = "reverse", index)
    ))
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
#' @details O(V+E).
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
#' @details O(V+E).
#'
#' @param graph A \code{dagri_graph}.
#' @param targets Optional target nodes.
#' @param index Optional pre-built adjacency index from [dagri_adjacency()].
#' @keywords internal
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

#' Collect pending gate ids on a set of edges
#'
#' Pure worker shared by [dagri_node_status_impl()] and
#' [dagri_recompute_state_impl()]: returns the ids of gates with status
#' "pending" attached to `edge_ids`, in deterministic order — `edge_ids` order
#' first (incoming-edge insertion order), then gate insertion order within each
#' edge. Reads the prebuilt `pending_gate_ids_by_edge` map from the adjacency
#' index instead of rescanning `graph$gates` per edge.
#'
#' @param index Adjacency index from [dagri_adjacency()].
#' @param edge_ids Character vector of edge ids in insertion order.
#' @return Unnamed character vector of gate ids; `character(0)` when none are
#'   pending.
#' @keywords internal
dagri_pending_gates_for_edges <- function(index, edge_ids) {
  if (length(edge_ids) == 0) {
    return(character(0))
  }

  pending <- unlist(
    lapply(edge_ids, function(eid) index$pending_gate_ids_by_edge[[eid]]),
    use.names = FALSE
  )
  if (is.null(pending)) {
    character(0)
  } else {
    pending
  }
}

#' Build the per-node status view for a plan
#'
#' Pure worker shared by [dagri_plan()]: assembles the per-node `node_status`
#' map — one entry per node in `topo_order`, each carrying the derived
#' structural state, its block reason, the pending gates on the node's inbound
#' edges, the propagated external hold reason, the direct structurally blocked
#' upstream neighbors, and final structural eligibility.
#'
#' Structural eligibility and external blocking stay separate: `eligible` is
#' `TRUE` whenever the derived state is "ready", even when the node carries an
#' `external_hold` (mirroring the deliberate overlap between `plan$eligible`
#' and `plan$external_blocked`).
#'
#' Deterministic ordering: entries follow `topo_order`; `pending_gates` follows
#' incoming-edge insertion order, then gate insertion order within each edge;
#' `upstream_blockers` follows incoming-edge insertion order and is unique.
#'
#' @param graph A \code{dagri_graph} with derived states from
#'   [dagri_recompute_state_impl()].
#' @param topo_order Character vector of node ids in topological order (the
#'   plan's target closure).
#' @param external_blocked Named list from [dagri_external_blocked()].
#' @param index Adjacency index from [dagri_adjacency()].
#' @return A named list keyed by node id, in `topo_order` order; each entry is
#'   a named list with `state`, `block_reason`, `pending_gates`,
#'   `external_hold`, `upstream_blockers`, and `eligible`.
#' @keywords internal
dagri_node_status_impl <- function(graph, topo_order, external_blocked, index) {
  node_status <- dagri_empty_named_list()

  for (node_id in topo_order) {
    node <- graph$nodes[[node_id]]

    upstream_ids <- index$reverse[[node_id]]
    upstream_not_ready <- vapply(
      upstream_ids,
      function(up_id) graph$nodes[[up_id]]$state != "ready",
      logical(1)
    )

    is_held <- node_id %in% names(external_blocked)
    hold_reason <- if (is_held) external_blocked[[node_id]] else NULL

    node_status[[node_id]] <- list(
      state = node$state,
      block_reason = node$block_reason,
      pending_gates = dagri_pending_gates_for_edges(index, index$reverse_edges[[node_id]]),
      external_hold = hold_reason,
      upstream_blockers = upstream_ids[upstream_not_ready],
      eligible = node$state == "ready"
    )
  }

  node_status
}

#' Create a structural plan
#'
#' @details O(V+E). State is derived internally, so the plan is always current
#'   even if the input graph was never passed through
#'   [dagri_recompute_state()]; the input graph value itself is not mutated.
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
#'   \code{c("dagri_plan", "list")}) with components:
#'   \describe{
#'     \item{\code{targets}}{Character vector of the planned target closure
#'       (the requested targets plus all their ancestors).}
#'     \item{\code{topo_order}}{Character vector of \code{targets} in
#'       topological order.}
#'     \item{\code{eligible}}{Character vector of structurally ready nodes
#'       within \code{targets}. External holds never remove a node from this
#'       set.}
#'     \item{\code{blocked}}{Named list mapping each structurally blocked
#'       target to its derived block reason (\code{"gate"} or
#'       \code{"upstream_blocked"}).}
#'     \item{\code{external_blocked}}{Named list mapping each externally held
#'       target — and every target downstream of it — to the propagated hold
#'       reason. A node can appear here and in \code{eligible} at the same
#'       time: structural eligibility and external blocking are separate.}
#'     \item{\code{terminal}}{Character vector of targets with no downstream
#'       neighbors inside \code{targets}.}
#'     \item{\code{pending_gates}}{Character vector of pending gate ids on
#'       inbound edges of the target closure, in gate insertion order.}
#'     \item{\code{node_status}}{Named list keyed by node id covering exactly
#'       \code{targets}, ordered by \code{topo_order}. Each entry is a named
#'       list with:
#'       \describe{
#'         \item{\code{state}}{Single string: the derived structural state
#'           (\code{"ready"} or \code{"blocked"}) after the internal
#'           recompute.}
#'         \item{\code{block_reason}}{Single string: the structural block
#'           reason (\code{"none"}, \code{"gate"}, or
#'           \code{"upstream_blocked"}).}
#'         \item{\code{pending_gates}}{Character vector of pending gate ids
#'           attached to the node's inbound edges, in deterministic order —
#'           edge insertion order, then gate insertion order within each
#'           edge; \code{character(0)} when none.}
#'         \item{\code{external_hold}}{\code{NULL} when the node is not
#'           externally blocked; otherwise the single-string propagated hold
#'           reason (the same value \code{external_blocked[[id]]} carries).}
#'         \item{\code{upstream_blockers}}{Character vector of direct upstream
#'           neighbor ids (incoming-edge sources) whose derived state is not
#'           \code{"ready"}; unique, in incoming-edge insertion order;
#'           \code{character(0)} when none.}
#'         \item{\code{eligible}}{Single logical: structural eligibility,
#'           identical to membership in the plan's \code{eligible} field.
#'           Deliberately remains \code{TRUE} when the node is externally
#'           held — structural eligibility and external blocking are separate
#'           axes, so an entry can carry \code{eligible = TRUE} together with
#'           a non-\code{NULL} \code{external_hold}.}
#'       }}
#'   }
#' @export
dagri_plan <- function(graph, targets = NULL, external_holds = list()) {
  dagri_validate_graph(graph)

  external_holds <- dagri_validate_external_holds(graph, external_holds)

  index <- dagri_adjacency(graph)
  graph <- dagri_recompute_state_impl(graph, index)
  targets <- dagri_target_closure(graph, targets, index = index)

  topo <- dagri_topo_order_impl(graph, subset = targets, index = index)

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
      terminal = dagri_terminal_impl(targets, index),
      pending_gates = dagri_pending_gates(graph, targets = targets, index = index),
      node_status = dagri_node_status_impl(graph, topo, external_blocked, index)
    ),
    class = c("dagri_plan", "list")
  )
}
