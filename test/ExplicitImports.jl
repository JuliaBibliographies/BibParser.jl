@testset "Look for Explicit Imports" begin
    # Some extension submodules are not statically analyzable on Julia 1.10.
    allow_modules = Module[]
    for (ext_name, submodules) in ((:BibParserXMLExt, (:XMLFormats,)),
        (:BibParserCFFExt, (:CFF,)),
        (:BibParserCSLExt, (:CSL,)))
        ext = Base.get_extension(BibParser, ext_name)
        ext === nothing && continue
        push!(allow_modules, ext)
        for submod in submodules
            isdefined(ext, submod) || continue
            push!(allow_modules, getfield(ext, submod))
        end
    end
    allow_unanalyzable = Tuple(allow_modules)

    @test check_no_implicit_imports(
        BibParser; allow_unanalyzable = allow_unanalyzable) === nothing
end
