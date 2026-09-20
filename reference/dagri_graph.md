# Create an empty dagriculture graph

Returns a new immutable graph carrying the given registry and empty
node/edge/gate collections. The result has S3 class
`c("dagri_graph", "list")` so
[`print.dagri_graph()`](https://sims1253.github.io/dagriculture/reference/print.dagri_graph.md)
dispatches; underneath it remains a plain named list and serializes
identically to before. Graph-mutating functions
([`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md),
[`dagri_add_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_add_edge.md),
...) preserve the class on the returned copy.

## Usage

``` r
dagri_graph(registry, metadata = list())
```

## Arguments

- registry:

  A `dagri_registry` object.

- metadata:

  Opaque caller-owned extension data: a named list of plain data (nested
  lists, vectors, and scalars are fine). Closures, environments,
  formulas, language objects, S4 objects, external pointers, and weak
  references are rejected recursively.

## Value

A `dagri_graph` (a named list with S3 class `c("dagri_graph", "list")`)
with fields `registry`, `nodes`, `edges`, `gates`, `version` (0L), and
`metadata`.

## Details

Graph-level `metadata` is opaque caller-owned extension data; every
record type (kind, registry, graph, node, edge, gate) carries the same
field. It must be a named list of plain data — closures, environments,
formulas, language objects, S4 objects, external pointers, and weak
references are rejected recursively — so it stays serializable under the
persistence contract.

## Errors

- `dagri_error_invalid_argument` when `metadata` is not a named list of
  plain data.

## Examples

``` r
reg <- dagri_registry(dagri_kind("source"))
g <- dagri_graph(reg, metadata = list(project = "pilot"))
g$version
#> [1] 0
g$metadata
#> $project
#> [1] "pilot"
#> 
```
