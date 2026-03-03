describe("groots_kind()", {
  it("creates a valid kind record with correct shape", {
    kind <- groots_kind(
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

  it("rejects executable closures in param_schema", {
    expect_error(
      groots_kind("bad", param_schema = list(fn = function() 1)),
      class = "groots_error_invalid_argument"
    )
  })
})

describe("groots_registry()", {
  it("creates a registry from kinds", {
    kind1 <- groots_kind("source")
    kind2 <- groots_kind("fit")
    reg <- groots_registry(kind1, kind2)

    expect_type(reg, "list")
    expect_identical(names(reg), c("kinds", "metadata"))
    expect_identical(names(reg$kinds), c("source", "fit"))
  })
})

describe("groots_graph()", {
  it("creates an empty graph with version 0 and required fields", {
    reg <- groots_registry(groots_kind("test"))
    graph <- groots_graph(reg)

    expect_type(graph, "list")
    expect_identical(graph$version, 0L)
    expect_identical(names(graph$nodes), character(0))
    expect_identical(names(graph$edges), character(0))
    expect_identical(names(graph$gates), character(0))
    expect_identical(names(graph), c("registry", "nodes", "edges", "gates", "version", "metadata"))
  })
})
