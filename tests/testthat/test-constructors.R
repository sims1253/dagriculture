describe("dagri_kind()", {
  it("creates a valid kind record with correct shape", {
    kind <- dagri_kind(
      name = "data_source",
      output_type = "data.frame",
      param_schema = list(required = c("path"))
    )
    expect_type(kind, "list")
    expect_identical(kind$name, "data_source")
    expect_identical(kind$output_type, "data.frame")
    expect_identical(kind$param_schema, list(required = c("path")))
    expect_identical(
      names(kind),
      c("name", "input_contract", "output_type", "param_schema", "metadata")
    )
  })

  it("accepts a valid input_contract", {
    kind <- dagri_kind(
      name = "source",
      input_contract = list(path = "character", format = "character")
    )
    expect_identical(kind$input_contract, list(path = "character", format = "character"))
  })

  it("accepts NULL input values in input_contract", {
    kind <- dagri_kind(
      name = "source",
      input_contract = list(path = "character", format = NULL)
    )
    expect_null(kind$input_contract$format)
  })

  it("rejects non-list input_contract", {
    expect_error(
      dagri_kind("bad", input_contract = "not a list"),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects unnamed input_contract", {
    expect_error(
      dagri_kind("bad", input_contract = list("a", "b")),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects non-character values in input_contract", {
    expect_error(
      dagri_kind("bad", input_contract = list(path = 123)),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects NA_character_ in input_contract", {
    expect_error(
      dagri_kind("bad", input_contract = list(path = NA_character_)),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects character(0) in input_contract", {
    expect_error(
      dagri_kind("bad", input_contract = list(path = character(0))),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects multi-element character in input_contract", {
    expect_error(
      dagri_kind("bad", input_contract = list(path = c("a", "b"))),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects executable closures in param_schema", {
    expect_error(
      dagri_kind("bad", param_schema = list(fn = function() 1)),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects non-list param_schema", {
    expect_error(
      dagri_kind("bad", param_schema = "not a list"),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects unnamed param_schema", {
    expect_error(
      dagri_kind("bad", param_schema = list("a", "b")),
      class = "dagri_error_invalid_argument"
    )
  })

  it("accepts empty param_schema", {
    kind <- dagri_kind("ok", param_schema = list())
    expect_identical(kind$param_schema, list())
  })

  it("accepts named param_schema", {
    schema <- list(required = c("path"), optional = list())
    kind <- dagri_kind("ok", param_schema = schema)
    expect_identical(kind$param_schema, schema)
  })
})

describe("dagri_registry()", {
  it("creates a registry from kinds", {
    kind1 <- dagri_kind("source")
    kind2 <- dagri_kind("fit")
    reg <- dagri_registry(kind1, kind2)

    expect_type(reg, "list")
    expect_identical(names(reg), c("kinds", "metadata"))
    expect_identical(names(reg$kinds), c("source", "fit"))
  })
})

describe("dagri_graph()", {
  it("creates an empty graph with version 0 and required fields", {
    reg <- dagri_registry(dagri_kind("test"))
    graph <- dagri_graph(reg)

    expect_type(graph, "list")
    expect_identical(graph$version, 0L)
    expect_identical(names(graph$nodes), character(0))
    expect_identical(names(graph$edges), character(0))
    expect_identical(names(graph$gates), character(0))
    expect_identical(names(graph), c("registry", "nodes", "edges", "gates", "version", "metadata"))
  })
})

describe("dagri_validate_graph()", {
  it("accepts a valid graph", {
    reg <- dagri_registry(dagri_kind("test"))
    graph <- dagri_graph(reg)
    expect_invisible(dagri_validate_graph(graph))
  })

  it("rejects a non-list", {
    expect_error(
      dagri_validate_graph("not a graph"),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects a list missing required fields", {
    expect_error(
      dagri_validate_graph(list(nodes = list())),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects a list with invalid version", {
    expect_error(
      dagri_validate_graph(list(
        registry = list(),
        nodes = list(),
        edges = list(),
        gates = list(),
        version = "zero",
        metadata = list()
      )),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects a data.frame", {
    expect_error(
      dagri_validate_graph(data.frame()),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects a list with scalar components", {
    expect_error(
      dagri_validate_graph(list(
        registry = 1,
        nodes = 1,
        edges = 1,
        gates = 1,
        version = 0L,
        metadata = 1
      )),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects a list with NA version", {
    expect_error(
      dagri_validate_graph(list(
        registry = list(),
        nodes = list(),
        edges = list(),
        gates = list(),
        version = NA_integer_
      )),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects an edge whose from references a missing node (dangling edge)", {
    # Hand-constructed graph bypassing dagri_add_edge, mirroring a corrupted
    # deserialized JSON snapshot.
    g <- list(
      registry = list(kinds = list(), metadata = list()),
      nodes = stats::setNames(list(list(id = "n1", kind = "s")), "n1"),
      edges = stats::setNames(list(list(id = "e1", from = "n1", to = "ghost")), "e1"),
      gates = stats::setNames(list(), character(0)),
      version = 0L,
      metadata = list()
    )
    expect_error(
      dagri_validate_graph(g),
      class = "dagri_error_invalid_argument"
    )
    err <- tryCatch(dagri_validate_graph(g), error = function(e) e)
    expect_setequal(err$details$missing_nodes, "ghost")
    expect_identical(err$details$edge_id, "e1")
  })

  it("rejects an edge whose to references a missing node (dangling edge)", {
    g <- list(
      registry = list(kinds = list(), metadata = list()),
      nodes = stats::setNames(list(list(id = "n1", kind = "s")), "n1"),
      edges = stats::setNames(list(list(id = "e1", from = "ghost", to = "n1")), "e1"),
      gates = stats::setNames(list(), character(0)),
      version = 0L,
      metadata = list()
    )
    err <- tryCatch(dagri_validate_graph(g), error = function(e) e)
    expect_s3_class(err, "dagri_error_invalid_argument")
    expect_setequal(err$details$missing_nodes, "ghost")
  })

  it("rejects a gate whose edge_id references a missing edge (dangling gate)", {
    g <- list(
      registry = list(kinds = list(), metadata = list()),
      nodes = stats::setNames(list(list(id = "n1", kind = "s")), "n1"),
      edges = stats::setNames(list(), character(0)),
      gates = stats::setNames(list(list(id = "g1", edge_id = "e_ghost")), "g1"),
      version = 0L,
      metadata = list()
    )
    err <- tryCatch(dagri_validate_graph(g), error = function(e) e)
    expect_s3_class(err, "dagri_error_invalid_argument")
    expect_identical(err$details$missing_edge_id, "e_ghost")
    expect_identical(err$details$gate_id, "g1")
  })

  it("accepts a graph with intact edge -> node and gate -> edge references", {
    g <- list(
      registry = list(kinds = list(), metadata = list()),
      nodes = stats::setNames(
        list(
          list(id = "n1", kind = "s"),
          list(id = "n2", kind = "s")
        ),
        c("n1", "n2")
      ),
      edges = stats::setNames(list(list(id = "e1", from = "n1", to = "n2")), "e1"),
      gates = stats::setNames(list(list(id = "g1", edge_id = "e1")), "g1"),
      version = 0L,
      metadata = list()
    )
    expect_invisible(dagri_validate_graph(g))
  })
})

describe("input_contract enforcement in dagri_add_node()", {
  it("rejects a node missing required contract fields", {
    reg <- dagri_registry(
      dagri_kind("source", input_contract = list(path = "character", format = "character"))
    )
    graph <- dagri_graph(reg)

    expect_error(
      dagri_add_node(graph, "n1", "source", params = list(path = "/tmp")),
      class = "dagri_error_invalid_argument"
    )
  })

  it("accepts a node with all required contract fields", {
    reg <- dagri_registry(
      dagri_kind("source", input_contract = list(path = "character", format = "character"))
    )
    graph <- dagri_graph(reg)

    result <- dagri_add_node(
      graph,
      "n1",
      "source",
      params = list(
        path = "/tmp",
        format = "csv"
      )
    )
    expect_identical(names(result$nodes), "n1")
  })

  it("accepts a node when kind has no input_contract", {
    reg <- dagri_registry(dagri_kind("source"))
    graph <- dagri_graph(reg)

    result <- dagri_add_node(graph, "n1", "source", params = list())
    expect_identical(names(result$nodes), "n1")
  })
})
