# Tests for the Mermaid flowchart export (PLAN.md Milestone 4).

build_small_graph <- function() {
  graph <- dagri_graph(dagri_registry())
  graph$registry$kinds[["source"]] <- dagri_kind("source")
  graph$registry$kinds[["fit"]] <- dagri_kind("fit")
  graph$registry$kinds[["ppc"]] <- dagri_kind("ppc")

  graph <- dagri_add_node(graph, "node_a", "source", label = "A")
  graph <- dagri_add_node(graph, "node_b", "fit") # no label -> id used
  graph <- dagri_add_node(graph, "node_c", "ppc", label = "C")
  graph <- dagri_add_edge(graph, "node_a", "node_b", id = "edge_b")
  graph <- dagri_add_edge(graph, "node_b", "node_c", id = "edge_c")
  graph
}

describe("dagri_mermaid", {
  it("emits just the header for an empty graph", {
    graph <- dagri_graph(dagri_registry())
    expect_equal(dagri_mermaid(graph), "flowchart TD\n")
  })

  it("renders a small graph with the exact expected output", {
    graph <- build_small_graph()
    expected <- paste0(
      "flowchart TD\n",
      "  node_a[\"A\"]\n",
      "  class node_a new\n",
      "  node_b[\"node_b\"]\n",
      "  class node_b new\n",
      "  node_c[\"C\"]\n",
      "  class node_c new\n",
      "  node_a --> node_b\n",
      "  node_b --> node_c\n"
    )
    expect_equal(dagri_mermaid(graph), expected)
  })

  it("returns a length-1 character scalar", {
    out <- dagri_mermaid(build_small_graph())
    expect_type(out, "character")
    expect_length(out, 1L)
  })

  it("honors custom node_label and node_class functions", {
    graph <- build_small_graph()
    out <- dagri_mermaid(
      graph,
      node_label = function(n) toupper(n$id),
      node_class = function(n) "custom"
    )
    expect_match(out, '  node_a\\["NODE_A"\\]', fixed = FALSE)
    expect_match(out, '  class node_a custom')
    # No default state class leaks through.
    expect_false(grepl("class node_a new", out, fixed = TRUE))
  })

  it("skips the class line when node_class returns NA or empty", {
    graph <- build_small_graph()
    out <- dagri_mermaid(graph, node_class = function(n) NA_character_)
    expect_false(grepl("class ", out, fixed = TRUE))

    out_empty <- dagri_mermaid(graph, node_class = function(n) "")
    expect_false(grepl("class ", out_empty, fixed = TRUE))
  })

  it("renders a pending gate as an edge annotation", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "g_pending")
    graph <- dagri_add_gate(graph, "edge_c", id = "g_resolved")
    graph <- dagri_resolve_gate(graph, "g_resolved")

    out <- dagri_mermaid(graph)

    # Pending gate is annotated on its edge.
    expect_match(out, '  node_a -- "gate: g_pending" --> node_b', fixed = TRUE)
    # Resolved gate is NOT annotated on its edge.
    expect_match(out, "  node_b --> node_c", fixed = TRUE)
    expect_false(grepl("g_resolved", out, fixed = TRUE))
  })

  it("joins multiple pending gates on one edge with ', '", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "g1")
    graph <- dagri_add_gate(graph, "edge_b", id = "g2")
    out <- dagri_mermaid(graph)
    expect_match(out, '  node_a -- "gate: g1, g2" --> node_b', fixed = TRUE)
  })

  it("sanitizes hostile labels", {
    graph <- dagri_graph(dagri_registry())
    graph$registry$kinds[["source"]] <- dagri_kind("source")
    graph <- dagri_add_node(
      graph,
      "n",
      "source",
      label = 'naughty "label" with [brackets] and | pipe'
    )
    out <- dagri_mermaid(graph)
    # The label line is the only place a bracket should appear (from the
    # mermaid node syntax `n["..."]`), and no raw `"`, `[`, `]`, or `|`
    # appear inside the rendered label payload.
    # Extract the rendered label payload: strip leading `  n["` and trailing `"]`.
    node_line <- grep('^  n\\["', strsplit(out, "\n")[[1]], value = TRUE)
    payload <- sub('^  n\\["', "", node_line)
    payload <- sub('"\\]$', "", payload)
    # No raw hostile characters survive sanitization inside the payload.
    expect_false(grepl('"', payload, fixed = TRUE))
    expect_false(grepl("[", payload, fixed = TRUE))
    expect_false(grepl("]", payload, fixed = TRUE))
    expect_false(grepl("|", payload, fixed = TRUE))
    # And pin the exact sanitized output.
    expect_equal(payload, "naughty 'label' with brackets and pipe")
  })

  it("sanitizes a label containing a newline", {
    graph <- dagri_graph(dagri_registry())
    graph$registry$kinds[["source"]] <- dagri_kind("source")
    graph <- dagri_add_node(graph, "n", "source", label = "line one\nline two")
    out <- dagri_mermaid(graph)
    # The node line must not contain a literal newline inside the label;
    # the label is collapsed to a single space.
    expect_match(out, '  n\\["line one line two"\\]', fixed = FALSE)
    expect_equal(length(strsplit(out, "\n")[[1]]), 3L) # header + node + class
  })

  it("respects a custom direction in the header", {
    graph <- build_small_graph()
    out <- dagri_mermaid(graph, direction = "LR")
    expect_match(out, "^flowchart LR\n", fixed = FALSE)
  })

  it("aborts on non-string direction", {
    graph <- dagri_graph(dagri_registry())
    expect_snapshot(error = TRUE, dagri_mermaid(graph, direction = 123))
    expect_snapshot(error = TRUE, dagri_mermaid(graph, direction = NA_character_))
  })

  it("aborts on non-function node_label / node_class", {
    graph <- build_small_graph()
    expect_snapshot(error = TRUE, dagri_mermaid(graph, node_label = "nope"))
    expect_snapshot(error = TRUE, dagri_mermaid(graph, node_class = 42))
  })

  it("aborts on a malformed graph", {
    expect_snapshot(error = TRUE, dagri_mermaid(list(nodes = list())))
  })
})
