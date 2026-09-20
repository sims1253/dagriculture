# Render a dagriculture graph as Mermaid flowchart text

Emits a [Mermaid](https://mermaid.js.org/) flowchart as a single
length-1 character scalar with embedded newlines (`\n`). The output is
the literal `flowchart` block — paste it into a Mermaid renderer or wrap
it in a fenced code block in Markdown.

## Usage

``` r
dagri_mermaid(
  graph,
  node_label = NULL,
  node_class = NULL,
  direction = "TD",
  gate_label = NULL,
  include_resolved_gates = FALSE,
  class_defs = character(),
  header = character()
)
```

## Arguments

- graph:

  A `dagri_graph`.

- node_label:

  `NULL` or a function `(node) -> string` that supplies the displayed
  label for each node. Defaults to
  `function(node) node$label %||% node$id` (use the id when the node has
  no label).

- node_class:

  `NULL` or a function `(node) -> string` that supplies a Mermaid CSS
  class name for each node. Defaults to
  `function(node) node$state %||% NA_character_`; when the function
  returns `NA`, no `class` line is emitted for that node.

- direction:

  Single character string, the Mermaid flowchart direction. Defaults to
  `"TD"` (top-down). Common alternatives are `"LR"`, `"RL"`, and `"BT"`.

- gate_label:

  `NULL` (default) or a function `(gate, edge) -> string` supplying the
  annotation label for each gate — e.g. `"pending review"`,
  `"signed off"`, or a reviewer name pulled from `gate$metadata` —
  instead of the default `gate: <id>` text. `gate` is the full gate
  record (`id`, `edge_id`, `status`, `metadata`) and `edge` is the full
  edge record (`id`, `from`, `to`, `type`, `metadata`). The return
  contract mirrors `node_label`: a single string is used (after
  sanitization); `NULL` or a scalar `NA` (of any type) falls back to the
  default `gate: <id>` label for that gate; non-character returns are
  coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html); a return
  that is still not a single non-`NA` string after coercion (e.g. a
  multi-element vector) becomes `""`.

- include_resolved_gates:

  Single non-`NA` logical, default `FALSE`. When `TRUE`, gates with
  `status == "resolved"` are also annotated on their edge, with the
  constant `" (resolved)"` appended to each resolved gate's label (after
  the callback/default label). Pending gates render exactly as they do
  with the default. With `FALSE` (the default), resolved gates produce
  no annotation.

