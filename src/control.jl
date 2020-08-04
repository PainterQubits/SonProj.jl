mutable struct ControlBlock{F<:Frequency} <: Block
    sweeptype::Symbol
    absresolution::Union{Missing, F}
    absresolutioninuse::Union{Missing, Bool}
    computecurrents::Bool
    multifrequencycaching::Bool
    singleprecision::Bool
    boxresonanceinfo::Bool
    deembedding::Bool
    subsperλ::Union{Missing, Int}
    subsperλinuse::Union{Missing, Bool}
    edgecheckinuse::Union{Missing, Bool}
    edgechecklevels::Union{Missing, Int}
    edgechecktechlayers::Union{Missing, Bool}
    maxsubsectionfinuse::Union{Missing, String} #TODO Char
    maxsubsectionf::Union{Missing, F}
    estε::Union{Missing, Float64}
    estεinuse::Union{Missing, Bool}
    filename::Union{Missing, String}
    speed::Int
    cacheabs::Int
    targetabs::Int
    qfactoraccuracy::Bool
    enhancedresonancedetection::Union{Missing, Bool}
    push::Bool
    function ControlBlock{F}() where {F}
        b = new{F}()
        b.sweeptype = :ABS
        b.absresolution = missing
        b.absresolutioninuse = missing
        b.computecurrents = false
        b.multifrequencycaching = false
        b.singleprecision = false
        b.boxresonanceinfo = false
        b.deembedding = true
        b.subsperλ = missing
        b.subsperλinuse = missing
        b.edgecheckinuse = missing
        b.edgechecklevels = missing
        b.edgechecktechlayers = missing
        b.maxsubsectionfinuse = missing
        b.maxsubsectionf = missing
        b.estε = missing
        b.estεinuse = missing
        b.filename = missing
        b.speed = 0
        b.cacheabs = 1
        b.targetabs = 300
        b.qfactoraccuracy = false
        b.enhancedresonancedetection = missing
        b.push = false
        return b
    end
end
ControlBlock(u::DimensionsBlock = DimensionsBlock()) =
    ControlBlock{typeof(1.0*u.frequency)}()

function Base.show(io::IO, b::ControlBlock)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Sonnet control block:")
    println(io, leaf, "  Sweep type:              ", b.sweeptype)
    println(io, leaf, "  ABS resolution in use:   ", b.absresolutioninuse)
    println(io, leaf, "  ABS resolution:          ", b.absresolution)
    println(io, leaf, "  Compute currents:        ", b.computecurrents)
    println(io, leaf, "  Multi-frequency caching: ", b.multifrequencycaching)
    println(io, leaf, "  Single precision:        ", b.singleprecision)
    println(io, leaf, "  Box resonance info:      ", b.boxresonanceinfo)
    println(io, leaf, "  Deembedding:             ", b.deembedding)
    println(io, leaf, "  Subsections / λ in use:  ", b.subsperλinuse)
    println(io, leaf, "  Subsections / λ:         ", b.subsperλ)
    println(io, leaf, "  Edge check in use:       ", b.edgecheckinuse)
    println(io, leaf, "  Edge check levels:       ", b.edgechecklevels)
    println(io, leaf, "  Edge check tech layers:  ", b.edgechecktechlayers)
    println(io, leaf, "  Max subsection f in use: ", b.maxsubsectionfinuse)
    println(io, leaf, "  Max subsection f:        ", b.maxsubsectionf)
    println(io, leaf, "  Estimate ε in use:       ", b.estεinuse)
    println(io, leaf, "  Estimate ε:              ", b.estε)
    # TODO filename
    println(io, leaf, "  Speed:                   ", b.speed)
    println(io, leaf, "  Cache ABS:               ", b.cacheabs)
    println(io, leaf, "  Target ABS:              ", b.targetabs)
    println(io, leaf, "  Q factor accuracy:       ", b.qfactoraccuracy)
    println(io, leaf, "  Enhanced resonance det.: ", b.enhancedresonancedetection)
    println(io, leaf, "  Hierarchy sweep:         ", b.push)
end

