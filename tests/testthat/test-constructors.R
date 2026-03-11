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

  it("rejects executable closures in param_schema", {
    expect_error(
      dagri_kind("bad", param_schema = list(fn = function() 1)),
      class = "dagri_error_invalid_argument"
    )
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