- class_defs:

  Character vector of Mermaid `classDef` statements (e.g.
  `"classDef ready fill:#e8f5e9"`), default
  [`character()`](https://rdrr.io/r/base/character.html) (no lines).
  Each element must be a single non-`NA` string and is sanitized with
  the label sanitizer, then emitted on its own line after the
  `flowchart` line and before the node lines, in the given order.
  Because the sanitizer strips parentheses, prefer 8-digit hex color
  forms (e.g. `fill:#3480db66`) over `rgba(...)` colors, whose
  parentheses are removed. `NULL` is treated as
  [`character()`](https://rdrr.io/r/base/character.html).

- header:

  Character vector of raw Mermaid preamble lines, default
  [`character()`](https://rdrr.io/r/base/character.html). Each element
  must be a single non-`NA` string; lines are emitted before the
  `flowchart` line in the given order. Because legitimate directives
  such as `%%{init: ...}%%` contain braces and quotes that the label
  sanitizer would destroy, `header` lines are NOT run through the full
  sanitizer — control characters (including CR/LF) are replaced with
  spaces and whitespace runs are collapsed, nothing more. `header` is
  trusted caller input; everything derived from graph data (labels,
  classes, gate annotations, `class_defs`) stays sanitized. `NULL` is
  treated as [`character()`](https://rdrr.io/r/base/character.html).

## Value

A length-1 character scalar containing the full Mermaid flowchart block,
with lines separated by `\n`. An empty graph yields just the `flowchart`
line (e.g. `"flowchart TD\n"`).

## Details

**Byte-compatibility.** With every argument at its default
(`gate_label = NULL`, `include_resolved_gates = FALSE`,
`class_defs = character()`, `header = character()`) the output is
byte-for-byte identical to the renderer without the customization hooks;
the hooks only add lines or change annotations when they are explicitly
enabled.

**Output shape.** Optional `header` lines come first (verbatim except
control-character stripping), then the `flowchart <direction>` line,
then optional `classDef` lines (one per `class_defs` element, in order).
Node lines follow (one per node in `names(graph$nodes)` insertion
order):

      <id>["<sanitized_label>"]

and, when a non-`NA` class string is produced, a companion line:

      class <id> <class>

Edge lines follow all node/class lines:

      <from> --> <to>

Edges carrying one or more **pending** gates are annotated with the gate
labels joined by `", "` in gate insertion order, e.g.
` <from> -- "gate: g1, g2" --> <to>`. With
`include_resolved_gates = TRUE`, resolved gates join the annotation in
the same insertion order, each suffixed with ` (resolved)`. When
`gate_label` is supplied, each gate's label is the callback's return
value (or the `gate: <id>` fallback), joined by `", "`.

**Sanitization.** Mermaid breaks on `"`, `(`, `)`, `[`, `]`, `{`, `}`,
`|`, `<`, `>`, and embedded newlines. Node labels, gate annotation text,
and `class_defs` lines are sanitized: `"` becomes `'` and the other
characters become single spaces (with runs of whitespace collapsed and
trimmed). A `node_label` / `node_class` return value that is `NULL`,
`NA`, multi-element, or non-character is coerced to a length-1 character
string (and becomes `""` if coercion yields `NA`); `gate_label` returns
follow the same coercion with the `gate: <id>` fallback described above.
The `" (resolved)"` suffix is a renderer-owned constant appended after
sanitization, so it is the one place parentheses appear in annotation
text. The `header` lines are the deliberate exception: they are trusted
caller input and are only stripped of control characters with whitespace
collapsed, because the full sanitizer would destroy legitimate init
directives.

**Node ids are NOT sanitized.** They are emitted verbatim as Mermaid
node identifiers, so they MUST be Mermaid-safe (alphanumeric /
underscore is safe). Callers building graphs from untrusted sources must
validate ids before rendering.

**Direction is passed through verbatim.** Only `direction`'s type is
validated (single non-NA non-empty string); the value is not checked
against an allowlist, so an unknown value is emitted as-is and Mermaid
will fail to render it.

**Determinism.** Nodes, edges, and gates are emitted in graph insertion
order, and multi-gate annotations join in gate insertion order, so
repeated calls on the same graph value always produce the same string
(snapshot-friendly).

## Examples

``` r
graph <- dagri_graph(dagri_registry(dagri_kind("source"), dagri_kind("fit")))
graph <- dagri_add_node(graph, "data", "source", label = "Data")
graph <- dagri_add_node(graph, "fit", "fit", label = "Fit")
graph <- dagri_add_edge(graph, "data", "fit", id = "e1")
cat(dagri_mermaid(graph))
#> flowchart TD
#>   data["Data"]
#>   class data new
#>   fit["Fit"]
#>   class fit new
#>   data --> fit

# Custom gate labels via the gate_label callback
graph <- dagri_add_gate(graph, "e1", id = "review")
cat(dagri_mermaid(graph, gate_label = function(gate, edge) {
  reviewer <- gate$metadata$reviewer
  if (is.null(reviewer)) "pending review" else paste("review by", reviewer)
}))
#> flowchart TD
#>   data["Data"]
#>   class data new
#>   fit["Fit"]
#>   class fit new
#>   data -- "pending review" --> fit

# Resolved gates join the annotation when asked to
graph <- dagri_resolve_gate(graph, "review")
cat(dagri_mermaid(graph, include_resolved_gates = TRUE))
#> flowchart TD
#>   data["Data"]
#>   class data new
#>   fit["Fit"]
#>   class fit new
#>   data -- "gate: review (resolved)" --> fit

# Style classes via class_defs (emitted right after the flowchart line)
graph <- dagri_reopen_gate(graph, "review")
cat(dagri_mermaid(
  graph,
  node_class = function(node) node$state,
  class_defs = c(
    "classDef ready fill:#e8f5e9",
    "classDef new fill:#fff3e0"
  )
))
#> flowchart TD
#>   classDef ready fill:#e8f5e9
#>   classDef new fill:#fff3e0
#>   data["Data"]
#>   class data new
#>   fit["Fit"]
#>   class fit new
#>   data -- "gate: review" --> fit
```
