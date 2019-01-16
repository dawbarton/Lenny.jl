using Documenter, Lenny

makedocs(
    modules = [Lenny],
    format = :html,
    checkdocs = :exports,
    sitename = "Lenny.jl",
    pages = Any["index.md"]
)

deploydocs(
    repo = "github.com/dawbarton/Lenny.jl.git",
)
