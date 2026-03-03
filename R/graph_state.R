#' Recompute graph state
#'
#' @param graph A \code{groots_graph}.
#' @export
groots_recompute_state <- function(graph) {
  topo <- groots_topo_order(graph)

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
#' @param graph A \code{groots_graph}.
#' @export
groots_eligible <- function(graph) {
  if (length(graph$nodes) == 0) {
    return(character(0))
  }
  names(graph$nodes)[vapply(graph$nodes, function(n) n$state == "ready", logical(1))]
}

#' Get blocked nodes
#'
#' @param graph A \code{groots_graph}.
#' @export
groots_blocked <- function(graph) {
  blocked_nodes <- Filter(function(n) n$state == "blocked", graph$nodes)
  res <- lapply(blocked_nodes, function(n) n$block_reason)
  if (length(res) == 0) {
    return(stats::setNames(list(), character(0)))
  }
  res
}

#' Get terminal nodes
#'
#' @param graph A \code{groots_graph}.
#' @export
groots_terminal <- function(graph) {
  groots_leaves(graph)
}

#' Create an execution plan
#'
#' @param graph A \code{groots_graph}.
#' @param targets Optional target nodes.
#' @export
groots_plan <- function(graph, targets = NULL) {
  if (is.null(targets)) {
    targets <- names(graph$nodes)
  } else {
    all_targets <- character(0)
    for (t in targets) {
      all_targets <- unique(c(all_targets, t, groots_ancestors(graph, t)))
    }
    targets <- all_targets
  }

  topo <- groots_topo_order(graph, subset = targets)

  eligible_nodes <- intersect(targets, groots_eligible(graph))

  blocked_list <- list()
  all_blocked <- groots_blocked(graph)
  for (t in targets) {
    if (t %in% names(all_blocked)) {
      blocked_list[[t]] <- all_blocked[[t]]
    }
  }
  if (length(blocked_list) == 0) {
    blocked_list <- stats::setNames(list(), character(0))
  }

  target_leaves <- character(0)
  for (t in targets) {
    down <- groots_downstream(graph, t)
    if (length(intersect(down, targets)) == 0) {
      target_leaves <- c(target_leaves, t)
    }
  }

  pending_gates <- character(0)
  for (g in graph$gates) {
    if (g$status == "pending") {
      e <- graph$edges[[g$edge_id]]
      if (e$to %in% targets) {
        pending_gates <- c(pending_gates, g$id)
      }
    }
  }

  list(
    targets = targets,
    topo_order = topo,
    eligible = eligible_nodes,
    blocked = blocked_list,
    terminal = target_leaves,
    pending_gates = pending_gates
  )
}
