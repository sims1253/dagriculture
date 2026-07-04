# Tests for the print methods (PLAN.md Milestone 5).
#
# A value-oriented library's only interactive UX surface is its print output,
# so the assertions check the load-bearing substrings (counts, version, class
# header) rather than pinning the exact full text, which would be brittle.

describe("print.dagri_graph", {
  build_graph <- function() {
    reg <- dagri_registry(dagri_kind("input"), dagri_kind("model"), dagri_kind("report"))
    dagri_graph(reg) |>
      dagri_add_node("data", "input", label = "Raw Data") |>
      dagri_add_node("fit", "model", label = "Fit") |>
      dagri_add_node("plot", "report", label = "Plot") |>
      dagri_add_edge("data", "fit", id = "e1") |>
      dagri_add_edge("fit", "plot", id = "e2") |>
      dagri_add_gate("e1", id = "approval_gate")
  }

  it("dispatches via S3 on a dagri_graph", {
    g <- build_graph()
    expect_s3_class(g, "dagri_graph")
    out <- capture.output(print(g))
    # The class header anchors the output as the graph print method.
    expect_true(any(grepl("<dagri_graph>", out, fixed = TRUE)))
  })

  it("returns the graph invisibly", {
    g <- build_graph()
    expect_invisible(print(g))
    # The returned value is the same object (not a copy of fields).
    expect_identical(print(g), g)
  })

  it("includes node, edge, and gate counts", {
    g <- build_graph()
    out <- capture.output(print(g))
    collapsed <- paste(out, collapse = "\n")
    expect_true(grepl("nodes: 3", collapsed, fixed = TRUE))
    expect_true(grepl("edges: 2", collapsed, fixed = TRUE))
    expect_true(grepl("gates: 1", collapsed, fixed = TRUE))
  })

  it("includes the graph version", {
    g <- build_graph()
    out <- capture.output(print(g))
    collapsed <- paste(out, collapse = "\n")
    # 3 nodes + 2 edges + 1 gate = 6 mutating ops from version 0.
    expect_true(grepl("version: 6", collapsed, fixed = TRUE))
  })

  it("lists the registry kinds", {
    g <- build_graph()
    out <- capture.output(print(g))
    collapsed <- paste(out, collapse = "\n")
    expect_true(grepl("registry kinds:", collapsed, fixed = TRUE))
    expect_true(grepl("input", collapsed, fixed = TRUE))
    expect_true(grepl("model", collapsed, fixed = TRUE))
    expect_true(grepl("report", collapsed, fixed = TRUE))
  })

  it("reports (none) for an empty registry", {
    g <- dagri_graph(dagri_registry())
    out <- capture.output(print(g))
    collapsed <- paste(out, collapse = "\n")
    expect_true(grepl("registry kinds: (none)", collapsed, fixed = TRUE))
    expect_true(grepl("nodes: 0", collapsed, fixed = TRUE))
  })

  it("prints cleanly for an empty graph", {
    g <- dagri_graph(dagri_registry(dagri_kind("solo")))
    out <- capture.output(print(g))
    collapsed <- paste(out, collapse = "\n")
    expect_true(grepl("nodes: 0", collapsed, fixed = TRUE))
    expect_true(grepl("edges: 0", collapsed, fixed = TRUE))
    expect_true(grepl("gates: 0", collapsed, fixed = TRUE))
    expect_true(grepl("version: 0", collapsed, fixed = TRUE))
  })

  it("preserves the class through mutating operations", {
    g <- dagri_graph(dagri_registry(dagri_kind("a")))
    g1 <- dagri_add_node(g, "n1", "a")
    expect_s3_class(g1, "dagri_graph")
    out <- capture.output(print(g1))
    expect_true(any(grepl("<dagri_graph>", out, fixed = TRUE)))
  })
})

describe("print.dagri_plan", {
  build_plan <- function() {
    reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
    g <- dagri_graph(reg) |>
      dagri_add_node("n1", "source") |>
      dagri_add_node("n2", "process") |>
      dagri_add_node("n3", "process") |>
      dagri_add_edge("n1", "n2", id = "e1") |>
      dagri_add_edge("n2", "n3", id = "e2") |>
      dagri_add_gate("e1", id = "gate1") |>
      dagri_recompute_state()
    dagri_plan(g, targets = "n3")
  }

  it("dispatches via S3 on a dagri_plan", {
    plan <- build_plan()
    expect_s3_class(plan, "dagri_plan")
    out <- capture.output(print(plan))
    expect_true(any(grepl("<dagri_plan>", out, fixed = TRUE)))
  })

  it("returns the plan invisibly", {
    plan <- build_plan()
    expect_invisible(print(plan))
    expect_identical(print(plan), plan)
  })

  it("includes target and topo order counts", {
    plan <- build_plan()
    out <- capture.output(print(plan))
    collapsed <- paste(out, collapse = "\n")
    # The closure of n3 is all three nodes.
    expect_true(grepl("targets: 3", collapsed, fixed = TRUE))
    expect_true(grepl("topo order length: 3", collapsed, fixed = TRUE))
  })

  it("includes eligible, blocked, terminal, and pending gate counts", {
    plan <- build_plan()
    out <- capture.output(print(plan))
    collapsed <- paste(out, collapse = "\n")
    # n1 eligible; n2 (gate) and n3 (upstream_blocked) blocked; n3 terminal;
    # gate1 pending.
    expect_true(grepl("eligible: 1", collapsed, fixed = TRUE))
    expect_true(grepl("blocked: 2", collapsed, fixed = TRUE))
    expect_true(grepl("terminal: 1", collapsed, fixed = TRUE))
    expect_true(grepl("pending gates: 1", collapsed, fixed = TRUE))
  })

  it("prints cleanly for an all-ready plan", {
    reg <- dagri_registry(dagri_kind("a"))
    g <- dagri_graph(reg) |>
      dagri_add_node("n1", "a") |>
      dagri_add_node("n2", "a") |>
      dagri_add_edge("n1", "n2", id = "e1") |>
      dagri_recompute_state()
    plan <- dagri_plan(g)
    out <- capture.output(print(plan))
    collapsed <- paste(out, collapse = "\n")
    expect_true(grepl("<dagri_plan>", out[1], fixed = TRUE))
    expect_true(grepl("blocked: 0", collapsed, fixed = TRUE))
    expect_true(grepl("pending gates: 0", collapsed, fixed = TRUE))
  })

  it("field access still works after the class is added", {
    plan <- build_plan()
    expect_setequal(plan$targets, c("n1", "n2", "n3"))
    expect_identical(plan$blocked[["n2"]], "gate")
    expect_identical(plan$blocked[["n3"]], "upstream_blocked")
    expect_setequal(plan$pending_gates, "gate1")
  })
})
