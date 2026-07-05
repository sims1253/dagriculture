# Render a dagriculture graph as Mermaid flowchart text

Emits a [Mermaid](https://mermaid.js.org/) flowchart as a single
length-1 character scalar with embedded newlines (`\n`). The output is
the literal `flowchart` block — paste it into a Mermaid renderer or wrap
it in a fenced code block in Markdown.

## Usage

``` r
dagri_mermaid(graph, node_label = NULL, node_class = NULL, direction = "TD")
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

## Value

A length-1 character scalar containing the full Mermaid flowchart block,
with lines separated by `\n`. An empty graph yields just the header line
(e.g. `"flowchart TD\n"`).

## Details

**Output shape.** The first line is `flowchart <direction>`. Node lines
follow (one per node in `names(graph$nodes)` insertion order):

      <id>["<sanitized_label>"]

and, when a non-`NA` class string is produced, a companion line:

      class <id> <class>

Edge lines follow all node/class lines:

      <from> --> <to>

Edges carrying one or more **pending** gates are annotated with the gate
ids joined by `", "`, e.g. ` <from> -- "gate: g1, g2" --> <to>`.
Resolved gates produce no annotation.

**Sanitization.** Mermaid breaks on `"`, `(`, `)`, `[`, `]`, `{`, `}`,
`|`, `<`, `>`, and embedded newlines. Node labels and gate annotation
text are sanitized: `"` becomes `'` and the other characters become
single spaces (with runs of whitespace collapsed and trimmed). A
`node_label` / `node_class` return value that is `NULL`, `NA`,
multi-element, or non-character is coerced to a length-1 character
string (and becomes `""` if coercion yields `NA`).

**Node ids are NOT sanitized.** They are emitted verbatim as Mermaid
node identifiers, so they MUST be Mermaid-safe (alphanumeric /
underscore is safe). Callers building graphs from untrusted sources must
validate ids before rendering.

**Direction is passed through verbatim.** Only `direction`'s type is
validated (single non-NA non-empty string); the value is not checked
against an allowlist, so an unknown value is emitted as-is and Mermaid
will fail to render it.

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
```
