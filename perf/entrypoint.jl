using PerfChecker

include("suite.jl")

function build_suite()
    source = get(ENV, "BIBPARSER_PATH", normpath(joinpath(@__DIR__, "..")))
    internal = get(ENV, "BIBINTERNAL_PATH",
        normpath(joinpath(@__DIR__, "..", "..", "BibInternal")))
    package = bibparser_perf_suite(; source, bibinternal_source = internal,
        environment = joinpath(source, "perf", "runner"))
    return SoftwareSuite(:bibparser, [package];
        description = "Public performance surface of BibParser")
end
