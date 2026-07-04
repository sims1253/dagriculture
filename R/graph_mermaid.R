# Mermaid flowchart export. Pure string output, zero new dependencies.
#
# This is the graph-to-text renderer that bayesgrove's
# `bg_graph_mermaid()` wraps (Milestone 7 of bayesgrove's plan) to supply
# branch-aware labels and run-state CSS classes. See
# `design/api-contracts.md` for the boundary contract.

# --- Internal: label sanitization ---

dagri_mermaid_sanitize <- function(x) {
  if (is.null(x)) {
    return("")
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    x <- as.character(x)
    if (length(x) != 1L || is.na(x)) {
      return("")
    }
  }
  # Mermaid breaks on `"`, brackets, braces, pipes, angle brackets, and
  # embedded newlines. Replace `"` with `'` (readable inside the quoted
  # label) and the rest with a single space, then collapse runs of
  # whitespace so hostile labels stay on one rendered line.
  x <- gsub('"', "'", x, fixed = TRUE)
  x <- gsub("[][(){}|<>]", " ", x)
  x <- gsub("[\r\n]", " ", x)
  x <- gsub("[ \t]+", " ", x)
  trimws(x)
}

# --- Mermaid flowchart export ---

#' Render a dagriculture graph as Mermaid flowchart text
#'
#' Emits a [Mermaid](https://mermaid.js.org/) flowchart as a single
#' length-1 character scalar with embedded newlines (`\n`). The output is
#' the literal `flowchart` block — paste it into a Mermaid renderer or
#' wrap it in a fenced code block in Markdown.
#'
#' @param graph A \code{dagri_graph}.
#' @param node_label `NULL` or a function \code{(node) -> string} that
#'   supplies the displayed label for each node. Defaults to
#'   \code{function(node) node$label \%||\% node$id} (use the id when the
#'   node has no label).
#' @param node_class `NULL` or a function \code{(node) -> string} that
#'   supplies a Mermaid CSS class name for each node. Defaults to
#'   \code{function(node) node$state \%||\% NA_character_}; when the
#'   function returns `NA`, no `class` line is emitted for that node.
#' @param direction Single character string, the Mermaid flowchart
#'   direction. Defaults to `"TD"` (top-down). Common alternatives are
#'   `"LR"`, `"RL"`, and `"BT"`.
#'
#' @return A length-1 character scalar containing the full Mermaid
#'   flowchart block, with lines separated by `\n`. An empty graph yields
#'   just the header line (e.g. `"flowchart TD\n"`).
#'
#' @details
#'
#' **Output shape.** The first line is `flowchart <direction>`. Node lines
#' follow (one per node in `names(graph$nodes)` insertion order):
#'
#' ```
#'   <id>["<sanitized_label>"]
#' ```
#'
#' and, when a non-`NA` class string is produced, a companion line:
#'
#' ```
#'   class <id> <class>
#' ```
#'
#' Edge lines follow all node/class lines (Mermaid accepts either order;
#' node-first is conventional):
#'
#' ```
#'   <from> --> <to>
#' ```
#'
#' Edges carrying one or more **pending** gates are annotated with the
#' gate ids joined by `", "`, e.g. `  <from> -- "gate: g1, g2" --> <to>`.
#' Resolved gates produce no annotation.
#'
#' **Sanitization.** Mermaid breaks on `"`, `(`, `)`, `[`, `]`, `{`, `}`,
#' `|`, `<`, `>`, and embedded newlines. Node labels and gate annotation
#' text are sanitized: `"` becomes `'` and the other characters become
#' single spaces (with runs of whitespace collapsed and trimmed). This
#' keeps hostile labels on a single rendered line. A `node_label` /
#' `node_class` return value that is `NULL`, `NA`, multi-element, or
#' non-character is coerced to a length-1 character string (and becomes
#' `""` if coercion yields `NA`); this lenient fallback is deliberate so a
#' misbehaving label function never crashes rendering.
#'
#' **Direction is passed through verbatim.** Only `direction`'s type is
#' validated (single non-NA non-empty string); the value is not checked
#' against an allowlist, so `"TD"`, `"LR"`, `"RL"`, and `"BT"` work but an
#' unknown value will be emitted as-is and Mermaid will fail to render it.
#'
#' **Node ids are NOT sanitized.** They are emitted verbatim as Mermaid
#' node identifiers, so they MUST be Mermaid-safe identifiers
#' (alphanumeric / underscore is safe). The editing API guarantees this
#' by convention; callers building graphs from untrusted sources must
#' validate ids before rendering.
#'
#' **Purity.** This function is pure string output with zero new
#' dependencies and no I/O. It validates the graph once at entry via
#' [dagri_validate_graph()].
#'
#' @examples
#' graph <- dagri_graph(dagri_registry(dagri_kind("source"), dagri_kind("fit")))
#' graph <- dagri_add_node(graph, "data", "source", label = "Data")
#' graph <- dagri_add_node(graph, "fit", "fit", label = "Fit")
#' graph <- dagri_add_edge(graph, "data", "fit", id = "e1")
#' cat(dagri_mermaid(graph))
#' @export
dagri_mermaid <- function(graph, node_label = NULL, node_class = NULL, direction = "TD") {
  dagri_validate_graph(graph)

  if (
    !is.character(direction) || length(direction) != 1L || is.na(direction) || !nzchar(direction)
  ) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`direction` must be a single non-NA character string, got %s.",
        paste(class(direction), collapse = "/")
      )
    )
  }
  if (is.null(node_label)) {
    node_label <- function(node) node$label %||% node$id
  } else if (!is.function(node_label)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`node_label` must be NULL or a function, got %s.",
        paste(class(node_label), collapse = "/")
      )
    )
  }
  if (is.null(node_class)) {
    node_class <- function(node) node$state %||% NA_character_
  } else if (!is.function(node_class)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`node_class` must be NULL or a function, got %s.",
        paste(class(node_class), collapse = "/")
      )
    )
  }

  lines <- character()
  lines <- c(lines, sprintf("flowchart %s", direction))

  # Pending gates grouped by edge id, in graph insertion order.
  pending_by_edge <- list()
  for (gate in graph$gates) {
    if (identical(gate$status, "pending")) {
      pending_by_edge[[gate$edge_id]] <- c(pending_by_edge[[gate$edge_id]], gate$id)
    }
  }

  for (node_id in names(graph$nodes)) {
    node <- graph$nodes[[node_id]]
    label_raw <- node_label(node)
    label <- dagri_mermaid_sanitize(label_raw)
    lines <- c(lines, sprintf("  %s[\"%s\"]", node_id, label))

    klass <- node_class(node)
    if (is.character(klass) && length(klass) == 1L && !is.na(klass) && nzchar(klass)) {
      lines <- c(lines, sprintf("  class %s %s", node_id, klass))
    }
  }

  for (edge_id in names(graph$edges)) {
    edge <- graph$edges[[edge_id]]
    pending <- pending_by_edge[[edge_id]]
    if (length(pending) > 0L) {
      annotation <- dagri_mermaid_sanitize(sprintf("gate: %s", paste(pending, collapse = ", ")))
      lines <- c(lines, sprintf("  %s -- \"%s\" --> %s", edge$from, annotation, edge$to))
    } else {
      lines <- c(lines, sprintf("  %s --> %s", edge$from, edge$to))
    }
  }

  paste0(paste(lines, collapse = "\n"), "\n")
}
