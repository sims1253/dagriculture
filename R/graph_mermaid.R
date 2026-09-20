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

# --- Internal: header line cleaning ---

# `header` lines are trusted caller input: legitimate Mermaid init
# directives contain braces and quotes that dagri_mermaid_sanitize() would
# destroy. They only get line-safety cleaning here — control characters
# (CR/LF/tabs/...) are replaced with spaces and whitespace runs are
# collapsed — so a single element can never inject additional lines into
# the emitted block.
dagri_mermaid_clean_header <- function(x) {
  x <- gsub("[[:cntrl:]]", " ", x)
  x <- gsub("[ \t]+", " ", x)
  trimws(x)
}

# --- Internal: per-gate edge annotation segment ---

# Sanitized annotation text for a single gate on an edge. `gate_label` is
# the caller's callback or NULL (default rendering). A callback return of
# NULL or a scalar NA (of any type) falls back to the default
# `gate: <id>` label; any other return is coerced exactly like a
# `node_label` return (via dagri_mermaid_sanitize(): non-character values
# are coerced with as.character(), and values that are still not a single
# non-NA string become ""). The renderer-owned " (resolved)" marker is
# appended after sanitization so its parentheses survive verbatim; the
# marker is a constant and carries no graph-derived data.
dagri_mermaid_gate_segment <- function(gate, edge, gate_label, mark_resolved) {
  if (is.null(gate_label)) {
    segment <- dagri_mermaid_sanitize(gate$id)
  } else {
    raw <- gate_label(gate, edge)
    if (is.null(raw) || (is.atomic(raw) && length(raw) == 1L && is.na(raw))) {
      raw <- sprintf("gate: %s", gate$id)
    }
    segment <- dagri_mermaid_sanitize(raw)
  }
  if (mark_resolved && identical(gate$status, "resolved")) {
    segment <- paste0(segment, " (resolved)")
  }
  segment
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
#' @param gate_label `NULL` (default) or a function
#'   \code{(gate, edge) -> string} supplying the annotation label for each
#'   gate — e.g. `"pending review"`, `"signed off"`, or a reviewer name
#'   pulled from `gate$metadata` — instead of the default `gate: <id>`
#'   text. `gate` is the full gate record (`id`, `edge_id`, `status`,
#'   `metadata`) and `edge` is the full edge record (`id`, `from`, `to`,
#'   `type`, `metadata`). The return contract mirrors `node_label`: a
#'   single string is used (after sanitization); `NULL` or a scalar `NA`
#'   (of any type) falls back to the default `gate: <id>` label for that
#'   gate; non-character returns are coerced with [as.character()]; a
#'   return that is still not a single non-`NA` string after coercion
#'   (e.g. a multi-element vector) becomes `""`.
#' @param include_resolved_gates Single non-`NA` logical, default `FALSE`.
#'   When `TRUE`, gates with `status == "resolved"` are also annotated on
#'   their edge, with the constant `" (resolved)"` appended to each
#'   resolved gate's label (after the callback/default label). Pending
#'   gates render exactly as they do with the default. With `FALSE` (the
#'   default), resolved gates produce no annotation.
#' @param class_defs Character vector of Mermaid `classDef` statements
#'   (e.g. `"classDef ready fill:#e8f5e9"`), default `character()` (no
#'   lines). Each element must be a single non-`NA` string and is
#'   sanitized with the label sanitizer, then emitted on its own line
#'   after the `flowchart` line and before the node lines, in the given
#'   order. Because the sanitizer strips parentheses, prefer 8-digit hex
#'   color forms (e.g. `fill:#3480db66`) over `rgba(...)` colors, whose
#'   parentheses are removed. `NULL` is treated as `character()`.
#' @param header Character vector of raw Mermaid preamble lines, default
#'   `character()`. Each element must be a single non-`NA` string; lines
#'   are emitted before the `flowchart` line in the given order. Because
#'   legitimate directives such as \code{\%\%\{init: ...\}\%\%} contain
#'   braces and quotes that the label sanitizer would destroy, `header`
#'   lines are NOT run through the full sanitizer — control characters
#'   (including CR/LF) are replaced with spaces and whitespace runs are
#'   collapsed, nothing more. `header` is trusted caller input; everything
#'   derived from graph data (labels, classes, gate annotations,
#'   `class_defs`) stays sanitized. `NULL` is treated as `character()`.
#'
#' @return A length-1 character scalar containing the full Mermaid
#'   flowchart block, with lines separated by `\n`. An empty graph yields
#'   just the `flowchart` line (e.g. `"flowchart TD\n"`).
#'
#' @details
#'
#' **Byte-compatibility.** With every argument at its default
#' (`gate_label = NULL`, `include_resolved_gates = FALSE`,
#' `class_defs = character()`, `header = character()`) the output is
#' byte-for-byte identical to the renderer without the customization
#' hooks; the hooks only add lines or change annotations when they are
#' explicitly enabled.
#'
#' **Output shape.** Optional `header` lines come first (verbatim except
#' control-character stripping), then the `flowchart <direction>` line,
#' then optional `classDef` lines (one per `class_defs` element, in
#' order). Node lines follow (one per node in `names(graph$nodes)`
#' insertion order):
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
#' Edge lines follow all node/class lines:
#'
#' ```
#'   <from> --> <to>
#' ```
#'
#' Edges carrying one or more **pending** gates are annotated with the
#' gate labels joined by `", "` in gate insertion order, e.g.
#' `  <from> -- "gate: g1, g2" --> <to>`. With
#' `include_resolved_gates = TRUE`, resolved gates join the annotation in
#' the same insertion order, each suffixed with ` (resolved)`. When
#' `gate_label` is supplied, each gate's label is the callback's return
#' value (or the `gate: <id>` fallback), joined by `", "`.
#'
#' **Sanitization.** Mermaid breaks on `"`, `(`, `)`, `[`, `]`, `{`, `}`,
#' `|`, `<`, `>`, and embedded newlines. Node labels, gate annotation
#' text, and `class_defs` lines are sanitized: `"` becomes `'` and the
#' other characters become single spaces (with runs of whitespace
#' collapsed and trimmed). A `node_label` / `node_class` return value that
#' is `NULL`, `NA`, multi-element, or non-character is coerced to a
#' length-1 character string (and becomes `""` if coercion yields `NA`);
#' `gate_label` returns follow the same coercion with the `gate: <id>`
#' fallback described above. The `" (resolved)"` suffix is a
#' renderer-owned constant appended after sanitization, so it is the one
#' place parentheses appear in annotation text. The `header` lines are
#' the deliberate exception: they are trusted caller input and are only
#' stripped of control characters with whitespace collapsed, because the
#' full sanitizer would destroy legitimate init directives.
#'
#' **Node ids are NOT sanitized.** They are emitted verbatim as Mermaid
#' node identifiers, so they MUST be Mermaid-safe (alphanumeric /
#' underscore is safe). Callers building graphs from untrusted sources
#' must validate ids before rendering.
#'
#' **Direction is passed through verbatim.** Only `direction`'s type is
#' validated (single non-NA non-empty string); the value is not checked
#' against an allowlist, so an unknown value is emitted as-is and Mermaid
#' will fail to render it.
#'
#' **Determinism.** Nodes, edges, and gates are emitted in graph
#' insertion order, and multi-gate annotations join in gate insertion
#' order, so repeated calls on the same graph value always produce the
#' same string (snapshot-friendly).
#'
#' @examples
#' graph <- dagri_graph(dagri_registry(dagri_kind("source"), dagri_kind("fit")))
#' graph <- dagri_add_node(graph, "data", "source", label = "Data")
#' graph <- dagri_add_node(graph, "fit", "fit", label = "Fit")
#' graph <- dagri_add_edge(graph, "data", "fit", id = "e1")
#' cat(dagri_mermaid(graph))
#'
#' # Custom gate labels via the gate_label callback
#' graph <- dagri_add_gate(graph, "e1", id = "review")
#' cat(dagri_mermaid(graph, gate_label = function(gate, edge) {
#'   reviewer <- gate$metadata$reviewer
#'   if (is.null(reviewer)) "pending review" else paste("review by", reviewer)
#' }))
#'
#' # Resolved gates join the annotation when asked to
#' graph <- dagri_resolve_gate(graph, "review")
#' cat(dagri_mermaid(graph, include_resolved_gates = TRUE))
#'
#' # Style classes via class_defs (emitted right after the flowchart line)
#' graph <- dagri_reopen_gate(graph, "review")
#' cat(dagri_mermaid(
#'   graph,
#'   node_class = function(node) node$state,
#'   class_defs = c(
#'     "classDef ready fill:#e8f5e9",
#'     "classDef new fill:#fff3e0"
#'   )
#' ))
#' @export
dagri_mermaid <- function(
  graph,
  node_label = NULL,
  node_class = NULL,
  direction = "TD",
  gate_label = NULL,
  include_resolved_gates = FALSE,
  class_defs = character(),
  header = character()
) {
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
  if (!is.null(gate_label) && !is.function(gate_label)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`gate_label` must be NULL or a function, got %s.",
        paste(class(gate_label), collapse = "/")
      )
    )
  }
  if (
    !is.logical(include_resolved_gates) ||
      length(include_resolved_gates) != 1L ||
      is.na(include_resolved_gates)
  ) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`include_resolved_gates` must be a single non-NA logical, got %s.",
        paste(class(include_resolved_gates), collapse = "/")
      )
    )
  }
  if (is.null(class_defs)) {
    class_defs <- character()
  }
  if (!is.character(class_defs) || anyNA(class_defs)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        paste0(
          "`class_defs` must be a character vector of Mermaid classDef ",
          "statements without NAs, got %s."
        ),
        paste(class(class_defs), collapse = "/")
      )
    )
  }
  if (is.null(header)) {
    header <- character()
  }
  if (!is.character(header) || anyNA(header)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`header` must be a character vector of single non-NA Mermaid preamble lines, got %s.",
        paste(class(header), collapse = "/")
      )
    )
  }

  lines <- character()
  if (length(header) > 0L) {
    lines <- c(lines, vapply(header, dagri_mermaid_clean_header, character(1)))
  }
  lines <- c(lines, sprintf("flowchart %s", direction))
  if (length(class_defs) > 0L) {
    lines <- c(
      lines,
      sprintf("  %s", vapply(class_defs, dagri_mermaid_sanitize, character(1)))
    )
  }

  # Gates grouped by edge id, in graph insertion order. Pending gates are
  # always collected; resolved gates only when include_resolved_gates is on.
  gates_by_edge <- list()
  for (gate in graph$gates) {
    if (
      identical(gate$status, "pending") ||
        (include_resolved_gates && identical(gate$status, "resolved"))
    ) {
      gates_by_edge[[gate$edge_id]] <- c(gates_by_edge[[gate$edge_id]], list(gate))
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
    included <- gates_by_edge[[edge_id]]
    if (length(included) == 0L) {
      lines <- c(lines, sprintf("  %s --> %s", edge$from, edge$to))
      next
    }
    has_resolved <- any(
      vapply(included, function(gate) identical(gate$status, "resolved"), logical(1))
    )
    if (is.null(gate_label) && !has_resolved) {
      # Historical default: all pending gate ids under one `gate:` prefix,
      # sanitized as a single string. Kept verbatim for byte-compatibility.
      ids <- vapply(included, function(gate) gate$id, character(1))
      annotation <- dagri_mermaid_sanitize(sprintf("gate: %s", paste(ids, collapse = ", ")))
    } else {
      segments <- vapply(
        included,
        function(gate) {
          dagri_mermaid_gate_segment(gate, edge, gate_label, include_resolved_gates)
        },
        character(1)
      )
      annotation <- if (is.null(gate_label)) {
        paste0("gate: ", paste(segments, collapse = ", "))
      } else {
        paste(segments, collapse = ", ")
      }
    }
    lines <- c(lines, sprintf("  %s -- \"%s\" --> %s", edge$from, annotation, edge$to))
  }

  paste0(paste(lines, collapse = "\n"), "\n")
}
