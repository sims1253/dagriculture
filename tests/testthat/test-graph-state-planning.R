describe("graph state and planning", {
  reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))

  # A linear chain: n1 -> n2 -> n3
  # n2 has a pending gate
  g <- dagri_graph(reg) |>
    dagri_add_node("n1", "source") |>
    dagri_add_node("n2", "process") |>
    dagri_add_node("n3", "process") |>
    dagri_add_edge("n1", "n2", id = "e1") |>
    dagri_add_edge("n2", "n3", id = "e2") |>
    dagri_add_gate("e1", id = "gate1")

  describe("dagri_recompute_state()", {
    it("returns a new graph with updated structural state", {
      g_state <- dagri_recompute_state(g)

      # n1 is a root, ready
      expect_identical(dagri_node(g_state, "n1")$state, "ready")

      # n2 is blocked by gate on inbound edge e1
      expect_identical(dagri_node(g_state, "n2")$state, "blocked")
      expect_identical(dagri_node(g_state, "n2")$block_reason, "gate")

      # n3 is blocked upstream (because n2 is blocked)
      expect_identical(dagri_node(g_state, "n3")$state, "blocked")
      expect_identical(dagri_node(g_state, "n3")$block_reason, "upstream_blocked")
    })

    it("identifies structural readiness flows after gate resolution", {
      g_resolved <- dagri_resolve_gate(g, "gate1") |> dagri_recompute_state()

      expect_identical(dagri_node(g_resolved, "n2")$state, "ready")
      expect_identical(dagri_node(g_resolved, "n3")$state, "ready")
    })
  })

  describe("structural accessors", {
    it("dagri_eligible() identifies ready nodes", {
      g_state <- dagri_recompute_state(g)
      expect_setequal(dagri_eligible(g_state), "n1")
    })

    it("dagri_blocked() identifies blocked nodes", {
      g_state <- dagri_recompute_state(g)
      expect_setequal(names(dagri_blocked(g_state)), c("n2", "n3"))
    })

    it("dagri_terminal() identifies terminal targets", {
      g_state <- dagri_recompute_state(g)
      expect_setequal(dagri_terminal(g_state), "n3")
    })
  })

  describe("dagri_plan()", {
    it("returns a compliant dagri_plan structure", {
      g_state <- dagri_recompute_state(g)
      plan <- dagri_plan(g_state, targets = "n3")

      expect_type(plan, "list")
      expect_identical(
        names(plan),
        c(
          "targets",
          "topo_order",
          "eligible",
          "blocked",
          "external_blocked",
          "terminal",
          "pending_gates"
        )
      )

      expect_setequal(plan$targets, c("n1", "n2", "n3"))
      expect_setequal(plan$terminal, "n3")
      expect_setequal(plan$eligible, "n1")

      expect_type(plan$blocked, "list")
      expect_identical(plan$blocked$n2, "gate")
      expect_identical(plan$blocked$n3, "upstream_blocked")
      expect_identical(plan$external_blocked, setNames(list(), character(0)))

      expect_setequal(plan$pending_gates, "gate1")
    })

    it("resolves gate when updated and re-plans", {
      g_resolved <- dagri_resolve_gate(g, "gate1") |> dagri_recompute_state()
      plan <- dagri_plan(g_resolved, targets = "n3")

      expect_identical(plan$blocked, setNames(list(), character(0)))
      expect_identical(plan$external_blocked, setNames(list(), character(0)))
      expect_identical(plan$pending_gates, character(0))
      expect_setequal(plan$eligible, c("n1", "n2", "n3"))
    })

    it("supports planning with a subset of targets", {
      g_state <- dagri_recompute_state(g)
      plan <- dagri_plan(g_state, targets = "n1")

      expect_setequal(plan$targets, "n1")
      expect_setequal(plan$terminal, "n1")
      expect_setequal(plan$eligible, "n1")
      expect_identical(plan$blocked, setNames(list(), character(0)))
      expect_identical(plan$external_blocked, setNames(list(), character(0)))
      expect_identical(plan$pending_gates, character(0))
    })

    it("surfaces a single held node without changing structural eligibility", {
      g_resolved <- dagri_resolve_gate(g, "gate1") |> dagri_recompute_state()
      plan <- dagri_plan(
        g_resolved,
        targets = "n3",
        external_holds = list(n2 = "policy_hold")
      )

      expect_setequal(plan$eligible, c("n1", "n2", "n3"))
      expect_identical(
        plan$external_blocked,
        list(n2 = "policy_hold", n3 = "policy_hold")
      )
      expect_identical(plan$blocked, setNames(list(), character(0)))
    })

    it("propagates external holds through downstream targets", {
      reg_branch <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
      g_branch <- dagri_graph(reg_branch) |>
        dagri_add_node("n1", "source") |>
        dagri_add_node("n2", "process") |>
        dagri_add_node("n3", "process") |>
        dagri_add_node("n4", "process") |>
        dagri_add_edge("n1", "n2", id = "e1") |>
        dagri_add_edge("n2", "n3", id = "e2") |>
        dagri_add_edge("n2", "n4", id = "e3") |>
        dagri_recompute_state()

      plan <- dagri_plan(
        g_branch,
        targets = c("n3", "n4"),
        external_holds = list(n2 = "awaiting_review")
      )

      expect_setequal(plan$targets, c("n1", "n2", "n3", "n4"))
      expect_setequal(plan$eligible, c("n1", "n2", "n3", "n4"))
      expect_identical(
        plan$external_blocked,
        list(
          n2 = "awaiting_review",
          n3 = "awaiting_review",
          n4 = "awaiting_review"
        )
      )
    })

    it("reports structural blocks and external holds side by side", {
      g_state <- dagri_recompute_state(g)
      plan <- dagri_plan(
        g_state,
        targets = "n3",
        external_holds = list(n1 = "manual_pause")
      )

      expect_identical(plan$blocked$n2, "gate")
      expect_identical(plan$blocked$n3, "upstream_blocked")
      expect_identical(
        plan$external_blocked,
        list(n1 = "manual_pause", n2 = "manual_pause", n3 = "manual_pause")
      )
      expect_setequal(plan$eligible, "n1")
    })
  })

  describe("graph validation in state functions", {
    bad_graph <- list(nodes = list())

    it("dagri_recompute_state rejects invalid graph", {
      expect_error(dagri_recompute_state(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_eligible rejects invalid graph", {
      expect_error(dagri_eligible(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_blocked rejects invalid graph", {
      expect_error(dagri_blocked(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_terminal rejects invalid graph", {
      expect_error(dagri_terminal(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_target_closure rejects invalid graph", {
      expect_error(dagri_target_closure(bad_graph, "n1"), class = "dagri_error_invalid_argument")
    })

    it("dagri_pending_gates rejects invalid graph", {
      expect_error(dagri_pending_gates(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_plan rejects invalid graph", {
      expect_error(dagri_plan(bad_graph), class = "dagri_error_invalid_argument")
    })
  })
})
