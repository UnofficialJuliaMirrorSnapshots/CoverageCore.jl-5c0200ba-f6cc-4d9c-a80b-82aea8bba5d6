# generates a lcov.info file in the format generated by `geninfo`. This format
# can be parsed by a variety of useful utilities to display coverage info

export LCOV
"""
CoverageCore.LCOV Module

This module provides functionality to generate LCOV info format files from
Julia coverage data. It exports the `writefile` function.
"""
module LCOV

using CoverageCore
using CoverageCore: CovCount

export writefile, readfile

"""
    writefile(outfile::AbstractString, fcs)

Write the given coverage data to a file in LCOV info format. The data can either
be a `FileCoverage` instance or a vector of `FileCoverage` instances.
"""
function writefile(outfile::AbstractString, fcs)
    open(outfile, "w") do f
        write(f, fcs)
        nothing
    end
    nothing
end

"""
    write(io::IO, fcs)

Write the given coverage data to an `IO` stream in LCOV info format. The data
can either be a `FileCoverage` instance or a vector of `FileCoverage` instances.
"""
function write end

function write(io::IO, fcs::Vector{FileCoverage})
    for fc in fcs
        write(io, fc)
    end
end

function write(io::IO, fc::FileCoverage)
    instrumented = 0
    covered = 0
    println(io, "SF:$(fc.filename)")
    for (line, cov) in enumerate(fc.coverage)
        (lineinst, linecov) = writeline(io, line, cov)
        instrumented += lineinst
        covered += linecov > 0 ? 1 : 0
    end
    println(io, "LH:$covered")
    println(io, "LF:$instrumented")
    println(io, "end_of_record")
end

# document the writeline function instead of individual methods
"""
    writeline(io::IO, line::Int, count)

Write LCOV data for a single line to the given `IO` stream. Returns a 2-tuple
of the number of lines instrumented (0 or 1) and the count for how many times
the line was executed during testing.
"""
function writeline end

function writeline(io::IO, line::Int, count::Int)
    println(io, "DA:$line,$count")
    (1, count)
end
function writeline(io::IO, line::Int, count::Nothing)
    # skipped line, nothing to do here
    (0, 0)
end


"""
    readfile(infofile::AbstractString) -> Vector{FileCoverage}

Read coverage data from a file in LCOV info format.
"""
function readfile(infofile::AbstractString)
    source_files = FileCoverage[]
    coverage = nothing
    for line in eachline(infofile)
        if startswith(line, "end_of_record")
            coverage = nothing
        elseif (m = match(r"^SF:(.+)", line)) !== nothing
            sf = String(m[1])
            coverage = FileCoverage(sf, "", CovCount[])
            push!(source_files, coverage)
        elseif (m = match(r"^DA:(\d+),(-?\d+)(,[^,\s]+)?", line)) !== nothing
            if coverage !== nothing
                ln = parse(Int, m[1])
                da = parse(Int, m[2])
                cv = coverage.coverage
                lc = length(cv)
                if ln > 0
                    if lc < ln
                        resize!(cv, ln)
                        cv[(lc + 1):ln] .= nothing
                    end
                    cv[ln] = something(cv[ln], 0) + da
                end
            end
        end
        nothing
    end
    return source_files
end

"""
    readfolder(folder) -> Vector{FileCoverage}

Process the contents of a folder of LCOV files to collect coverage statistics.
Will recursively traverse child folders.
Post-process with `merge_coverage_counts(coverages)` to combine duplicates.
"""
function readfolder(folder)
    @info """CoverageCore.LCOV.readfolder: Searching $folder for .info files..."""
    source_files = FileCoverage[]
    files = readdir(folder)
    for file in files
        fullfile = joinpath(folder, file)
        if isfile(fullfile)
            # Is it a tracefile?
            if endswith(fullfile, ".info")
                append!(source_files, readfile(fullfile))
            else
                @debug "CoverageCore.LCOV.readfolder: Skipping $file, not a .info file"
            end
        elseif isdir(fullfile)
            # If it is a folder, recursively traverse
            append!(source_files, readfolder(fullfile))
        end
    end
    return source_files
end

end
