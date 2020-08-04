mutable struct QSGBlock <: Block
    imprt::Bool
    extrametal::Bool
    units::Bool
    align::Bool
    ref::Bool
    viewres::Bool
    metals::Bool
    used::Bool
    QSGBlock() =
        return new(false, false, false, false, false, false, false, false)
end

function Base.show(io::IO, b::QSGBlock)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Sonnet quick start guide block:")
    println(io, leaf, "  DXF or GDS imported:       ", b.imprt)
    println(io, leaf, "  Extra metal removed:       ", b.extrametal)
    println(io, leaf, "  Units changed:             ", b.units)
    println(io, leaf, "  Aligned to grid:           ", b.align)
    println(io, leaf, "  Reference planes added:    ", b.ref)
    println(io, leaf, "  Viewed response data:      ", b.viewres)
    println(io, leaf, "  Defined new metals:        ", b.metals)
    println(io, leaf, "  Quick start guide enabled: ", b.used)
end

function process1(b::QSGBlock, io::IO)
    l = sonreadline(io)
    if startswith(l, "END")
        return true
    elseif startswith(l, "IMPORT")
        b.imprt = startswith(split(l)[2], "Y")
    elseif startswith(l, "EXTRA_METAL")
        b.extrametal = startswith(split(l)[2], "Y")
    elseif startswith(l, "UNITS")
        b.units = startswith(split(l)[2], "Y")
    elseif startswith(l, "ALIGN")
        b.align = startswith(split(l)[2], "Y")
    elseif startswith(l, "REF")
        b.ref = startswith(split(l)[2], "Y")
    elseif startswith(l, "VIEW_RES")
        b.viewres = startswith(split(l)[2], "Y")
    elseif startswith(l, "METALS")
        b.metals = startswith(split(l)[2], "Y")
    elseif startswith(l, "USED")
        b.used = startswith(split(l)[2], "Y")
    else
        error("unexpected token: ", l)
    end
    return false
end

qsg(x::Bool) = ifelse(x, "YES", "NO")
function Base.write(io::IO, b::QSGBlock)
    println(io, "QSG")
    println(io, "IMPORT ", qsg(b.imprt))
    println(io, "EXTRA_METAL ", qsg(b.extrametal))
    println(io, "UNITS ", qsg(b.units))
    println(io, "ALIGN ", qsg(b.align))
    println(io, "REF ", qsg(b.ref))
    println(io, "VIEW_RES ", qsg(b.viewres))
    println(io, "METALS ", qsg(b.metals))
    println(io, "USED ", qsg(b.used))
    println(io, "END QSG")
end
