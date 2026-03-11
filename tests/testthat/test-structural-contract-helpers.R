describe("structural helper contract", {
  it("dagri_target_closure() returns the structural target closure", {
    fixture <- dagri_fixture_gated_chain()

    expect_setequal(
      dagri_target_closure(fixture$graph, fixture$targets),
      c("n1", "n2", "n3")
    )
  })

  it("dagri_target_closure() rejects missing targets", {
    fixture <- dagri_fixture_gated_chain()

    expect_error(
      dagri_target_closure(fixture$graph, "missing"),
      class = "dagri_error_not_found"
    )
  })

  it("dagri_terminal() returns leaves within the scoped target closure", {
    fixture <- dagri_fixture_branching_graph()

    expect_setequal(
      dagri_terminal(fixture$graph, targets = fixture$targets),
      c("n3", "n4")
    )
  })

  it("dagri_pending_gates() scopes pending gates to the structural target closure", {
    fixture <- dagri_fixture_gated_chain()

    expect_setequal(
      dagri_pending_gates(fixture$graph, targets = fixture$targets),
      fixture$gate_id
    )
    expect_identical(
      dagri_pending_gates(fixture$graph, targets = "n1"),
      character(0)
    )
  })

  it("dagri_plan() remains aligned with the explicit structural helpers", {
    fixture <- dagri_fixture_gated_chain()
    graph <- dagri_recompute_state(fixture$graph)
    plan <- dagri_plan(graph, targets = fixture$targets)

    expect_setequal(plan$targets, dagri_target_closure(graph, fixture$targets))
    expect_setequal(plan$terminal, dagri_terminal(graph, fixture$targets))
    expect_setequal(plan$pending_gates, dagri_pending_gates(graph, fixture$targets))
  })
})

describe("structural fixtures", {
  it("remain plain-data named maps suitable for cross-repo compatibility checks", {
    fixture <- dagri_fixture_branching_graph()
    graph <- fixture$graph

    expect_identical(
      names(graph),
      c("registry", "nodes", "edges", "gates", "version", "metadata")
    )
    expect_setequal(names(graph$nodes), c("n1", "n2", "n3", "n4"))
    expect_setequal(names(graph$edges), c("e1", "e2", "e3"))
    expect_identical(names(graph$gates), character(0))

    expect_true(all(vapply(graph$nodes, is.list, logical(1))))
    expect_true(all(vapply(graph$edges, is.list, logical(1))))
    expect_true(all(vapply(graph$nodes, function(node) is.null(attr(node, "class")), logical(1))))
    expect_true(all(vapply(graph$edges, function(edge) is.null(attr(edge, "class")), logical(1))))
  })
})