function process1(b::ControlBlock, io::IO, u::DimensionsBlock)
    l = sonreadline(io)
    if startswith(l, "END")
        return true
    elseif l in ("SIMPLE", "STD", "ABS", "OPTIMIZE", "VARSWP", "EXTFILE")
        b.sweeptype = Symbol(l)
    elseif startswith(l, "OPTIONS")
        x = split(l)
        opts = length(x) > 1 ? x[2] : ""
        b.deembedding = 'd' in opts
        b.boxresonanceinfo = 'b' in opts
        b.singleprecision = 'm' in opts
        b.computecurrents = 'j' in opts
        b.multifrequencycaching = 'A' in opts
    elseif startswith(l, "SUBSPLAM")
        strs = split(l)[2:end]
        b.subsperλinuse = strs[1] == "Y" ? true : false
        b.subsperλ = parse(Int, strs[2])
    elseif startswith(l, "EDGECHECK")
        strs = split(l)[2:end]
        b.edgecheckinuse = strs[1] == "Y" ? true : false
        b.edgechecklevels = parse(Int, strs[2])
        if length(strs) > 2
            b.edgechecktechlayers = true
        end
    elseif startswith(l, "CFMAX")
        strs = split(l)[2:end]
        b.maxsubsectionfinuse = strs[1]
        if strs[1] == "N" || strs[1] == "L" || strs[1] == "B"
            if length(strs) > 1
                f = tryparse(Float64, strs[2])
                if !isnull(f)
                    b.maxsubsectionf = get(f)*u.frequency
                end
            end
        elseif strs[1] == "Y"
            f = tryparse(Float64, strs[2])
            if !isnull(f)
                b.maxsubsectionf = get(f)*u.frequency
            else
                error("expected input for CFMAX Y ___")
            end
        else
            error("unexpected: CFMAX $(strs[1])")
        end
    elseif startswith(l, "CEPSY")
        strs = split(l)[2:end]
        b.estεinuse = ifelse(strs[1] == "Y", true, false)
        b.estε = parse(Float64, strs[2])
    elseif startswith(l, "FILENAME")
        b.filename = split(l)[2]
    elseif startswith(l, "SPEED")
        b.speed = parse(Int, split(l)[2])
    elseif startswith(l, "PUSH") # hierarchy sweep for netlists
        b.push = true
    elseif startswith(l, "RES_ABS")
        strs = split(l)[2:end]
        b.absresolutioninuse = ifelse(strs[1] == "Y", true, false)
        if length(strs) > 1
            b.absresolution = parse(Float64, strs[2])*u.frequency
        end
    elseif startswith(l, "CACHE_ABS")
        b.cacheabs = parse(Int, split(l)[2])
    elseif startswith(l, "TARG_ABS")
        b.targetabs = parse(Int, split(l)[2])
    elseif startswith(l, "Q_ACC")
        b.qfactoraccuracy = split(l)[2] == "Y" ? true : false
    elseif startswith(l, "DET_ABS_RES")
        b.enhancedresonancedetection = split(l)[2] == "Y" ? true : false
    else
        error("unexpected token: ", l)
    end
    return false
end

function Base.write(io::IO, b::ControlBlock, u=DimensionsBlock())
    println(io, "CONTROL")
    println(io, string(b.sweeptype))
    opstr = "-" *
        ifelse(b.deembedding, 'd', "") *
        ifelse(b.boxresonanceinfo, 'b', "") *
        ifelse(b.singleprecision, 'm', "") *
        ifelse(b.computecurrents, 'j', "") *
        ifelse(b.multifrequencycaching, 'A', "")
    if opstr != "-"
        println(io, "OPTIONS ", opstr)
    else
        println(io, "OPTIONS")
    end
    if !ismissing(b.subsperλinuse) || !ismissing(b.subsperλ)
        println(io, "SUBSPLAM ",
            ifelse(ismissing(b.subsperλinuse), 'N', ifelse(b.subsperλinuse, 'Y', 'N')),
            ' ', ifelse(ismissing(b.subsperλ), 20, b.subsperλ))
    end
    if !ismissing(b.maxsubsectionf)
        println(io, "CFMAX ",
            ifelse(ismissing(b.maxsubsectionfinuse), 'N', ifelse(b.maxsubsectionfinuse, 'Y', 'N')),
            ' ', ustrip(b.maxsubsectionf |> u.frequency))
    end
    if !ismissing(b.estε)
        println(io, "CEPSY ",
            ifelse(ismissing(b.estεinuse), 'N', ifelse(b.estεinuse, 'Y', 'N')),
            ' ', b.estε)
    end
    if b.sweeptype == :FILENAME && !ismissing(b.filename)
        println(io, "FILENAME ", b.filename)
    end
    println(io, "SPEED ", b.speed)
    if !ismissing(b.edgechecklevels)
        print(io, "EDGECHECK ",
            ifelse(ismissing(b.edgecheckinuse), 'N', ifelse(b.edgecheckinuse, 'Y', 'N')),
            ' ', b.edgechecklevels)
        if !ismissing(b.edgechecktechlayers) && b.edgechecktechlayers
            print(io, " TECHLAY")
        end
        println()
    end
    if !ismissing(b.absresolution)
        println(io, "RES_ABS ",
            ifelse(ismissing(b.absresolutioninuse), 'N', ifelse(b.absresolutioninuse, 'Y', 'N')),
            ' ', ustrip(b.absresolution |> u.frequency))
    end
    println(io, "CACHE_ABS ", b.cacheabs)
    println(io, "TARG_ABS ", b.targetabs)
    println(io, "Q_ACC ", ifelse(b.qfactoraccuracy, 'Y', 'N'))
    if !ismissing(b.enhancedresonancedetection)
        println(io, "DET_ABS_RES ", ifelse(b.enhancedresonancedetection, 'Y', 'N'))
    end
    println(io, "END CONTROL")
end
