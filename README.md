[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaBibliographies.github.io/BibParser.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaBibliographies.github.io/BibParser.jl/dev)
[![Build Status](https://github.com/JuliaBibliographies/BibParser.jl/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/JuliaBibliographies/BibParser.jl/actions/workflows/ci.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/JuliaBibliographies/BibParser.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaBibliographies/BibParser.jl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# BibParser.jl

BibParser is the import layer of the bibliography stack.

It reads bibliographic source formats and projects them into
`BibInternal.Entry` or lossless `BibInternal.BibliographyDocument` values.
The supported formats are BibTeX, BibLaTeX, RIS, CFF 1.2, CSL-JSON, EndNote
XML, and MODS 3.x.

This package is usually used through `Bibliography.jl`, which provides the
high-level import/export API. Using `BibParser.jl` directly is still useful when
you want to parse a format without writing it back immediately.

The output of an example parsing a BibTeX file can be found at [baffier.fr/publications.html](https://baffier.fr/publications.html).

BibTeX, BibLaTeX, and RIS are available in the core package. Formats backed by
external parsing libraries are package extensions:

- load `YAML` and `JSONSchema` to enable CFF;
- load `JSON3` to enable CSL-JSON;
- load `EzXML` to enable EndNote XML and MODS.

Lossless parsing is available for the supported formats whenever the backend
can preserve the raw source structure.

For example:

```julia
using BibParser, JSON3
document = parse_bibliography(read("references.json", String); format = :CSL)
```

### BibTeX and BibLaTeX

A new parser is in use since `v0.1.12`. It preserves entries, string macros,
preambles, comments, and free text in the lossless document model. Remaining
transformations outside the parser grammar are:

- Applying the LaTeX commands from `@preamble`s entries to other entries
- Optional transformation of Unicode <-> LaTeX characters

### CFF

The CFF importer validates version 1.2 documents against the bundled official
JSON Schema before projecting their metadata.
