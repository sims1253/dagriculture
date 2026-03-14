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
#' for \code{registry}, \code{nodes}, \code{edges}, and \code{gates}, and checks
#' that \code{version} is a single integer.
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
  invisible(graph)
}
