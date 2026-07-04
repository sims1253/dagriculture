#' Abort with a typed dagriculture error
#'
#' @param class Error class.
#' @param message Error message.
#' @param details Optional details list.
#' @export
abort_dagri <- function(class, message, details = list()) {
  rlang::abort(message, class = class, details = details)
}

#' Validate a dagriculture graph object
#'
#' Ensures the graph has all required top-level fields, validates component types
#' for \code{registry}, \code{nodes}, \code{edges}, and \code{gates}, checks
#' that \code{version} is a single integer, and enforces referential integrity:
#' every edge's \code{$from}/\code{$to} must reference a node in \code{graph$nodes},
#' and every gate's \code{$edge_id} must reference an edge in \code{graph$edges}.
#'
#' This is the load-time / entry-point validator: it guards every public
#' boundary, so it is kept cheap and structural (O(V+E) referential checks). It
#' does NOT detect cycles, because cycle detection is O(V+E) and only needed for
#' topological operations; [dagri_topo_order()] performs that check explicitly.
#'
#' @param graph A \code{dagri_graph}.
#' @return The graph, invisibly, if valid.
#' @keywords internal
dagri_validate_graph <- function(graph) {
  if (!is.list(graph) || inherits(graph, "data.frame")) {
    abort_dagri(
      "dagri_error_invalid_argument",
      "`graph` must be a list created by dagri_graph()."
    )
  }
  required_fields <- c("registry", "nodes", "edges", "gates", "version")
  missing_fields <- setdiff(required_fields, names(graph))
  if (length(missing_fields) > 0) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`graph` is missing required fields: %s. Use dagri_graph() to create a valid graph.",
        paste(missing_fields, collapse = ", ")
      )
    )
  }
  component_ok <- c(
    registry = is.list(graph$registry) && !inherits(graph$registry, "data.frame"),
    nodes = is.list(graph$nodes) && !inherits(graph$nodes, "data.frame"),
    edges = is.list(graph$edges) && !inherits(graph$edges, "data.frame"),
    gates = is.list(graph$gates) && !inherits(graph$gates, "data.frame")
  )
  invalid_components <- names(component_ok)[!component_ok]
  if (length(invalid_components) > 0) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`graph` has invalid components: %s.",
        paste(invalid_components, collapse = ", ")
      )
    )
  }
  if (!is.integer(graph$version) || length(graph$version) != 1 || is.na(graph$version)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      "`graph$version` must be a single integer."
    )
  }

  # Referential integrity (edge -> node). O(E). The editing API prevents
  # dangling edges, but graphs deserialized from JSON bypass it, so this guards
  # the same threat model as the cycle check in dagri_topo_order().
  node_ids <- names(graph$nodes)
  for (e in graph$edges) {
    if (!is.list(e) || is.null(e$from) || is.null(e$to)) {
      abort_dagri(
        "dagri_error_invalid_argument",
        "`graph$edges` contains a malformed edge (must be a list with `from` and `to`)."
      )
    }
    dangling <- setdiff(c(e$from, e$to), node_ids)
    if (length(dangling) > 0) {
      abort_dagri(
        "dagri_error_invalid_argument",
        sprintf(
          "Edge `%s` references missing node(s): %s.",
          e$id %||% "<unnamed>",
          paste(dangling, collapse = ", ")
        ),
        details = list(edge_id = e$id %||% NA, missing_nodes = dangling)
      )
    }
  }

  # Referential integrity (gate -> edge). O(G).
  edge_ids <- names(graph$edges)
  for (g in graph$gates) {
    if (!is.list(g) || is.null(g$edge_id)) {
      abort_dagri(
        "dagri_error_invalid_argument",
        "`graph$gates` contains a malformed gate (must be a list with `edge_id`)."
      )
    }
    if (!g$edge_id %in% edge_ids) {
      abort_dagri(
        "dagri_error_invalid_argument",
        sprintf("Gate `%s` references missing edge: %s.", g$id %||% "<unnamed>", g$edge_id),
        details = list(gate_id = g$id %||% NA, missing_edge_id = g$edge_id)
      )
    }
  }

  invisible(graph)
}
