using BibParser, Dates, JSONSchema, YAML
using Test, TOML, SHA, UUIDs

function _cff_cache_inventory(depot)
    root = joinpath(depot, "compiled")
    Dict(relpath(joinpath(parent, name), root) => bytes2hex(open(
             sha256, joinpath(parent, name)))
    for (parent, _, files) in walkdir(root) for name in files if endswith(name, ".ji"))
end

function _cff_relocation_environment!(origin)
    project = Base.active_project()
    manifest_path = joinpath(dirname(project), "Manifest.toml")
    isfile(manifest_path) ||
        error("CFF relocation tests require an already resolved test Manifest")
    manifest = TOML.parsefile(manifest_path)
    roots = ["BibParser", "Dates", "JSONSchema", "YAML", "Test"]
    selected, pending = Set{String}(), copy(roots)
    while !isempty(pending)
        name = pop!(pending)
        name in selected && continue
        entries = get(manifest["deps"], name, nothing)
        entries isa AbstractVector && length(entries) == 1 ||
            error("Ambiguous or unresolved CFF test dependency")
        push!(selected, name)
        deps = get(only(entries), "deps", String[])
        append!(pending, deps isa AbstractDict ? collect(keys(deps)) : deps)
        # Keep installed weak-dependency identities used by extension metadata.
        # Pruning them can make Julia's precompile graph itself inconsistent.
        weakdeps = get(only(entries), "weakdeps", String[])
        append!(pending,
            filter(dep -> haskey(manifest["deps"], dep),
                weakdeps isa AbstractDict ? collect(keys(weakdeps)) : weakdeps))
    end
    isolated = deepcopy(manifest)
    delete!(isolated, "project_hash")
    filter!(pair -> first(pair) in selected, isolated["deps"])
    environment, depot = joinpath(origin, "environment"), joinpath(origin, "depot")
    mkpath(environment)
    mkpath(depot)
    for name in selected
        entry = only(isolated["deps"][name])
        if name == "BibParser"
            entry["path"] = "../depot/dev/BibParser"
            entry["version"] = TOML.parsefile(joinpath(pkgdir(BibParser), "Project.toml"))["version"]
            delete!(entry, "git-tree-sha1")
            delete!(entry, "registries")
        elseif haskey(entry, "path")
            entry["path"] = abspath(dirname(project), entry["path"])
        elseif haskey(entry, "git-tree-sha1")
            slug = Base.version_slug(UUID(entry["uuid"]), Base.SHA1(entry["git-tree-sha1"]))
            source = findfirst(
                path -> isdir(joinpath(path, "packages", name, slug)), DEPOT_PATH)
            source === nothing && error("Resolved CFF test source is not installed")
            target = joinpath(depot, "packages", name)
            mkpath(target)
            symlink(joinpath(DEPOT_PATH[source], "packages", name, slug),
                joinpath(target, slug))
        end
    end
    # Only source/artifact links are shared. The child's compiled cache starts
    # empty, so an unrelated old BibParser cache cannot prewarm this test.
    artifacts = joinpath(depot, "artifacts")
    mkpath(artifacts)
    for parent in DEPOT_PATH
        directory = joinpath(parent, "artifacts")
        isdir(directory) || continue
        for name in readdir(directory)
            occursin(r"\A[0-9a-f]{40}\z", name) || continue
            target = joinpath(artifacts, name)
            ispath(target) || symlink(joinpath(directory, name), target)
        end
    end
    test_project = Dict("deps" => Dict(name => only(isolated["deps"][name])["uuid"]
    for name in roots))
    open(io -> TOML.print(io, test_project; sorted = true),
        joinpath(environment, "Project.toml"), "w")
    open(io -> TOML.print(io, isolated; sorted = true),
        joinpath(environment, "Manifest.toml"), "w")
    # Julia tags sources under DEPOT_PATH with @depot in the cache header;
    # external absolute development paths are deliberately not relocatable.
    package = joinpath(depot, "dev", "BibParser")
    mkpath(package)
    for name in ("Project.toml", "src", "ext", "examples", "LICENCE")
        cp(joinpath(pkgdir(BibParser), name), joinpath(package, name))
    end
    return (; environment, depot, package)
end

