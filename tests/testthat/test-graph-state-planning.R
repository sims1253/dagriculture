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
          "pending_gates",
          "node_status"
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

    it("derives state internally, independent of stored state", {
      plan_recomputed <- dagri_plan(dagri_recompute_state(g), targets = "n3")
      plan_never <- dagri_plan(g, targets = "n3")

      expect_identical(plan_never$eligible, plan_recomputed$eligible)
      expect_identical(plan_never$blocked, plan_recomputed$blocked)
      expect_identical(plan_never$external_blocked, plan_recomputed$external_blocked)
      expect_identical(plan_never$pending_gates, plan_recomputed$pending_gates)
      expect_identical(plan_never$targets, plan_recomputed$targets)
      expect_identical(plan_never$terminal, plan_recomputed$terminal)
    })

    it("does not mutate the input graph value", {
      g_before <- g
      plan <- dagri_plan(g, targets = "n3")

      expect_identical(g, g_before)
      expect_setequal(
        vapply(g$nodes, function(n) n$state, character(1)),
        rep("new", length(g$nodes))
      )
    })
  })

  describe("dagri_plan() node_status", {
    it("reports per-node state, block reason, gates, and blockers on the gated chain", {
      fixture <- dagri_fixture_gated_chain()
      plan <- dagri_plan(fixture$graph, targets = fixture$targets)

      # Covers exactly the target closure, in the plan's topo order.
      expect_identical(names(plan$node_status), plan$topo_order)

      expect_identical(
        plan$node_status$n1,
        list(
          state = "ready",
          block_reason = "none",
          pending_gates = character(0),
          external_hold = NULL,
          upstream_blockers = character(0),
          eligible = TRUE
        )
      )
      expect_identical(
        plan$node_status$n2,
        list(
          state = "blocked",
          block_reason = "gate",
          pending_gates = "gate1",
          external_hold = NULL,
          upstream_blockers = character(0),
          eligible = FALSE
        )
      )
      expect_identical(
        plan$node_status$n3,
        list(
          state = "blocked",
          block_reason = "upstream_blocked",
          pending_gates = character(0),
          external_hold = NULL,
          upstream_blockers = "n2",
          eligible = FALSE
        )
      )
    })

    it("keeps eligible TRUE on an externally held root (overlap preserved)", {
      fixture <- dagri_fixture_gated_chain()
      g_resolved <- dagri_resolve_gate(fixture$graph, fixture$gate_id)
      plan <- dagri_plan(
        g_resolved,
        targets = fixture$targets,
        external_holds = list(n1 = "manual_pause")
      )

      # n1 is structurally eligible AND externally held at the same time.
      expect_identical(plan$node_status$n1$eligible, TRUE)
      expect_identical(plan$node_status$n1$state, "ready")
      expect_identical(plan$node_status$n1$external_hold, "manual_pause")

      # The hold propagates downstream without touching structural fields.
      expect_identical(plan$node_status$n2$external_hold, "manual_pause")
      expect_identical(plan$node_status$n2$state, "ready")
      expect_identical(plan$node_status$n2$eligible, TRUE)
      expect_identical(plan$node_status$n3$external_hold, "manual_pause")
      expect_identical(plan$node_status$n3$eligible, TRUE)
    })

    it("propagates external holds into node_status on a branching graph", {
      fixture <- dagri_fixture_branching_graph()
      plan <- dagri_plan(
        fixture$graph,
        targets = fixture$targets,
        external_holds = list(n2 = "awaiting_review")
      )

      expect_null(plan$node_status$n1$external_hold)
      expect_identical(plan$node_status$n2$external_hold, "awaiting_review")
      expect_identical(plan$node_status$n2$eligible, TRUE)
      expect_identical(plan$node_status$n3$external_hold, "awaiting_review")
      expect_identical(plan$node_status$n4$external_hold, "awaiting_review")
      expect_true(all(vapply(plan$node_status, function(s) isTRUE(s$eligible), logical(1))))
    })

    it("pins the request-order closure of targets on a branching graph", {
      fixture <- dagri_fixture_branching_graph()
      plan <- dagri_plan(fixture$graph, targets = c("n3", "n4"))

      # Pins the request-order closure documented in api-contracts.md: each
      # requested target followed by its ancestors, shared ancestors not
      # repeated. Deliberately exact (not expect_setequal) so reordering
      # plan$targets fails here.
      expect_identical(plan$targets, c("n3", "n2", "n1", "n4"))
    })

    it("mirrors the aggregate eligible, blocked, and external_blocked fields", {
      plan <- dagri_plan(
        g,
        targets = "n3",
        external_holds = list(n1 = "manual_pause")
      )

      eligible_from_status <- names(plan$node_status)[
        vapply(plan$node_status, function(s) isTRUE(s$eligible), logical(1))
      ]
      expect_setequal(eligible_from_status, plan$eligible)

      blocked_from_status <- lapply(
        Filter(function(s) identical(s$state, "blocked"), plan$node_status),
        function(s) s$block_reason
      )
      expect_setequal(names(blocked_from_status), names(plan$blocked))
      expect_identical(blocked_from_status[names(plan$blocked)], plan$blocked)

      held_from_status <- lapply(
        Filter(function(s) !is.null(s$external_hold), plan$node_status),
        function(s) s$external_hold
      )
      expect_identical(held_from_status, plan$external_blocked)
    })

    it("orders multiple pending gates by edge insertion, then gate insertion", {
      g_multi <- dagri_graph(reg) |>
        dagri_add_node("n1", "source") |>
        dagri_add_node("n2", "process") |>
        dagri_add_node("n3", "process") |>
        dagri_add_node("n4", "process") |>
        dagri_add_edge("n1", "n4", id = "e1") |>
        dagri_add_edge("n2", "n4", id = "e2") |>
        dagri_add_edge("n3", "n4", id = "e3") |>
        dagri_add_gate("e2", id = "g2b") |>
        dagri_add_gate("e2", id = "g2a") |>
        dagri_add_gate("e1", id = "g1")

      plan <- dagri_plan(g_multi, targets = "n4")

      # Inbound edges of n4 in insertion order are e1, e2, e3: e1's gate lists
      # first even though g1 was added last, and within e2, g2b precedes g2a
      # by gate insertion order (not lexicographic order).
      expect_identical(plan$node_status$n4$pending_gates, c("g1", "g2b", "g2a"))
      expect_identical(plan$node_status$n4$block_reason, "gate")
      expect_identical(plan$node_status$n4$upstream_blockers, character(0))

      # The plan-level field keeps its own convention (gate insertion order).
      expect_identical(plan$pending_gates, c("g2b", "g2a", "g1"))
    })

    it("lists multiple upstream blockers in incoming-edge insertion order", {
      g_multi <- dagri_graph(reg) |>
        dagri_add_node("s1", "source") |>
        dagri_add_node("s2", "source") |>
        dagri_add_node("m1", "process") |>
        dagri_add_node("m2", "process") |>
        dagri_add_node("t", "process") |>
        dagri_add_edge("s2", "m2", id = "e_s2m2") |>
        dagri_add_gate("e_s2m2", id = "gm2") |>
        dagri_add_edge("s1", "t", id = "e_s1t") |>
        dagri_add_edge("s2", "m1", id = "e_s2m1") |>
        dagri_add_gate("e_s2m1", id = "gm1") |>
        dagri_add_edge("m2", "t", id = "e_m2t") |>
        dagri_add_edge("m1", "t", id = "e_m1t")

      plan <- dagri_plan(g_multi, targets = "t")

      # Incoming edges of t were inserted as e_s1t (from s1), e_m2t (from m2),
      # e_m1t (from m1): blocked m2 lists before blocked m1 despite
      # lexicographic order, ready s1 stays out, and the adjacency index keeps
      # upstream neighbors unique.
      expect_identical(plan$node_status$t$upstream_blockers, c("m2", "m1"))
      expect_identical(plan$node_status$t$block_reason, "upstream_blocked")
      expect_identical(plan$node_status$t$state, "blocked")
      expect_identical(plan$node_status$t$pending_gates, character(0))
    })

    it("still lists a node's own pending gates when the upstream verdict wins", {
      g_chain <- dagri_graph(reg) |>
        dagri_add_node("n1", "source") |>
        dagri_add_node("n2", "process") |>
        dagri_add_node("n3", "process") |>
        dagri_add_edge("n1", "n2", id = "e1") |>
        dagri_add_gate("e1", id = "gA") |>
        dagri_add_edge("n2", "n3", id = "e2") |>
        dagri_add_gate("e2", id = "gB")

      plan <- dagri_plan(g_chain, targets = "n3")

      expect_identical(plan$node_status$n3$state, "blocked")
      expect_identical(plan$node_status$n3$block_reason, "upstream_blocked")
      expect_identical(plan$node_status$n3$upstream_blockers, "n2")
      expect_identical(plan$node_status$n3$pending_gates, "gB")
    })

    it("scopes node_status to the target closure and its topo order", {
      plan <- dagri_plan(g, targets = "n1")

      expect_identical(names(plan$node_status), plan$topo_order)
      expect_identical(names(plan$node_status), "n1")
      expect_false("n2" %in% names(plan$node_status))
      expect_identical(plan$node_status$n1$eligible, TRUE)
    })

    it("returns an empty named list for an empty target closure", {
      plan <- dagri_plan(dagri_graph(reg))

      expect_identical(plan$node_status, setNames(list(), character(0)))
    })
  })

  # These validation tests assert the error behavior of the unexported
  # helpers dagri_target_closure and dagri_pending_gates directly, which
  # requires reaching into the package namespace via `:::`.
  # jarl-ignore internal_function: tests unexported helpers via `:::`
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
      expect_error(
        dagriculture:::dagri_target_closure(bad_graph, "n1"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_pending_gates rejects invalid graph", {
      expect_error(
        dagriculture:::dagri_pending_gates(bad_graph),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_plan rejects invalid graph", {
      expect_error(dagri_plan(bad_graph), class = "dagri_error_invalid_argument")
    })
  })
})
