# Tests for the Mermaid flowchart export.

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
    expect_match(out, "  class node_a custom")
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
    expect_equal(length(strsplit(out, "\n")[[1]]), 3L) # header, node, class
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

  it("is byte-identical to the pre-hook renderer on a gated fixture", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "g_pending")
    graph <- dagri_add_gate(graph, "edge_c", id = "g_resolved")
    graph <- dagri_resolve_gate(graph, "g_resolved")
    expect_identical(
      dagri_mermaid(graph),
      paste0(
        "flowchart TD\n",
        "  node_a[\"A\"]\n",
        "  class node_a new\n",
        "  node_b[\"node_b\"]\n",
        "  class node_b new\n",
        "  node_c[\"C\"]\n",
        "  class node_c new\n",
        "  node_a -- \"gate: g_pending\" --> node_b\n",
        "  node_b --> node_c\n"
      )
    )
  })

  it("uses sanitized gate_label callback results joined in gate order", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "g1")
    graph <- dagri_add_gate(graph, "edge_b", id = "g2")
    out <- dagri_mermaid(graph, gate_label = function(gate, edge) {
      sprintf("state: %s <%s>", gate$id, gate$status)
    })
    # Angle brackets are sanitized away and whitespace collapses, but the
    # join order follows gate insertion order.
    expect_match(out, '  node_a -- "state: g1 pending, state: g2 pending" --> node_b', fixed = TRUE)

    out_quote <- dagri_mermaid(graph, gate_label = function(gate, edge) 'pending "review"')
    expect_match(
      out_quote,
      "  node_a -- \"pending 'review', pending 'review'\" --> node_b",
      fixed = TRUE
    )
  })

  it("falls back to the default gate label on NULL or NA gate_label returns", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "g1")
    graph <- dagri_add_gate(graph, "edge_b", id = "g2")
    out_null <- dagri_mermaid(graph, gate_label = function(gate, edge) NULL)
    expect_match(out_null, '  node_a -- "gate: g1, gate: g2" --> node_b', fixed = TRUE)
    expect_identical(
      dagri_mermaid(graph, gate_label = function(gate, edge) NA_character_),
      out_null
    )
    expect_identical(dagri_mermaid(graph, gate_label = function(gate, edge) NA), out_null)
  })

  it("coerces weird gate_label returns like node_label returns", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "g1")
    out_num <- dagri_mermaid(graph, gate_label = function(gate, edge) 42)
    expect_match(out_num, '  node_a -- "42" --> node_b', fixed = TRUE)
    # Multi-element returns collapse to "" (same as node_label handling).
    out_multi <- dagri_mermaid(graph, gate_label = function(gate, edge) c("a", "b"))
    expect_match(out_multi, '  node_a -- "" --> node_b', fixed = TRUE)
  })

  it("passes the full gate and edge records to gate_label", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "g1", metadata = list(reviewer = "mara"))
    seen <- FALSE
    out <- dagri_mermaid(graph, gate_label = function(gate, edge) {
      seen <<- TRUE
      expect_identical(gate$id, "g1")
      expect_identical(gate$edge_id, "edge_b")
      expect_identical(gate$status, "pending")
      expect_identical(gate$metadata$reviewer, "mara")
      expect_identical(edge$id, "edge_b")
      expect_identical(edge$from, "node_a")
      expect_identical(edge$to, "node_b")
      expect_identical(edge$type, "data")
      "checked"
    })
    expect_true(seen)
    expect_match(out, '  node_a -- "checked" --> node_b', fixed = TRUE)
  })

  it("annotates resolved gates only when include_resolved_gates = TRUE", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "g1")
    graph <- dagri_add_gate(graph, "edge_b", id = "g2")
    graph <- dagri_add_gate(graph, "edge_c", id = "g3")
    graph <- dagri_resolve_gate(graph, "g2")
    graph <- dagri_resolve_gate(graph, "g3")

    out_on <- dagri_mermaid(graph, include_resolved_gates = TRUE)
    # Mixed edge: pending first, resolved suffixed, gate insertion order.
    expect_match(out_on, '  node_a -- "gate: g1, g2 (resolved)" --> node_b', fixed = TRUE)
    # Resolved-only edge also annotates.
    expect_match(out_on, '  node_b -- "gate: g3 (resolved)" --> node_c', fixed = TRUE)

    # Default FALSE omits resolved gates entirely (byte-identical).
    out_off <- dagri_mermaid(graph)
    expect_false(grepl("resolved", out_off, fixed = TRUE))
    expect_identical(dagri_mermaid(graph, include_resolved_gates = FALSE), out_off)
    expect_match(out_off, '  node_a -- "gate: g1" --> node_b', fixed = TRUE)
    expect_match(out_off, "  node_b --> node_c", fixed = TRUE)
  })

  it("appends the resolved marker after the gate_label result", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "signoff")
    graph <- dagri_resolve_gate(graph, "signoff")
    out <- dagri_mermaid(
      graph,
      gate_label = function(gate, edge) "signed off",
      include_resolved_gates = TRUE
    )
    expect_match(out, '  node_a -- "signed off (resolved)" --> node_b', fixed = TRUE)
  })

  it("keeps pending-gate rendering unchanged when the flag is on", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "g1")
    graph <- dagri_add_gate(graph, "edge_b", id = "g2")
    expect_identical(
      dagri_mermaid(graph, include_resolved_gates = TRUE),
      dagri_mermaid(graph)
    )
  })

  it("emits sanitized class_defs after the flowchart line and before node lines", {
    graph <- build_small_graph()
    out <- dagri_mermaid(
      graph,
      class_defs = c(
        "classDef ready fill:#e8f5e9",
        'classDef "quoted" fill:#fff'
      )
    )
    lines <- strsplit(out, "\n", fixed = TRUE)[[1]]
    expect_identical(lines[1], "flowchart TD")
    expect_identical(lines[2], "  classDef ready fill:#e8f5e9")
    # The embedded double quote is sanitized to a single quote.
    expect_identical(lines[3], "  classDef 'quoted' fill:#fff")
    expect_identical(lines[4], "  node_a[\"A\"]")
  })

  it("accepts header init directives verbatim before the flowchart line", {
    graph <- build_small_graph()
    directive <- '%%{init: {"theme":"neutral","flowchart":{"curve":"linear"}}}%%'
    out <- dagri_mermaid(graph, header = c(directive, "%% node styling hooks below"))
    lines <- strsplit(out, "\n", fixed = TRUE)[[1]]
    expect_identical(lines[1], directive)
    expect_identical(lines[2], "%% node styling hooks below")
    expect_identical(lines[3], "flowchart TD")
    expect_identical(lines[4], "  node_a[\"A\"]")
  })

  it("strips CR/LF and control characters from header lines", {
    graph <- build_small_graph()
    out <- dagri_mermaid(graph, header = "a\r\nb\t\tc")
    # One input element can never inject additional output lines.
    expect_match(out, "^a b c\nflowchart TD\n", fixed = FALSE)
  })

  it("renders header and class_defs on an empty graph", {
    graph <- dagri_graph(dagri_registry())
    out <- dagri_mermaid(graph, header = "%% init", class_defs = "classDef a fill:x")
    expect_identical(out, "%% init\nflowchart TD\n  classDef a fill:x\n")
    # NULL is treated as character() for both arguments.
    expect_identical(dagri_mermaid(graph, header = NULL, class_defs = NULL), "flowchart TD\n")
  })

  it("is deterministic across repeated calls with hooks enabled", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "g1")
    graph <- dagri_add_gate(graph, "edge_c", id = "g2")
    graph <- dagri_resolve_gate(graph, "g2")
    render <- function() {
      dagri_mermaid(
        graph,
        gate_label = function(gate, edge) paste(gate$id, "on", edge$id),
        include_resolved_gates = TRUE,
        class_defs = "classDef ready fill:#e8f5e9",
        header = '%%{init: {"theme":"neutral"}}%%'
      )
    }
    expect_identical(render(), render())
  })

  it("aborts on invalid hook arguments", {
    graph <- build_small_graph()
    expect_error(
      dagri_mermaid(graph, gate_label = "nope"),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_mermaid(graph, include_resolved_gates = "yes"),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_mermaid(graph, class_defs = 1:2),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_mermaid(graph, class_defs = c("classDef a fill:x", NA)),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_mermaid(graph, header = 123),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_mermaid(graph, header = NA_character_),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_mermaid(graph, header = list("a", c("b", "c"))),
      class = "dagri_error_invalid_argument"
    )
    expect_snapshot(error = TRUE, dagri_mermaid(graph, gate_label = "nope"))
    expect_snapshot(error = TRUE, dagri_mermaid(graph, include_resolved_gates = "yes"))
    expect_snapshot(error = TRUE, dagri_mermaid(graph, class_defs = 1:2))
    expect_snapshot(error = TRUE, dagri_mermaid(graph, header = 123))
  })

  it("snapshots the customization hooks together", {
    graph <- build_small_graph()
    graph <- dagri_add_gate(graph, "edge_b", id = "review", metadata = list(reviewer = "mara"))
    graph <- dagri_add_gate(graph, "edge_c", id = "signoff")
    graph <- dagri_resolve_gate(graph, "signoff")
    expect_snapshot(cat(dagri_mermaid(
      graph,
      gate_label = function(gate, edge) {
        reviewer <- gate$metadata$reviewer
        if (is.null(reviewer)) "pending review" else paste("review by", reviewer)
      },
      include_resolved_gates = TRUE,
      class_defs = "classDef ready fill:#e8f5e9",
      header = '%%{init: {"theme":"neutral"}}%%'
    )))
  })
})