function check_cff_relocation!()
    @testset "CFF schema parsing and runtime resource paths" begin
        cff = Base.get_extension(BibParser, :BibParserCFFExt).CFF
        valid = read(joinpath(pkgdir(BibParser), "examples", "CITATION.cff"), String)
        @test isempty(parse_bibliography(valid; format = :CFF).diagnostics)
        @test only(parse_bibliography(valid; format = :CFF).entries).title ==
              "Software paper"
        for name in ("invalid_yaml.cff", "invalid_version.cff", "invalid_schema.cff")
            input = read(joinpath(pkgdir(BibParser), "examples", name), String)
            document = parse_bibliography(input; format = :CFF)
            @test isempty(document.entries)
            @test !isempty(document.diagnostics)
        end
        @test realpath(cff.module_path()) == realpath(pkgdir(BibParser))
        @test cff.PACKAGE_ROOT isa String
    end
    @testset "CFF uses an existing precompiled cache after relocation" begin
        mktempdir() do root
            origin = mkdir(joinpath(root, "origin"))
            paths = _cff_relocation_environment!(origin)
            precompile = raw"""
                using BibParser, Dates, JSONSchema, YAML, Test
                cff = Base.get_extension(BibParser, :BibParserCFFExt).CFF
                isempty(cff.schemas) || error("Schema was unexpectedly loaded before relocation")
                println("CFF_EXTENSION_PRECOMPILED")
                """
            command = `$(Base.julia_cmd()) --startup-file=no --history-file=no --threads=1 --gcthreads=1 --pkgimages=no --compiled-modules=yes --project=$(paths.environment) -e $precompile`
            environment = [
                "JULIA_DEPOT_PATH" => paths.depot, "JULIA_LOAD_PATH" => "@:@stdlib",
                "JULIA_PKG_OFFLINE" => "true", "JULIA_PKG_SERVER" => "", "JULIA_NUM_PRECOMPILE_TASKS" => "1",
                "JULIA_NUM_THREADS" => "1", "OPENBLAS_NUM_THREADS" => "1", "OMP_NUM_THREADS" => "1"]
            @test occursin(
                "CFF_EXTENSION_PRECOMPILED", read(setenv(command, environment), String))
            cached = _cff_cache_inventory(paths.depot)
            @test any(path -> occursin("BibParserCFFExt", path), keys(cached))
            relocated = joinpath(root, "relocated")
            mv(origin, relocated)
            @test !ispath(origin)
            relocated_depot = joinpath(relocated, "depot")
            @test _cff_cache_inventory(relocated_depot) == cached
            check = raw"""
                using BibParser, Dates, JSONSchema, YAML, Test
                cff = Base.get_extension(BibParser, :BibParserCFFExt).CFF
                @testset "Relocated CFF resource IO" begin
                    @test !ispath(ARGS[1])
                    @test pkgdir(BibParser) == joinpath(ARGS[2], "depot", "dev", "BibParser")
                    @test realpath(cff.PACKAGE_ROOT) == realpath(pkgdir(BibParser))
                    @test isempty(cff.schemas)
                    input = read(joinpath(pkgdir(BibParser), "examples", "CITATION.cff"), String)
                    entry, ok = cff.parse_content(YAML.load(input; dicttype=Dict{String,Any}))
                    @test ok && entry.title == "Software paper"
                    @test haskey(cff.schemas, "1.2.0")
                    @test isempty(parse_bibliography(input; format=:CFF).diagnostics)
                    # The resource read is independent of the compatibility
                    # binding and does not require manually invoking __init__.
                    empty!(cff.schemas)
                    cff.PACKAGE_ROOT = joinpath(ARGS[1], "missing-resource-root")
                    @test isempty(parse_bibliography(input; format=:CFF).diagnostics)
                    @test haskey(cff.schemas, "1.2.0")
                    cff.__init__()
                    @test isempty(cff.schemas)
                    @test realpath(cff.PACKAGE_ROOT) == realpath(pkgdir(BibParser))
                    for name in ("invalid_yaml.cff", "invalid_version.cff", "invalid_schema.cff")
                        document = parse_bibliography(read(joinpath(pkgdir(BibParser), "examples", name), String); format=:CFF)
                        @test isempty(document.entries) && !isempty(document.diagnostics)
                    end
                end
                println("CFF_RELOCATED_PARSING_PASSED")
                """
            # Julia 1.12+ strict mode refuses missing/invalid precompiled caches.
            # Earlier supported Julia versions retain the cache-inventory check.
            compiled_mode = VERSION >= v"1.12" ? "strict" : "yes"
            command = `$(Base.julia_cmd()) --startup-file=no --history-file=no --threads=1 --gcthreads=1 --pkgimages=no --compiled-modules=$compiled_mode --project=$(joinpath(relocated,"environment")) -e $check $origin $relocated`
            environment[1] = "JULIA_DEPOT_PATH" => relocated_depot
            output = read(setenv(command, environment), String)
            print(output)
            @test occursin("CFF_RELOCATED_PARSING_PASSED", output)
            @test _cff_cache_inventory(relocated_depot) == cached
            @test !ispath(origin)
        end
    end
end
