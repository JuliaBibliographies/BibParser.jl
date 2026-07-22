@testset "Aqua.jl" begin
    # Aqua builds a registry-only wrapper for this check, which cannot resolve
    # BibInternal 0.4 while it is still an unregistered development version.
    # Re-enable persistent_tasks when the 0.4 stack has been registered.
    Aqua.test_all(BibParser; deps_compat = false, persistent_tasks = false)

    @testset "Dependencies compatibility (no extras)" begin
        Aqua.test_deps_compat(BibParser; check_extras = false)
    end
end
