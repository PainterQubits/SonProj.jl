abstract type Sweep end
abstract type UnderspecifiableSweep{N} <: Sweep end

function (::Type{S})() where {N, S<:UnderspecifiableSweep{N}}
    return S{typeof(1.0GHz)}(ntuple(x->NaN*GHz, N)...)
end
function (::Type{S})(x::T) where {N, S<:UnderspecifiableSweep{N}, T}
    return S{T}(x, ntuple(x->T(NaN), N-1)...)
end
function (::Type{S})(x::T, y::T) where {S<:UnderspecifiableSweep{3}, T}
    return S{T}(x, y, T(NaN))
end
(::Type{S})(x, y) where {S<:UnderspecifiableSweep} = S(promote(x,y)...)

struct ABSSweep{T} <: UnderspecifiableSweep{2}
    start::T
    stop::T
end
function Base.show(io::IO, s::ABSSweep)
    print(io, "ABS sweep: ", s.start)
    if !isnan(s.stop)
        print(io, " to ", s.stop)
    end
end

struct ABSEntrySweep{T} <: UnderspecifiableSweep{2}    # used in optimization block
    start::T
    stop::T
end

struct SimpleSweep{T} <: UnderspecifiableSweep{3}
    start::T
    stop::T
    step::T
end
struct StepRangeSweep{T} <: Sweep
    start::T
    stop::T
    step::T
end
function Base.show(io::IO, s::Union{SimpleSweep,StepRangeSweep})
    if s isa SimpleSweep
        print(io, "Simple sweep: ", s.start)
    else
        print(io, "StepRange sweep: ", s.start)
    end
    if !isnan(s.stop)
        print(io, " to ", s.stop)
        if !isnan(s.step)
            print(io, ", step by ", s.step)
        end
    end
end

struct ExponentialSweep{T} <: Sweep
    start::T
    stop::T
    nf::Int
end
function Base.write(io::IO, s::ExponentialSweep, u=DimensionsBlock())
    println(io, string("ESWEEP ", ustrip(s.start |> u.frequency), " ",
        ustrip(s.stop |> u.frequency), " ", s.nf))
end
struct LinSpaceSweep{T} <: Sweep
    start::T
    stop::T
    nf::Int
end
function Base.write(io::IO, s::LinSpaceSweep, u=DimensionsBlock())
    println(io, string("FSWEEP ", ustrip(s.start |> u.frequency), " ",
        ustrip(s.stop |> u.frequency), " ", s.nf))
end
function Base.show(io::IO, s::Union{LinSpaceSweep,ExponentialSweep})
    if s isa LinSpaceSweep
        print(io, "LinSpace sweep: ", s.start)
    else
        print(io, "Exponential sweep: ", s.start)
    end
    if !isnan(s.stop)
        print(io, " to ", s.stop)
        if !isnan(s.nf)
            print(io, ", points: ", s.nf)
        end
    end
end

struct List{T} <: Sweep
    list::Vector{T}
end
function Base.show(io::IO, s::List)
    print(io, "List sweep: ")
    show(IOContext(io, compact=true), s.list)
end

struct Discrete{T} <: Sweep
    f::T
end
Base.show(io::IO, s::Discrete) = print(io, "Discrete sweep: ", s.f)

struct DC <: Sweep
    auto::Bool
    f::typeof(1.0u"kHz")
end
Base.write(io::IO, s::DC) = println(io, "DC_FREQ " * (s.auto ? "AUTO" : (
    "MAN $(ustrip(s.f))")))

struct CornerSweep{T} <: Sweep
    start::T
    stop::T
end

struct SensitivitySweep{T} <: Sweep
    start::T
    stop::T
end

mutable struct FrequencyBlock <: Block
    sweeps::Vector{Sweep}
    FrequencyBlock() = new(Sweep[])
end

function Base.show(io::IO, b::FrequencyBlock)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Sonnet frequency block:")
    for sw in b.sweeps
        print(io, leaf, "  ")
        show(io, sw)
        println(io)
    end
end

function process1(b::FrequencyBlock, io::IO, u::DimensionsBlock)
    l = sonreadline(io)
    if startswith(l, "END")
        return true
    elseif startswith(l, "ABS_FMIN")
        error("not yet supported: ABS_FMIN")
        # push!(b.sweeps, ABS_Fmin())
    elseif startswith(l, "ABS_FMAX")
        error("not yet supported: ABS_FMAX")
        # push!(b.sweeps, ABS_Fmax())
    end

    push!(b.sweeps, parsesweep(l, u))
    return false
end

function parsesweep(l, u=DimensionsBlock())
    x = tryparse.(Float64, split(l)[2:end])
    if !any(isnull.(x))
        args = get.(x)
        if startswith(l, "SIMPLE")
            return SimpleSweep(args.*u.frequency...)
        elseif startswith(l, "SWEEP")
            return StepRangeSweep(args.*u.frequency...)
        elseif startswith(l, "ABS_ENTRY")
            return ABSEntrySweep(args.*u.frequency...)
        elseif startswith(l, "ABS")
            return ABSSweep(args.*u.frequency...)
        elseif startswith(l, "ESWEEP")
            return ExponentialSweep(args[1:(end-1)].*u.frequency..., Int(args[end]))
        elseif startswith(l, "LSWEEP")
            return LinSpaceSweep(args[1:(end-1)].*u.frequency..., Int(args[end]))
        elseif startswith(l, "DC_FREQ")
            return DC(args...)
        elseif startswith(l, "LIST")
            return List(args.*u.frequency)
        elseif startswith(l, "STEP")
            return Discrete(args.*u.frequency...)
        else
            error("unexpected token: ", l)
        end
    else
        error("unexpected sweep arguments.")
    end
end

function Base.write(io::IO, b::FrequencyBlock, u=DimensionsBlock())
    println(io, "FREQ")
    for sweep in b.sweeps
        write(io, sweep, u)
    end
    println(io, "END FREQ")
end

function Base.write(io::IO, s::Sweep, u=DimensionsBlock())
    tag = if s isa ABSSweep
        "ABS"
    elseif s isa ABSEntrySweep
        "ABS_ENTRY"
    elseif s isa SimpleSweep
        "SIMPLE"
    elseif s isa StepRangeSweep
        "SWEEP"
    elseif s isa List
        "LIST"
    elseif s isa Discrete
        "STEP"
    else
        error("unexpected sweep: ", s)
    end
    nums = [ustrip(getfield(s, x) |> u.frequency) for x in fieldnames(s)]
    strs = (x->isnan(x)? "UNDEF" : string(x)).(nums)
    for i in length(strs):-1:1
        if strs[i] == "UNDEF"
            pop!(strs)
        else break end
    end
    println(io, string(tag, " ", join(strs, " ")))
end
