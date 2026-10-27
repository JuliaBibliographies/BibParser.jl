using BibParser
using Test

@testset "BibTeX task dispatch preserves Val methods" begin
    states = (
        :free, :entry, :key, :field_name, :field_in, :field_inbrace,
        :field_inquote, :field_outquote, :field_concat, :field_var,
        :field_number, :field_out, :field_next, :special, :string,
        :string_inquote, :string_value, :string_outquote
    )
    characters = ('@', '{', '}', '(', ')', '"', ',', '#', '=', '7', 'q', '\n', ' ', 'é')
    for state in states, char in characters, braces in 0:2, delim in ('{', '(')
        parser = BibParser.BibTeX.Parser(""; task = state)
        parser.field.braces = braces
        parser.storage.delim = delim
        reference = deepcopy(parser)

        # The unchanged three-argument methods are the semantic reference,
        # including brace-counter changes in nested fields and special blocks.
        expected = BibParser.BibTeX.is_dumped(reference, char, Val(state))
        actual = BibParser.BibTeX.is_dumped(parser, char)
        @test (actual, parser.field.braces, parser.task) ===
              (expected, reference.field.braces, reference.task)
    end

    @testset "Unknown tasks retain the original dispatch failure" begin
        parser = BibParser.BibTeX.Parser(""; task = :task_dispatch_unknown)
        reference = deepcopy(parser)
        expected = try
            BibParser.BibTeX.is_dumped(reference, '@', Val(reference.task))
        catch exception
            exception
        end
        actual = try
            BibParser.BibTeX.is_dumped(parser, '@')
        catch exception
            exception
        end
        @test expected isa MethodError
        @test actual isa MethodError
        if expected isa MethodError && actual isa MethodError
            @test actual.f === expected.f === BibParser.BibTeX.is_dumped
            @test actual.args[1] === parser
            @test expected.args[1] === reference
            @test actual.args[2:end] === expected.args[2:end]
        end
        @test parser.task === reference.task === :task_dispatch_unknown
        @test parser.field.braces == reference.field.braces == 0
    end
end
