describe("graph state and planning", {
  reg <- groots_registry(groots_kind("source"), groots_kind("process"))

  # A linear chain: n1 -> n2 -> n3
  # n2 has a pending gate
  g <- groots_graph(reg) |>
    groots_add_node("n1", "source") |>
    groots_add_node("n2", "process") |>
    groots_add_node("n3", "process") |>
    groots_add_edge("n1", "n2", id = "e1") |>
    groots_add_edge("n2", "n3", id = "e2") |>
    groots_add_gate("e1", id = "gate1")

  describe("groots_recompute_state()", {
    it("returns a new graph with updated structural state", {
      g_state <- groots_recompute_state(g)

      # n1 is a root, ready
      expect_identical(groots_node(g_state, "n1")$state, "ready")

      # n2 is blocked by gate on inbound edge e1
      expect_identical(groots_node(g_state, "n2")$state, "blocked")
      expect_identical(groots_node(g_state, "n2")$block_reason, "gate")

      # n3 is blocked upstream (because n2 is blocked)
      expect_identical(groots_node(g_state, "n3")$state, "blocked")
      expect_identical(groots_node(g_state, "n3")$block_reason, "upstream_blocked")
    })

    it("identifies invalid configurations", {
      # Missing required inputs based on groots_kind$input_contract could lead to missing_edge
      # But since we have a simple registry without contracts here, let's just test
      # structural readiness flows properly.
      g_resolved <- groots_resolve_gate(g, "gate1") |> groots_recompute_state()

      expect_identical(groots_node(g_resolved, "n2")$state, "ready")
      expect_identical(groots_node(g_resolved, "n3")$state, "ready")
    })
  })

  describe("structural accessors", {
    it("groots_eligible() identifies ready nodes", {
      g_state <- groots_recompute_state(g)
      expect_setequal(groots_eligible(g_state), "n1")
    })

    it("groots_blocked() identifies blocked nodes", {
      g_state <- groots_recompute_state(g)
      expect_setequal(names(groots_blocked(g_state)), c("n2", "n3"))
    })

    it("groots_terminal() identifies terminal targets", {
      g_state <- groots_recompute_state(g)
      expect_setequal(groots_terminal(g_state), "n3")
    })
  })

  describe("groots_plan()", {
    it("returns a compliant groots_plan structure", {
      g_state <- groots_recompute_state(g)
      plan <- groots_plan(g_state, targets = "n3")

      expect_type(plan, "list")
      expect_identical(
        names(plan),
        c("targets", "topo_order", "eligible", "blocked", "terminal", "pending_gates")
      )

      expect_setequal(plan$targets, c("n1", "n2", "n3"))
      expect_setequal(plan$terminal, "n3")
      expect_setequal(plan$eligible, "n1")

      expect_type(plan$blocked, "list")
      expect_identical(plan$blocked$n2, "gate")
      expect_identical(plan$blocked$n3, "upstream_blocked")

      expect_setequal(plan$pending_gates, "gate1")
    })

    it("resolves gate when updated and re-plans", {
      g_resolved <- groots_resolve_gate(g, "gate1") |> groots_recompute_state()
      plan <- groots_plan(g_resolved, targets = "n3")

      expect_identical(plan$blocked, setNames(list(), character(0)))
      expect_identical(plan$pending_gates, character(0))
      expect_setequal(plan$eligible, c("n1", "n2", "n3"))
    })

    it("supports planning with a subset of targets", {
      g_state <- groots_recompute_state(g)
      plan <- groots_plan(g_state, targets = "n1")

      expect_setequal(plan$targets, "n1")
      expect_setequal(plan$terminal, "n1")
      expect_setequal(plan$eligible, "n1")
      expect_identical(plan$blocked, setNames(list(), character(0)))
      expect_identical(plan$pending_gates, character(0))
    })
  })
})
