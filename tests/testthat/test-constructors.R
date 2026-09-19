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

describe("metadata in constructors", {
  it("round-trips metadata on dagri_kind()", {
    kind <- dagri_kind("source", metadata = list(owner = "team_a", revision = 2))
    expect_identical(kind$metadata, list(owner = "team_a", revision = 2))
  })

  it("round-trips metadata on dagri_registry()", {
    reg <- dagri_registry(dagri_kind("source"), metadata = list(origin = "hand-authored"))
    expect_identical(reg$metadata, list(origin = "hand-authored"))
    expect_identical(names(reg$kinds), "source")
  })

  it("round-trips metadata on dagri_graph()", {
    reg <- dagri_registry(dagri_kind("source"))
    graph <- dagri_graph(reg, metadata = list(project = "pilot"))
    expect_identical(graph$metadata, list(project = "pilot"))
  })

  it("defaults metadata to empty list on all constructors", {
    expect_identical(dagri_kind("source")$metadata, list())
    expect_identical(dagri_registry(dagri_kind("source"))$metadata, list())
    expect_identical(dagri_graph(dagri_registry(dagri_kind("source")))$metadata, list())
  })

  it("accepts empty and nested named metadata", {
    expect_identical(dagri_kind("s", metadata = list())$metadata, list())
    deep <- dagri_kind("s", metadata = list(a = list(b = list(c = 1, d = c("x", "y")))))
    expect_identical(deep$metadata$a$b$c, 1)
  })

  it("rejects non-list metadata", {
    expect_error(
      dagri_kind("bad", metadata = "not a list"),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_registry(dagri_kind("s"), metadata = 42),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_graph(dagri_registry(dagri_kind("s")), metadata = "not a list"),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects data.frame metadata", {
    expect_error(
      dagri_kind("bad", metadata = data.frame(a = 1)),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_graph(dagri_registry(dagri_kind("s")), metadata = data.frame(a = 1)),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects unnamed metadata entries", {
    expect_error(
      dagri_kind("bad", metadata = list("a")),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_registry(dagri_kind("s"), metadata = list(a = 1, "b")),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_graph(dagri_registry(dagri_kind("s")), metadata = list("a")),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects closures in metadata, including nested", {
    expect_error(
      dagri_kind("bad", metadata = list(fn = function(x) x)),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_kind("bad", metadata = list(a = list(b = function() 1))),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_registry(dagri_kind("s"), metadata = list(fn = mean)),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_graph(dagri_registry(dagri_kind("s")), metadata = list(fn = function(x) x)),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects environments in metadata", {
    expect_error(
      dagri_kind("bad", metadata = list(env = new.env())),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_registry(dagri_kind("s"), metadata = list(env = new.env())),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_graph(dagri_registry(dagri_kind("s")), metadata = list(env = new.env())),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects formulas in metadata", {
    expect_error(
      dagri_kind("bad", metadata = list(f = ~x)),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_graph(dagri_registry(dagri_kind("s")), metadata = list(a = list(f = ~x))),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects language objects in metadata (calls, symbols, expressions)", {
    expect_error(
      dagri_kind("bad", metadata = list(expr = quote(x + 1))),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_kind("bad", metadata = list(sym = as.name("x"))),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_registry(dagri_kind("s"), metadata = list(exprs = expression(y ~ z))),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_graph(
        dagri_registry(dagri_kind("s")),
        metadata = list(a = list(b = quote(x + 1)))
      ),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects S4 objects in metadata, including nested", {
    methods::setClass("DagriTestRefBearer", slots = c(env = "environment"))
    on.exit(methods::removeClass("DagriTestRefBearer"), add = TRUE)
    expect_error(
      dagri_kind(
        "bad",
        metadata = list(obj = methods::new("DagriTestRefBearer", env = new.env()))
      ),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_graph(
        dagri_registry(dagri_kind("s")),
        metadata = list(a = list(obj = methods::new("DagriTestRefBearer")))
      ),
      class = "dagri_error_invalid_argument"
    )
  })

  it("rejects weak references in metadata", {
    # Base R 4.6 has no public weakref constructor; rlang (a hard Imports
    # dependency) exposes one internally. If it ever disappears, fall back to
    # exercising the denylist branch directly and skip the end-to-end path.
    wr <- tryCatch(
      getFromNamespace("new_weakref", "rlang")(new.env()),
      error = function(e) NULL
    )
    if (is.null(wr)) {
      skip("no weakref constructor available on this R/rlang")
    }
    expect_identical(typeof(wr), "weakref")
    expect_true(dagriculture:::dagri_has_reference_value(wr))
    expect_error(
      dagri_kind("bad", metadata = list(ref = wr)),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_graph(
        dagri_registry(dagri_kind("s")),
        metadata = list(a = list(ref = wr))
      ),
      class = "dagri_error_invalid_argument"
    )
  })

  it("plain data still passes the reference check", {
    ok <- list(
      a = 1,
      b = c("x", "y"),
      c = list(d = TRUE, e = list(f = 1.5)),
      g = NULL
    )
    expect_false(dagriculture:::dagri_has_reference_value(ok))
  })

  it("reports the failing argument and reason in details", {
    err <- tryCatch(
      dagri_kind("bad", metadata = list(a = ~x)),
      error = function(e) e
    )
    expect_s3_class(err, "dagri_error_invalid_argument")
    expect_identical(err$details$arg, "metadata")
    expect_identical(err$details$reason, "reference_bearing_value")
  })

  it("unnamed-list failures report the unnamed_entries reason", {
    err <- tryCatch(
      dagri_registry(dagri_kind("s"), metadata = list("a")),
      error = function(e) e
    )
    expect_identical(err$details$reason, "unnamed_entries")
  })

  it("non-list failures report the not_a_list reason", {
    err <- tryCatch(
      dagri_graph(dagri_registry(dagri_kind("s")), metadata = "nope"),
      error = function(e) e
    )
    expect_identical(err$details$reason, "not_a_list")
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
