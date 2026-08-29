using PerfChecker

_bibinternal_pin(version) = Any[(name = "BibInternal", version = version)]

function bibparser_release_pins()
    pins = Dict{VersionNumber, Vector{Any}}()
    pins[v"0.1.0"] = _bibinternal_pin(v"0.1.0")
    for version in (v"0.1.1", v"0.1.2")
        pins[version] = _bibinternal_pin(v"0.1.2")
    end
    pins[v"0.1.3"] = _bibinternal_pin(v"0.2.0")
    for version in (v"0.1.4", v"0.1.5", v"0.1.6")
        pins[version] = _bibinternal_pin(v"0.2.1")
    end
    pins[v"0.1.7"] = _bibinternal_pin(v"0.2.2")
    pins[v"0.1.8"] = _bibinternal_pin(v"0.2.3")
    for version in (v"0.1.9", v"0.1.10")
        pins[version] = _bibinternal_pin(v"0.2.4")
    end
    for version in (v"0.1.11", v"0.1.12", v"0.1.13", v"0.1.14", v"0.1.15")
        pins[version] = _bibinternal_pin(v"0.2.8")
    end
    for version in (v"0.1.16", v"0.1.17", v"0.1.18", v"0.2.0")
        pins[version] = _bibinternal_pin(v"0.3.0")
    end
    pins[v"0.2.1"] = _bibinternal_pin(v"0.3.3")
    for version in (v"0.2.2", v"0.2.3", v"0.2.4")
        pins[version] = _bibinternal_pin(v"0.3.7")
    end
    pins[v"0.3.0"] = _bibinternal_pin(v"0.4.0")
    return pins
end

function bibparser_perf_suite(;
        source = normpath(joinpath(@__DIR__, "..")),
        bibinternal_source = normpath(joinpath(@__DIR__, "..", "..", "BibInternal")),
        environment = joinpath(@__DIR__, "runner"))
    parsing = FeatureSpec(:parse_bibtex_file;
        description = "Parse a representative BibTeX file",
        backend = :benchmark,
        variants = [
            FeatureVariant(joinpath(@__DIR__, "features", "parse_legacy.jl");
                until = v"0.1.2", comparison_key = "bibtex-file-parse/v1"),
            FeatureVariant(joinpath(@__DIR__, "features", "parse_legacy.jl");
                since = v"0.1.3", until = v"0.1.3",
                comparison_key = "bibtex-file-parse/v1"),
            FeatureVariant(joinpath(@__DIR__, "features", "parse_file.jl");
                since = v"0.1.4", comparison_key = "bibtex-file-parse/v1")],
        options = Dict(:samples => 50, :evals => 1, :seconds => 0.5))
    parsing_allocations = FeatureSpec(:parse_bibtex_file_allocations;
        description = "Attribute BibTeX parsing allocations to source file and line",
        backend = :profile_alloc, variants = parsing.variants,
        options = Dict(:targets => ["BibParser"], :track => "none", :repeat => true))
    parsing_profile = FeatureSpec(:parse_bibtex_file_profile;
        description = "Capture BibTeX parsing CPU call stacks for flame graphs",
        backend = :profile, variants = parsing.variants,
        options = Dict(:targets => ["BibParser"], :track => "none", :repeat => true,
            :profile_seconds => 0.5, :profile_delay => 0.001))
    parsing_wall_profile = FeatureSpec(:parse_bibtex_file_wall_profile;
        description = "Capture BibTeX parsing task wall-time stacks",
        backend = :wall_profile, variants = parsing.variants,
        options = Dict(:targets => ["BibParser"], :track => "none", :repeat => true,
            :profile_seconds => 0.5, :profile_delay => 0.001))
    return PackageSuite("BibParser"; source, environment, versions = :all,
        dev_sources = [bibinternal_source], release_pins = bibparser_release_pins(),
        features = [parsing, parsing_allocations, parsing_profile, parsing_wall_profile])
end
