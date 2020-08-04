import Devices
const Point = Devices.Points.Point

@enum SnapAngle ∠90° ∠45° ∠30° ∠22_5° ∠5°
@enum Side left right top bottom
function Base.parse(::Type{Side}, s::AbstractString)
    return if s == "T"
        top
    elseif s == "B"
        bottom
    elseif s == "R"
        right
    else
        left
    end
end

abstract type MetalModel end
abstract type PlanarMetalModel <: MetalModel end
abstract type ViaMetalModel <: MetalModel end

function lossfactor(l, u, dir=true)
    return if l isa ElectricalConductivity
        ustrip(uconvert(u.conductivity, l)), (dir ? "" : " CDVY")
    elseif l isa ElectricalResistivity
        ustrip(uconvert(u.resistivity, l)), " RSVY"
    else
        if Unitful.name(typeof(unit(l)).parameters[1][1]) == :OhmsPerSquare
            ustrip(uconvert(u.sheetresistance, l)), " SRVY"
        else
            ustrip(uconvert(u.resistance, l)), " RPV"
        end
    end
end

struct DefaultPlanarModel <: PlanarMetalModel end
Base.write(io::IO, ::DefaultPlanarModel) = println(io, "SUP 0 0 0 0")
Base.show(io::IO, ::DefaultPlanarModel) = print(io, "Default planar metal")

struct WaveguideLoadModel <: PlanarMetalModel end
Base.write(io::IO, ::WaveguideLoadModel) = println(io, "WGLOAD")
Base.show(io::IO, ::WaveguideLoadModel) = print(io, "Waveguide load")

struct FreeSpaceModel <: PlanarMetalModel end
Base.write(io::IO, ::FreeSpaceModel) = println(io, "FREESPACE 376.7303136 0 0 0")
Base.show(io::IO, ::FreeSpaceModel) = print(io, "Free space")

mutable struct NormalMetalModel <: PlanarMetalModel
    lossfactor::LossFactor
    currentratio::SReal{Float64}
    thickness::Length
end
function Base.write(io::IO, m::NormalMetalModel, u=DimensionsBlock())
    lf, su = lossfactor(m.lossfactor, u)
    le = ustrip(uconvert(u.length, m.thickness))
    println(IOContext(io, son=true),
        "NOR ", lf, " ", m.currentratio, " ", le, su)
end
function Base.show(io::IO, m::NormalMetalModel)
    leaf = get(io, :leaf, "")
    println(io, leaf, "Normal metal model:")
    println(io, leaf, "  Loss factor:   ", m.lossfactor)
    println(io, leaf, "  Current ratio: ", m.currentratio)
    print(io, leaf,   "  Thickness:     ", m.thickness)
end

mutable struct ResistorModel <: PlanarMetalModel
    rdc::SheetResistance
end
Base.write(io::IO, m::ResistorModel, u=DimensionsBlock()) =
    println(IOContext(io, son=true), "RES ",
        ustrip(uconvert(u.sheetresistance, m.rdc)))
function Base.show(io::IO, m::ResistorModel)
    leaf = get(io, :leaf, "")
    println(io, leaf, "Resistor model: ")
    print(io, leaf,   "  DC resistance: ", m.rdc)
end

mutable struct NativeModel <: PlanarMetalModel
    rdc::SheetResistance
    rrf::SReal{Float64}
end
Base.write(io::IO, m::NativeModel, u=DimensionsBlock()) =
    println(IOContext(io, son=true), "NAT ",
        ustrip(uconvert(u.sheetresistance, m.rdc)), " ", m.rrf)
function Base.show(io::IO, m::NativeModel)
    leaf = get(io, :leaf, "")
    println(io, leaf, "Native model: ")
    println(io, leaf, "  DC resistance:           ", m.rdc)
    print(io, leaf,   "  Skin effect coefficient: ", m.rrf)
end

mutable struct GeneralModel <: PlanarMetalModel
    rdc::SheetResistance
    rrf::SReal{Float64}
    xdc::SheetResistance
    ls::SheetInductance
end
Base.write(io::IO, m::GeneralModel, u=DimensionsBlock()) =
    println(IOContext(io, son=true), "SUP ",
        ustrip(uconvert(u.sheetresistance, m.rdc)), " ", m.rrf, " ",
        ustrip(uconvert(u.sheetresistance, m.xdc)), " ",
        ustrip(uconvert(u.inductance / □, m.ls)))
function Base.show(io::IO, m::GeneralModel)
    leaf = get(io, :leaf, "")
    println(io, leaf, "General model:")
    println(io, leaf, "  DC resistance:           ", m.rdc)
    println(io, leaf, "  Skin effect coefficient: ", m.rrf)
    println(io, leaf, "  DC reactance:            ", m.xdc)
    print(io, leaf,   "  Kinetic inductance:      ", m.ls)
end

mutable struct SenseModel <: PlanarMetalModel
    xdc::SheetResistance
end
Base.write(io::IO, m::SenseModel, u=DimensionsBlock()) =
    println(IOContext(io, son=true), "SEN ",
        ustrip(uconvert(u.sheetresistance, m.xdc)))
function Base.show(io::IO, m::SenseModel)
    leaf = get(io, :leaf, "")
    println(io, leaf, "Sense model: ")
    print(io, leaf,   "  DC reactance: ", m.xdc)
end

mutable struct ThickMetalModel <: PlanarMetalModel
    lossfactor::LossFactor
    currentratio::SReal{Float64}
    thickness::Length
    numsheets::Int
    directionup::Bool
end
function Base.write(io::IO, m::ThickMetalModel, u=DimensionsBlock())
    dir = m.directionup ? "" : " TDWN"
    lf, su = lossfactor(m.lossfactor, u, m.directionup)
    le = ustrip(uconvert(u.length, m.thickness))
    println(IOContext(io, son=true), "TMM ", lf, " ", m.currentratio, " ",
        le, " ", m.numsheets, " ", su, dir)
end
function Base.show(io::IO, m::ThickMetalModel)
    leaf = get(io, :leaf, "")
    println(io, leaf, "Thick metal model:")
    println(io, leaf, "  Loss factor:             ", m.lossfactor)
    println(io, leaf, "  Skin effect coefficient: ", m.currentratio)
    println(io, leaf, "  Thickness:               ", m.thickness)
    println(io, leaf, "  Number of sheets:        ", m.numsheets)
    print(io, leaf, "  Metal direction is ", ifelse(m.directionup, "up", "down"))
end

mutable struct RoughMetalModel <: PlanarMetalModel
    isthick::Bool
    lossfactor::LossFactor
    thickness::Length
    toprough::typeof(1.0μm)
    bottomrough::typeof(1.0μm)
    currentratio::SReal{Float64}
    directionup::Bool
end
function Base.write(io::IO, m::RoughMetalModel, u=DimensionsBlock())
    dir = m.directionup ? "" : " TDWN"
    th = m.isthick ? " THK " : " THN "
    lf, su = lossfactor(m.lossfactor, u, m.directionup)
    le = ustrip(uconvert(u.length, m.thickness))
    println(IOContext(io, son=true), "RUF", th, lf, " ", le, " ",
        ustrip(m.toprough), " ", ustrip(m.bottomrough), " ",
        m.currentratio, su, dir)
end

struct DefaultViaModel <: ViaMetalModel end
mutable struct VolumeLossModel <: ViaMetalModel
    lossfactor::LossFactor
    solid::Bool
    wallthickness::Length
end
function Base.write(io::IO, m::VolumeLossModel, u=DimensionsBlock())
    lf, su = lossfactor(m.lossfactor, u)
    le = ustrip(uconvert(u.length, m.wallthickness))
    sol = m.solid ? "SOLID " : ""
    println(IOContext(io, son=true), "VOL ", lf, " ", sol, le, su)
end

mutable struct SurfaceLossModel <: ViaMetalModel
    rdc::SheetResistance
    rrf::SReal{Float64}
    xdc::SheetResistance
end
function Base.write(io::IO, m::SurfaceLossModel, u=DimensionsBlock())
    println(IOContext(io, son=true), "SFC ",
        ustrip(uconvert(u.sheetresistance, m.rdc)), " ", r.rrf, " ",
        ustrip(uconvert(u.sheetresistance, m.xdc)))
end

mutable struct ArrayLossModel <: ViaMetalModel
    lossfactor::LossFactor
    fillfactor::SReal{Float64}
end
function Base.write(io::IO, m::ArrayLossModel, u=DimensionsBlock())
    lf, su = lossfactor(m.lossfactor)
    println(IOContext(io, son=true), "ARR ", lf, " ", m.fillfactor, su)
end

covermodel(x) = false
covermodel(::FreeSpaceModel) = true
covermodel(::WaveguideLoadModel) = true
covermodel(::NormalMetalModel) = true
covermodel(::ResistorModel) = true
covermodel(::NativeModel) = true
covermodel(::GeneralModel) = true
covermodel(::SenseModel) = true

abstract type PolygonFill end

struct Metal{T<:MetalModel} <: PolygonFill
    name::String
    pattern::Int
    metalmodel::T
end
Metal(s::AbstractString, p::Integer, m::MetalModel) =
    Metal(convert(String, s), convert(Int, p), m)
const PlanarMetal = Metal{<:PlanarMetalModel}
const ViaMetal = Metal{<:ViaMetalModel}
function Base.show(io::IO, m::Metal)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "") * "  "
    intro = m isa PlanarMetal ? "Planar " : "Via "
    println(io, root, intro, "metal named \"", m.name, "\" with pattern ", m.pattern)
    show(IOContext(io, root=root, leaf=leaf), m.metalmodel)
end

Metal() = Metal("Lossless", 0, DefaultPlanarModel())
Via() = Metal("Lossless", 0, DefaultViaModel())

function spec_using(str)
    spec_using_str = lowercase(str)
    if spec_using_str == "CDVY"
        :conductivity
    elseif spec_using_str == "RSVY"
        :resistivity
    elseif spec_using_str == "SRVY"
        :sheetresistance
    elseif spec_using_str == "RPV"
        :resistance
    else
        error("unknown `spec_using`: ", spec_using_str)
    end
end

function Base.parse(::Type{Metal}, s::AbstractString, u=DimensionsBlock())
    strs = quotesplit(s)
    name, pattern = strs[2], parse(Int, strs[3])
    modeltype = strs[4]
    model = if modeltype == "VOL"
        solid = lowercase(strs[6]) == "solid"
        ni = solid ? 7 : 6
        spec_using = if length(strs) == ni + 1
            spec_using(strs[ni + 1])
        else
            :conductivity
        end
        su = getfield(u, spec_using)
        VolumeLossModel(
            sonvarparse(Float64, strs[5], su),
            solid,
            sonvarparse(Float64, strs[ni], u.length)
        )
    elseif modeltype == "NOR"
        spec_using = if length(strs) == 8
            spec_using(strs[8])
        else
            :conductivity
        end
        su = getfield(u, spec_using)
        NormalMetalModel(
            sonvarparse(Float64, strs[5], su),
            sonvarparse(Float64, strs[6]),
            sonvarparse(Float64, strs[7], u.length)
        )
    elseif modeltype == "TMM"
        spec_using = if length(strs) >= 9
            spec_using(strs[9])
        else
            :conductivity
        end
        dir = if length(strs) == 10
            lowercase(strs[10]) == "tup"
        else
            true
        end
        su = getfield(u, spec_using)
        ThickMetalModel(
            sonvarparse(Float64, strs[5], su),
            sonvarparse(Float64, strs[6]),
            sonvarparse(Float64, strs[7], u.length),
            sonvarparse(Int, strs[8]),
            dir
        )
    elseif modeltype == "RUF"
        isthick = lowercase(strs[5]) == "thk"
        ni = isthick ? 10 : 11
        spec_using = if length(strs) >= ni
            spec_using(strs[ni])
        else
            :conductivity
        end
        dir = if length(strs) == ni + 1
            lowercase(strs[ni + 1]) == "tup"
        else
            true
        end
        su = getfield(u, spec_using)
        currentratio = isthick ? NaN : sonvarparse(Float64, strs[10])
        RoughMetalModel(
            isthick,
            sonvarparse(Float64, strs[6], su),
            sonvarparse(Float64, strs[7], u.length),
            sonvarparse(Float64, strs[8], Unitful.μm),
            sonvarparse(Float64, strs[9], Unitful.μm),
            currentratio,
            dir
        )
    elseif modeltype == "VOL"
        solid = lowercase(strs[6]) == "solid"
        ni = solid ? 7 : 6
        spec_using = if length(strs) == ni + 1
            spec_using(strs[ni + 1])
        else
            :conductivity
        end
        su = getfield(u, spec_using)
        VolumeLossModel(
            sonvarparse(Float64, strs[5], su),
            solid,
            sonvarparse(Float64, strs[7], u.length)
        )
    elseif modeltype == "ARR"
        spec_using = if length(strs) == 7
            spec_using(strs[7])
        else
            :conductivity
        end
        su = getfield(u, spec_using)
        ArrayLossModel(
            sonvarparse(Float64, strs[5], su),
            sonvarparse(Float64, strs[6])
        )
    else
        if modeltype == "WGLOAD"
            WaveguideLoadModel()
        elseif modeltype == "FREESPACE"
            FreeSpaceModel()
        elseif modeltype == "RES"
            ResistorModel(
                sonvarparse(Float64, strs[5], u.sheetresistance)
            )
        elseif modeltype == "NAT"
            NativeModel(
                sonvarparse(Float64, strs[5], u.sheetresistance),
                sonvarparse(Float64, strs[6])
            )
        elseif modeltype == "SUP"
            GeneralModel(
                sonvarparse(Float64, strs[5], u.sheetresistance),
                sonvarparse(Float64, strs[6]),
                sonvarparse(Float64, strs[7], u.sheetresistance),
                sonvarparse(Float64, strs[8], pH/□)
            )
        elseif modeltype == "SEN"
            SenseModel(
                sonvarparse(Float64, strs[5], u.sheetresistance)
            )
        elseif modeltype == "SFC"
            SurfaceLossModel(
                sonvarparse(Float64, strs[5], u.sheetresistance),
                sonvarparse(Float64, strs[6]),
                sonvarparse(Float64, strs[7], u.sheetresistance)
            )
        else
            error("unknown loss model: ", s)
        end
    end
    return Metal(name, pattern, model)
end

function Base.write(io::IO, m::Metal, u=DimensionsBlock())
    print(io, "MET \"", m.name, "\" ", m.pattern, " ")
    write(io, m.metalmodel, u)
end

mutable struct DielectricBrick <: PolygonFill
    default::Bool
    isotropic::Bool
    name::String
    pattern::Int
    erelx::SReal{Float64}
    losstanx::SReal{Float64}
    bulkx::IntrinsicLossFactor
    erely::SReal{Float64}
    losstany::SReal{Float64}
    bulky::IntrinsicLossFactor
    erelz::SReal{Float64}
    losstanz::SReal{Float64}
    bulkz::IntrinsicLossFactor
    function DielectricBrick(isotropic, name, pattern, erelx, losstanx, bulkx,
        erely, losstany, bulky, erelz, losstanz, bulkz)
        (dimension(bulkx) == dimension(bulky) == dimension(bulkz)) ||
            throw(ArgumentError("must consistently specify bulk conductivity or resistivity."))
        return new(false, isotropic, name, pattern,
            erelx, losstanx, bulkx,
            erely, losstany, bulky,
            erelz, losstanz, bulkz)
    end
    DielectricBrick(a,b,c,d,e,f) = new(false,a,b,c,d,e,f,d,e,f,d,e,f)
    function DielectricBrick() #TODO this won't work on its own
        cdvy = 0.0*(Unitful.S/Unitful.m)
        return new(true, true, "Air", 0, 1.0, 0.0, cdvy,
            1.0, 0.0, cdvy, 1.0, 0.0, cdvy)
    end
end

function Base.show(io::IO, b::DielectricBrick)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")

    if b.default
        print(io, root, "Default dielectric brick")
    else
        println(io, root, "\"", b.name, "\" with pattern ", b.pattern)
        if b.isotropic
            println(io, leaf, "  Dielectric constant: ", b.erelx)
            println(io, leaf, "  Loss tangent:        ", b.losstanx)
            if b.bulkx isa ElectricalConductivity
                print(io, leaf, "  Bulk conductivity:   ", b.bulkx)
            else
                print(io, leaf, "  Bulk resistivity:    ", b.bulkx)
            end
        else
            println(io, leaf, "  X-direction:")
            println(io, leaf, "    Dielectric constant: ", b.erelx)
            println(io, leaf, "    Loss tangent:        ", b.losstanx)
            if b.bulkx isa ElectricalConductivity
                println(io, leaf, "    Bulk conductivity:   ", b.bulkx)
            else
                println(io, leaf, "    Bulk resistivity:    ", b.bulkx)
            end
            println(io, leaf, "  Y-direction:")
            println(io, leaf, "    Dielectric constant: ", b.erely)
            println(io, leaf, "    Loss tangent:        ", b.losstany)
            if b.bulky isa ElectricalConductivity
                println(io, leaf, "    Bulk conductivity:   ", b.bulky)
            else
                println(io, leaf, "    Bulk resistivity:    ", b.bulky)
            end
            println(io, leaf, "  Z-direction:")
            println(io, leaf, "    Dielectric constant: ", b.erelz)
            println(io, leaf, "    Loss tangent:        ", b.losstanz)
            if b.bulkz isa ElectricalConductivity
                print(io, leaf, "    Bulk conductivity:   ", b.bulkz)
            else
                print(io, leaf, "    Bulk resistivity:    ", b.bulkz)
            end
        end
    end
end

function Base.write(io::IO, b::DielectricBrick, u=DimensionsBlock())
    b.default && return
    prefix = ifelse(b.isotropic, "BRI ", "BRA ")
    x, y, z = if b.bulkx isa ElectricalConductivity
        ustrip.(uconvert.(u.conductivity, (b.bulkx, b.bulky, b.bulkz)))
    else
        ustrip.(uconvert.(u.resistivity, (b.bulkx, b.bulky, b.bulkz)))
    end
    ctx = IOContext(io, son=true)
    print(ctx, prefix, "\"", b.name, "\" ", b.pattern, " ",
        b.erelx, " ", b.losstanx, " ", x)
    if !b.isotropic
        print(ctx, " ", b.erely, " ", b.losstany, " ", y)
        print(ctx, " ", b.erelz, " ", b.losstanz, " ", z)
    end
    if b.bulkx isa ElectricalResistivity
        print(io, " RSVY")
    end
    println(io)
end

mutable struct Dimension{L<:Length}
    xdir::Bool
    sign::Bool
    pos::Devices.Points.Point{L}
    nominal::L
    ref1id::Int
    ref1v::Int
    ref2id::Int
    ref2v::Int
end
Dimension(xdir, sign, pos::Devices.Points.Point{L}, nominal::L,
    ref1id, ref1v, ref2id, ref2v) where {L} =
    Dimension{L}(xdir, sign, pos, nominal, ref1id, ref1v, ref2id, ref2v)
Dimension(xdir, sign, pos::Devices.Points.Point{L1}, nominal::L2,
    ref1id, ref1v, ref2id, ref2v) where {L1,L2} =
    Dimension{promote_type(L1,L2)}(xdir, sign,
        convert(Devices.Points.Point{promote_type(L1,L2)}, pos),
        convert(promote_type(L1,L2), nominal), ref1id, ref1v, ref2id, ref2v)
function Base.write(io::IO, v::Dimension, u=DimensionsBlock())
    ctx = IOContext(io, son=true)
    println(ctx, "DIM STD ", ifelse(v.xdir, "XDIR ", "YDIR "),
                            ifelse(v.sign, "1", "-1"))
    println(ctx, "POS ", ustrip(uconvert(u.length, v.pos.x)), " ",
                        ustrip(uconvert(u.length, v.pos.y)))
    println(ctx, "NOM ", ustrip(uconvert(u.length, v.nominal)))
    println(ctx, "REF1 POLY ", v.ref1id, " 1")
    println(ctx, v.ref1v)
    println(ctx, "REF2 POLY ", v.ref2id, " 1")
    println(ctx, v.ref2v)
    println(ctx, "END")
end

const VariableDeclarationTypes = Union{
    Unitful.Length,
    Unitful.ElectricalResistance,
    Unitful.Capacitance,
    Unitful.Inductance,
    Unitful.Frequency,
    SonnetUnits.SheetResistance,
    Unitful.ElectricalConductivity,
    Unitful.ElectricalResistivity,
    Real,
    String
}
mutable struct VariableDeclaration
    value::VariableDeclarationTypes
    description::String
end
function Base.show(io::IO, v::VariableDeclaration)
    print(io, v.value)
    if !isempty(v.description)
        print(io, " (\"", v.description, "\")")
    end
end
function Base.write(io::IO, v::VariableDeclaration, u=DimensionsBlock())
    d = v.value
    dimstr, vstr = if d isa Length
        "LNG", string(ustrip(uconvert(u.length, d)))
    elseif d isa ElectricalResistance
        "RES", string(ustrip(uconvert(u.resistance, d)))
    elseif d isa Capacitance
        "CAP", string(ustrip(uconvert(u.capacitance, d)))
    elseif d isa Inductance
        "IND", string(ustrip(uconvert(u.inductance, d)))
    elseif d isa Frequency
        "FREQ", string(ustrip(uconvert(u.frequency, d)))
    elseif d isa SheetResistance
        "SRES", string(ustrip(uconvert(u.sheetresistance, d)))
    elseif d isa ElectricalConductivity
        "CDVY", string(ustrip(uconvert(u.conductivity, d)))
    elseif d isa ElectricalResistivity
        "RSVY", string(ustrip(uconvert(u.resistivity, d)))
    elseif d isa Real
        "NONE", string(d)
    else
        "NONE", string("\"", d, "\"")
    end
    descstr = string("\"", v.description, "\"")
    println(io, dimstr, " ", vstr, " ", descstr)
end

@enum ParameterType anchored symmetric radial
function Base.write(io::IO, p::ParameterType)
    if p == anchored
        print(io, "ANC")
    elseif p == symmetric
        print(io, "SYM")
    elseif p == radial
        print(io, "RAD")
    else
        error("unexpected parameter type: $p")
    end
end

@enum ScaleType noscaling uniaxial xy
function Base.write(io::IO, s::ScaleType)
    if s == noscaling
        print(io, "NSCD")
    elseif s == uniaxial
        print(io, "SCUNI")
    elseif s == xy
        print(io, "SCXY")
    else
        error("unexpected scale type: $s")
    end
end

struct Parameter{L<:Length}
    name::String
    parametertype::ParameterType
    xdir::Bool
    sign::Bool
    scaletype::ScaleType
    pos::Devices.Points.Point{L}
    nominal::L
    ref1id::Int
    ref1v::Int
    ref2id::Int
    ref2v::Int
    equation
    ps1
    ps2
end
Parameter(name, parametertype, xdir, sign, scaletype, pos::Devices.Points.Point{L},
    nominal::L, ref1id, ref1v, ref2id, ref2v, rest...) where {L} =
    Parameter{L}(name, parametertype, xdir, sign, scaletype, pos, nominal,
        ref1id, ref1v, ref2id, ref2v, rest...)
Parameter(name, parametertype, xdir, sign, scaletype, pos::Devices.Points.Point{L1},
    nominal::L2, ref1id, ref1v, ref2id, ref2v, rest...) where {L1,L2} =
    Parameter{promote_type(L1,L2)}(name, parametertype, xdir, sign, scaletype,
        convert(Devices.Points.Point{promote_type(L1,L2)}, pos),
        convert(promote_type(L1,L2), nominal),
        ref1id, ref1v, ref2id, ref2v, rest...)
function Base.write(io::IO, p::Parameter, u=DimensionsBlock())
    ctx = IOContext(io, son=true)
    print(io, "GEOVAR ", p.name, " ")
    write(io, p.parametertype)
    print(io, " ", ifelse(p.xdir, "XDIR ", "YDIR "),
        ifelse(p.sign, "1 ", "-1 "))
    write(io, p.scaletype)
    println(io)
    println(io, "POS ", ustrip(uconvert(u.length, p.pos.x)), " ",
                        ustrip(uconvert(u.length, p.pos.y)))
    println(io, "NOM ", ustrip(uconvert(u.length, p.nominal)))
    println(io, "REF1 POLY ", p.ref1id, " 1")
    println(io, p.ref1v)
    println(io, "REF2 POLY ", p.ref2id, " 1")
    println(io, p.ref2v)
    println(io, "PS1 ", length(p.ps1))
    for k in keys(p.ps1)
        v = p.ps1[k]
        println(io, "POLY ", k, " ", length(v))
        for n in v
            println(io, n)
        end
    end
    println(io, "END")
    println(io, "PS2 ", length(p.ps2))
    for k in keys(p.ps2)
        v = p.ps2[k]
        println(io, "POLY ", k, " ", length(v))
        for n in v
            println(io, n)
        end
    end
    println(io, "END")
    println(io, "END")
end

struct BoxDielectric{T<:IntrinsicLossFactor}
    isotropic::Bool
    thickness::Length
    εrelxy::SReal{Float64}
    mrelxy::SReal{Float64}
    elossxy::SReal{Float64}
    mlossxy::SReal{Float64}
    bulkxy::T
    nzpart::Int
    name::String
    εrelz::SReal{Float64}
    mrelz::SReal{Float64}
    elossz::SReal{Float64}
    mlossz::SReal{Float64}
    bulkz::T
    BoxDielectric{T}(a,b,c,d,e,f::T,g,h) where {T} =
        new{T}(true,a,b,c,d,e,f,g,h,b,c,d,e,f)
    BoxDielectric{T}(a,b,c,d,e,f::T,g,h,i,j,k,l,m::T) where {T} =
        new{T}(false,a,b,c,d,e,f,g,h,i,j,k,l,m)
end
BoxDielectric(thickness, εrelxy, mrelxy, elossxy, mlossxy, bulkxy::T, nzpart,
    name) where {T} = BoxDielectric{T}(thickness, εrelxy, mrelxy, elossxy,
        mlossxy, bulkxy, nzpart, name)
BoxDielectric(thickness, εrelxy, mrelxy, elossxy, mlossxy, bulkxy::T,
    nzpart, name, εrelz, mrelz, elossz, mlossz, bulkz::T) where {T} =
    BoxDielectric{T}(thickness, εrelxy, mrelxy, elossxy, mlossxy, bulkxy,
        nzpart, name, εrelz, mrelz, elossz, mlossz, bulkz)
function BoxDielectric(thickness, εrelxy, mrelxy, elossxy, mlossxy, bulkxy::S,
    nzpart, name, εrelz, mrelz, elossz, mlossz, bulkz::T) where {S,T}
    (dimension(S) == dimension(T)) ||
        throw(ArgumentError("must consistently specify bulk conductivity or resistivity."))
    s,t = promote(bulkxy, bulkz)
    return BoxDielectric{T}(thickness, εrelxy, mrelxy, elossxy, mlossxy, s,
        nzpart, name, εrelz, mrelz, elossz, mlossz, t)
end
function Base.write(io::IO, b::BoxDielectric{T}, u=DimensionsBlock()) where {T}
    xy, z = if T <: ElectricalConductivity
        ustrip.(uconvert.(u.conductivity, (b.bulkxy, b.bulkz)))
    else
        ustrip.(uconvert.(u.resistivity, (b.bulkxy, b.bulkz)))
    end
    print(io, ustrip(uconvert(u.length, b.thickness)), " ", b.εrelxy, " ", b.mrelxy, " ",
        b.elossxy, " ", b.mlossxy, " ", xy, " ", b.nzpart, " \"", b.name, "\"")
    if !b.isotropic
        print(io, " A ", b.εrelz, " ", b.mrelz, " ", b.elossz, " ", b.mlossz, " ", z)
    end
    println(io, ifelse(T <: ElectricalResistivity, " RSVY", ""))
end
function Base.show(io::IO, b::BoxDielectric)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Name: ", b.name)
    println(io, leaf, "  Thickness:    ", b.thickness)
    println(io, leaf, "  Z-partitions: ", b.nzpart)
    if b.isotropic
        println(io, leaf, "  Relative permittivity: ", b.εrelxy)
        println(io, leaf, "  Relative permeability: ", b.mrelxy)
        println(io, leaf, "  Electric loss tangent: ", b.elossxy)
        println(io, leaf, "  Magnetic loss tangent: ", b.mlossxy)
        if b.bulkxy isa ElectricalConductivity
            print(io, leaf, "  Bulk conductivity: ", b.bulkxy)
        else
            print(io, leaf, "  Bulk resistivity:  ", b.bulkxy)
        end
    else
        println(io, leaf, "  X and Y directions:")
        println(io, leaf, "    Relative permittivity: ", b.εrelxy)
        println(io, leaf, "    Relative permeability: ", b.mrelxy)
        println(io, leaf, "    Electric loss tangent: ", b.elossxy)
        println(io, leaf, "    Magnetic loss tangent: ", b.mlossxy)
        if b.bulkxy isa ElectricalConductivity
            println(io, leaf, "    Bulk conductivity: ", b.bulkxy)
        else
            println(io, leaf, "    Bulk resistivity:  ", b.bulkxy)
        end
        println(io, leaf, "  Z direction:")
        println(io, leaf, "    Relative permittivity: ", b.εrelz)
        println(io, leaf, "    Relative permeability: ", b.mrelz)
        println(io, leaf, "    Electric loss tangent: ", b.elossz)
        println(io, leaf, "    Magnetic loss tangent: ", b.mlossz)
        if b.bulkz isa ElectricalConductivity
            print(io, leaf, "    Bulk conductivity: ", b.bulkz)
        else
            print(io, leaf, "    Bulk resistivity:  ", b.bulkz)
        end
    end
end

struct Box{L<:Length}
    x::L
    y::L
    xcells2::Int
    ycells2::Int
    εeff::Float64   # no variables allowed
    dielectrics::Vector{BoxDielectric}
end
function Base.write(io::IO, b::Box, u=DimensionsBlock())
    ctx = IOContext(io, son=true)
    println(ctx, "BOX ", length(b.dielectrics) - 1, " ",
        ustrip(uconvert(u.length, b.x)), " ",
        ustrip(uconvert(u.length, b.x)), " ",
        b.xcells2, " ", b.ycells2, " 20 ", b.εeff)
    for d in b.dielectrics; write(ctx, "    "); write(ctx, d, u); end
end
function Base.show(io::IO, b::Box)
    leaf = get(io, :leaf, "")
    println(io, leaf, "Sonnet box:")
    println(io, leaf, "  Width:       ", b.x)
    println(io, leaf, "  Height:      ", b.y)
    println(io, leaf, "  2 * x cells: ", b.xcells2)
    println(io, leaf, "  2 * y cells: ", b.ycells2)
    (b.εeff >= 1.0) &&
        println(io, leaf, "  Effective dielectric constant: ", b.εeff)
    println(io, leaf, "  Box dielectrics:")
    for i in 1:length(b.dielectrics)
        ctx = if i==length(b.dielectrics)
            IOContext(io, root=leaf*"  └─", leaf=leaf*"    ")
        else
            IOContext(io, root=leaf*"  ├─", leaf=leaf*"  │ ")
        end
        println(ctx, b.dielectrics[i])
    end
end
# Sonnet default box
Box() = Box(10.0mil, 10.0mil, 32, 32, 0.0, BoxDielectric[])

@enum TechLayerType brick metal via
@enum PlanarMesh staircase diagonal conformal
function Base.write(io::IO, m::PlanarMesh)
    if m == staircase
        print(io, "N")
    elseif m == diagonal
        print(io, "T")
    else
        print(io, "V")
    end
end
@enum ViaMesh ring center vertices solid bar
function Base.write(io::IO, v::ViaMesh)
    if v == ring
        print(io, "RING")
    elseif v == center
        print(io, "CENTER")
    elseif v == vertices
        print(io, "VERTICES")
    elseif v == solid
        print(io, "SOLID")
    else
        print(io, "BAR")
    end
end
mutable struct TechLayer
    laytype::TechLayerType
    dxflayer::Union{Missing,String}
    gdsstream::Int
    gdsobject::Int
    gbrname::Union{Missing,String}
    level::Int
    mtype::Int
    meshtype::PlanarMesh
    debugid::Int
    xmin::Int
    ymin::Int
    xmax::Int
    ymax::Int
    conmax::Float64         # cannot be a variable
    edgemeshing::Bool
    # Vias only::
      tolevel::Int
      viameshtype::ViaMesh
      pads::Bool
end
function Base.show(io::IO, t::TechLayer)
    leaf = get(io, :leaf, "")
    if t.laytype == brick
        print(io, leaf, "Brick")
    elseif t.laytype == metal
        print(io, leaf, "Metal")
    else
        print(io, leaf, "Via")
    end
    println(io, " tech layer")
    if !ismissing(t.dxflayer)
        println(io, leaf, "DXF layer: ", t.dxflayer)
    end
    if t.gdsstream >= 0
        println(io, leaf, "GDS stream: ", t.gdsstream)
        println(io, leaf, "GDS object: ", t.gdsobject)
    end
    if !ismissing(t.gbrname)
        println(io, leaf, "Gerber file: ", t.gbrname)
    end
    println(io, leaf, "Metallization level index: ", t.level)
    println(io, leaf, "index: ", t.mtype)
    print(io, leaf, "Mesh type: ")
    if t.meshtype == staircase
        println(io, "staircase")
    elseif t.meshtype == diagonal
        println(io, "diagonal")
    else
        println(io, "conformal")
    end
    println(io, leaf, "Debug id: ", t.debugid)
    println(io, leaf, "X-direction: min, max subsection size: ", t.xmin, " ", t.xmax)
    println(io, leaf, "Y-direction: min, max subsection size: ", t.ymin, " ", t.ymax)
    println(io, leaf, "Maximum conformal subsection length: ", t.conmax==0? "auto" : t.conmax)
    print(io, leaf, "Edge meshing: ", t.edgemeshing)
    if t.laytype == via
        println(io)
        println(io, leaf, "Via going to level: ", t.tolevel)
        print(io, leaf, "Via meshing type: ")
        if t.viameshtype == ring
            println(io, "ring")
        elseif t.viameshtype == center
            println(io, "center")
        elseif t.viameshtype == vertices
            println(io, "vertices")
        elseif t.viameshtype == solid
            println(io, "solid")
        else
            println(io, "bar")
        end
        print(io, leaf, "Has via pads: ", t.pads)
    end
end

struct EdgeVia
    polyid::Int
    polyedge::Int
    tolevel::Int
end

@enum PortType standard autognd cocalibrated
mutable struct Port
    porttype::PortType
    diagallowed::Bool
    polyid::Int
    polyedge::Int
    number::Int
    resistance::Unitful.ElectricalResistance        # no variables allowed
    reactance::Unitful.ElectricalResistance         # |
    inductance::Unitful.Inductance                  # |
    capacitance::Unitful.Capacitance                # |
    pos::Devices.Points.Point{<:Unitful.Length}     # |
    optargs::Bool
    refplane::Bool
    length::Unitful.Length                          # no variables allowed
end
function Base.show(io::IO, p::Port)
    leaf = get(io, :leaf, "")
    if p.porttype == standard
        print(io, leaf, "Standard port")
    elseif p.porttype == autognd
        print(io, leaf, "Autogrounded port")
    else
        print(io, leaf, "Co-calibrated port")
    end
    print(io, " ", ifelse(p.diagallowed, "(diagonal allowed) ", ""))
    print(io, "on polygon ", p.polyid, ", edge ", p.polyedge, "-", p.polyedge+1)
    println(io, " with number ", p.number)
    println(io, leaf, "  Port terminations: ")
    println(io, leaf, "    Resistance: ", p.resistance)
    println(io, leaf, "    Reactance: ", p.reactance)
    println(io, leaf, "    Inductance: ", p.inductance)
    println(io, leaf, "    Capacitance: ", p.capacitance)
    print(io, leaf, "  Located at: ", p.pos)
    if p.optargs
        println(io)
        str = p.refplane ? "Reference plane: " : "Calibration length: "
        print(io, leaf, "  ", str, p.length)
    end
end
function Base.write(io::IO, p::Port, u=DimensionsBlock())
    print(io, "POR1 ")
    if p.porttype == standard
        println(io, "STD")
    elseif p.porttype == autognd
        println(io, "AGND")
    else
        println(io, "CUP")
    end
    println(io, "DIAGALLOWED ", ifelse(p.diagallowed, "Y", "N"))
    println(io, "POLY ", p.polyid, " 1")
    println(io, p.polyedge)
    print(io, p.number, " ",
        ustrip(uconvert(Ω, p.resistance)), " ",
        ustrip(uconvert(Ω, p.reactance)), " ",
        ustrip(uconvert(nH, p.inductance)), " ",
        ustrip(uconvert(pF, p.capacitance)), " ",
        ustrip(uconvert(u.length, p.pos.x)), " ",
        ustrip(uconvert(u.length, p.pos.y)))
    if p.optargs
        println(io, ifelse(p.refplane, " FIX", " NONE"), " ",
            ustrip(uconvert(u.length, p.length)))
    else
        println(io)
    end
end

@enum GroundReference boxref floatingref userref
function Base.write(io::IO, g::GroundReference)
    if g == boxref
        println(io, "GNDREF B")
    elseif g == floatingref
        println(io, "GNDREF F")
    else
        println(io, "GNDREF P")
    end
end

abstract type TerminalWidthInfo end
struct FeedlineWidth <: TerminalWidthInfo end
struct UserWidth{L<:Length} <: TerminalWidthInfo
    value::L
end
struct OneCellWidth <: TerminalWidthInfo end
function Base.write(io::IO, tw::TerminalWidthInfo, u=DimensionsBlock())
    if tw isa FeedlineWidth
        println(io, "TWTYPE FEED")
        println(io, "TWVALUE 1")
    elseif tw isa UserWidth
        println(io, "TWTYPE CUST")
        println(io, "TWVALUE ", ustrip(uconvert(u.length, tw.value)))
    elseif tw isa OneCellWidth
        println(io, "TWTYPE 1CELL")
        println(io, "TWVALUE 1")
    end
end

struct CalibrationGroup
    name::String
    islocal::Bool
    objectid::Int
    gndref::GroundReference
    twinfo::TerminalWidthInfo
    # TODO: refplanes
    # TODO: gndref must be box or floating
end
# function Base.write(io::IO, )

abstract type ComponentInfo end
struct PortsOnlyComponent <: ComponentInfo end
struct IdealComponent{T<:Union{ElectricalResistance, Capacitance, Inductance}} <: ComponentInfo
    val::T
end
struct DataFileComponent <: ComponentInfo
    fileid::Int
end
struct UserModelComponent <: ComponentInfo
    name::String
    libfolder::String
    libmodule::String
    params::Dict{String, Any}
end
struct SonnetProjectComponent <: ComponentInfo
    name::String
    path::String
    params::Dict{String, Any}
end
struct ComponentPort{L<:Length}
    level::Int
    pos::Devices.Points.Point{L}
    orientation::Side
    port::Int
    pin::Int
end
mutable struct Component{L<:Length}
    level::Int
    label::String
    objectid::Int
    gndref::GroundReference
    twinfo::TerminalWidthInfo
    # TODO: refplanes
    sboxl::L
    sboxr::L
    sboxt::L
    sboxb::L
    showpackagesize::Bool
    pboxl::L
    pboxr::L
    pboxt::L
    pboxb::L
    pkglength::L
    pkgheight::L
    pkgwidth::L
    lposx::L
    lposy::L
    cinfo::ComponentInfo
    cports::Vector{ComponentPort{L}}
end

mutable struct Polygon{L<:Length}
    level::Int
    fill::PolygonFill
    mtype::Int
    meshtype::PlanarMesh
    debugid::Int
    xmin::Int
    ymin::Int
    xmax::Int
    ymax::Int
    conmax::Float64         # cannot be a variable
    edgemeshing::Bool
    # Vias only::
      tolevel::Int
      viameshtype::ViaMesh
      pads::Bool
    tlayername::AbstractString
    inherit::Bool
    polygon::Devices.Polygons.Polygon{L}
end
function Base.write(io::IO, p::Polygon{L}, u=DimensionsBlock()) where {L}
    if p.fill isa Metal{<:PlanarMetalModel}
        # println(io, "MET POL") # optional
    elseif p.fill isa Metal{<:ViaMetalModel}
        println(io, "VIA POLYGON")
    elseif p.fill isa DielectricBrick
        println(io, "BRI POL")
    else
        error("unexpected polygon fill type.")
    end
    print(io, p.level, " ", length(p.polygon.p), " ", p.mtype, " ")
    write(io, p.meshtype)
    print(io, " ", p.debugid, " ", p.xmin, " ", p.ymin, " ")
    print(io, p.xmax, " ", p.ymax, " ", p.conmax, " 0 0 ")
    println(io, ifelse(p.edgemeshing, "Y", "N"))
    if p.fill isa Metal{<:ViaMetalModel}
        print(io, "TOLEVEL ", p.tolevel, " ")
        write(io, p.viameshtype)
        println(io, " ", ifelse(p.pads, "COVERS", "NOCOVERS"))
    end
    if p.tlayername != ""
        println(io, "TLAYNAM ", p.tlayername, " ", ifelse(p.inherit, "INH", "NOH"))
    end
    for pxy in p.polygon.p
        println(io, ustrip(uconvert(u.length, pxy.x)), " ", ustrip(uconvert(u.length, pxy.y)))
    end
    println(io, "END")
end

mutable struct GeometryBlock{L<:Length} <: Block
    symmetric::Bool
    autoheightvias::Bool
    snapangle::SnapAngle

    psb::Dict{Side, L}
    refplanes::Dict{Side, Union{L, Pair{Int,Int}}}

    topcovermetal::Metal
    bottomcovermetal::Metal
    metals::Vector{Metal}
    dimensions::Vector{Dimension}
    dielectricbricks::Vector{DielectricBrick}
    variables::Dict{String, VariableDeclaration}
    parameters::Vector{Parameter{L}}
    box::Box
    # TODO vncells
    techlayers::Dict{String,TechLayer}
    edgevias::Vector{EdgeVia}
    localorigin::Devices.Points.Point{L}
    localoriginlock::Bool
    ports::Vector{Port}
    calibrationgroups::Vector{CalibrationGroup}
    components::Vector{Component{L}}
    polygons::Vector{Polygon}

    function GeometryBlock{L}() where {L}
        return new{L}(
            false,
            false,
            ∠45°,
            Dict{Side, L}(),
            Dict{Side, Union{L, Pair{Int,Int}}}(),
            Metal(),
            Metal(),
            Metal[],
            Dimension{L}[],
            DielectricBrick[],
            Dict{String, VariableDeclaration}(),
            Parameter{L}[],
            Box(),
            Dict{String, TechLayer}(),
            EdgeVia[],
            Devices.Points.Point(zero(L), zero(L)),
            false,
            Port[],
            CalibrationGroup[],
            Component{L}[],
            Polygon[]
        )
    end
end
function GeometryBlock(u::DimensionsBlock = DimensionsBlock())
    L = typeof(1.0*u.length)
    return GeometryBlock{L}()
end

function Base.show(io::IO, b::GeometryBlock)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Sonnet geometry block:")
    println(io, leaf, "  Symmetric:          ", b.symmetric)
    println(io, leaf, "  Auto height vias:   ", b.autoheightvias)
    println(io, leaf, "  Snap angle:         ", b.snapangle)
    # psb
    # refplanes
    println(io, leaf, "  Top cover metal:")
    println(IOContext(io, root=leaf*"  └─", leaf=leaf*"    "), b.topcovermetal)
    println(io, leaf, "  Bottom cover metal:")
    println(IOContext(io, root=leaf*"  └─", leaf=leaf*"    "), b.bottomcovermetal)
    println(io, leaf, "  Metals:")
    for i in 1:length(b.metals)
        ctx = if i==length(b.metals)
            IOContext(io, root=leaf*"  └─", leaf=leaf*"    ")
        else
            IOContext(io, root=leaf*"  ├─", leaf=leaf*"  │ ")
        end
        println(ctx, b.metals[i])
    end
    println(io, leaf, "  Dimensions:         ")
    for i in 1:length(b.dimensions)
        println(io, leaf, "    ", b.dimensions[i])
    end
    println(io, leaf, "  Dielectric bricks:  ")
    for i in 1:length(b.dielectricbricks)
        ctx = if i==length(b.dielectricbricks)
            IOContext(io, root=leaf*"  └─", leaf=leaf*"    ")
        else
            IOContext(io, root=leaf*"  ├─", leaf=leaf*"  │ ")
        end
        println(ctx, b.dielectricbricks[i])
    end
    println(io, leaf, "  Variables:          ")
    for k in keys(b.variables)
        println(io, leaf, "    $k => ", b.variables[k])
    end
    println(io, leaf, "  Parameters:         ")
    for i in 1:length(b.parameters)
        println(io, leaf, "    ", b.parameters[i])
    end
    print(IOContext(io, leaf=leaf*"  "), b.box)
    println(io, leaf, "  Technology layers:  ")
    k = collect(keys(b.techlayers))
    for i in 1:length(k)
        ctx = if i==length(k)
            println(io, leaf, "  └─", k[i])
            IOContext(io, leaf=leaf*"      ")
        else
            println(io, leaf, "  ├─", k[i])
            IOContext(io, leaf=leaf*"    │ ")
        end
        println(ctx, b.techlayers[k[i]])
    end
    println(io, leaf, "  Edge vias:          ")
    for i in 1:length(b.edgevias)
        println(io, leaf, "    ", b.edgevias[i])
    end
    println(io, leaf, "  Ports:              ")
    for i in 1:length(b.ports)
        println(IOContext(io, leaf=leaf*"    "), b.ports[i])
    end
    println(io, leaf, "  Calibration groups: ")
    for i in 1:length(b.calibrationgroups)
        println(io, leaf, "    ", b.calibrationgroups[i])
    end
    println(io, leaf, "  Components:         ")
    for i in 1:length(b.components)
        println(io, leaf, "    ", b.components[i])
    end
    println(io, leaf, "  Polygon count: $(length(b.polygons))")
end

function process1(b::GeometryBlock, io::IO, u::DimensionsBlock)
    l = sonreadline(io)
    isdone = false
    startswith(l, "SYM") && (b.sym = true)
    if startswith(l, "TMET")
        strs = quotesplit(l)
        b.topcovermetal = parse(Metal, l, u)
    elseif startswith(l, "BMET")
        b.bottomcovermetal = parse(Metal, l, u)
    elseif startswith(l, "MET")
        push!(b.metals, parse(Metal, l, u))
    elseif startswith(l, "DIM")
        strs = split(l)
        dir, sign = (strs[3] == "XDIR", strs[4] == "1")
        strs = split(sonreadline(io))
        xc, yc = parse(Float64, strs[2]) * u.length,
            parse(Float64, strs[3]) * u.length
        strs = split(sonreadline(io))
        nvalue = parse(Float64, strs[2]) * u.length
        strs = split(sonreadline(io))
        ref1id = parse(Int, strs[3])
        ref1v = parse(Int, sonreadline(io))
        strs = split(sonreadline(io))
        ref2id = parse(Int, strs[3])
        ref2v = parse(Int, sonreadline(io))
        sonreadline(io)
        push!(b.dimensions, Dimension(
            dir, sign, Devices.Points.Point(xc, yc), nvalue, ref1id, ref1v, ref2id, ref2v))
    elseif startswith(l, "BRI") || startswith(l, "BRA")
        strs = quotesplit(l)
        name = strs[2]
        patternid = parse(Int, strs[3])
        erelx = sonvarparse(Float64, strs[4])
        lossx = sonvarparse(Float64, strs[5])
        if length(strs) == 6
            bulkx = sonvarparse(Float64, strs[6], u.conductivity)
            push!(b.dielectricbricks,
                DielectricBrick(true, name, patternid, erelx, lossx, bulkx))
        elseif length(strs) == 7
            bulkx = sonvarparse(Float64, strs[6], u.resistivity)
            push!(b.dielectricbricks,
                DielectricBrick(true, name, patternid, erelx, lossx, bulkx))
        elseif length(strs) == 12
            bulkx = sonvarparse(Float64, strs[6], u.conductivity)
            erely = sonvarparse(Float64, strs[7])
            lossy = sonvarparse(Float64, strs[8])
            bulky = sonvarparse(Float64, strs[9], u.conductivity)
            erelz = sonvarparse(Float64, strs[10])
            lossz = sonvarparse(Float64, strs[11])
            bulkz = sonvarparse(Float64, strs[12], u.conductivity)
            push!(b.dielectricbricks,
                DielectricBrick(false, name, patternid, erelx, lossx, bulkx,
                    erely, lossy, bulky, erelz, lossz, bulkz))
        elseif length(strs) == 13
            bulkx = sonvarparse(Float64, strs[6], u.resistivity)
            erely = sonvarparse(Float64, strs[7])
            lossy = sonvarparse(Float64, strs[8])
            bulky = sonvarparse(Float64, strs[9], u.resistivity)
            erelz = sonvarparse(Float64, strs[10])
            lossz = sonvarparse(Float64, strs[11])
            bulkz = sonvarparse(Float64, strs[12], u.resistivity)
            push!(b.dielectricbricks,
                DielectricBrick(false, name, patternid, erelx, lossx, bulkx,
                    erely, lossy, bulky, erelz, lossz, bulkz))
        else
            error("unexpected line: ", l)
        end
    elseif startswith(l, "VALVAR")
        strs = quotesplit(l)
        ustr = strs[3]
        unit = if ustr == "LNG"
            u.length
        elseif ustr == "RES"
            u.resistance
        elseif ustr == "CAP"
            u.capacitance
        elseif ustr == "IND"
            u.inductance
        elseif ustr == "FREQ"
            u.frequency
        elseif ustr == "SRES"
            u.sheetresistance
        elseif ustr == "CDVY"
            u.conductivity
        elseif ustr == "RSVY"
            u.resistivity
        elseif ustr == "NONE"
            Unitful.NoUnits
        else
            error("unexpected variable def'n.: ", l)
        end
        b.variables[strs[2]] =
            VariableDeclaration(sondeclparse(Float64, strs[4], unit), strs[5])
    elseif startswith(l, "GEOVAR")
        strs = split(l)
        name = strs[2]
        ptyp = if strs[3] == "ANC"
            anchored
        elseif strs[3] == "SYM"
            symmetric
        elseif strs[3] == "RAD"
            radial
        else
            error("unexpected parameter type: $(strs[3])")
        end
        xdir = (strs[4] == "XDIR")
        sign = (strs[5] == "1")
        sctyp = if strs[6] == "NSCD"
            noscaling
        elseif strs[6] == "SCUNI"
            uniaxial
        elseif strs[6] == "SCXY"
            xy
        else
            error("unexpected scaling type: $(strs[6])")
        end

        strs = split(sonreadline(io))
        pos = Devices.Points.Point(parse(Float64, strs[2]) * u.length,
            parse(Float64, strs[3]) * u.length)

        strs = split(sonreadline(io))
        nom = sontryparse(Float64, strs[2], u.length)

        ref1id = parse(Int, split(sonreadline(io))[3])
        ref1v = parse(Int, sonreadline(io))
        ref2id = parse(Int, split(sonreadline(io))[3])
        ref2v = parse(Int, sonreadline(io))

        #TODO EQN

        ps1 = Dict{Int, Vector{Int}}()
        ps2 = Dict{Int, Vector{Int}}()
        for d in (ps1, ps2)
            np = parse(Int, split(sonreadline(io))[2])
            for i in 1:np
                strs = split(sonreadline(io))
                k = parse(Int, strs[2])
                nv = parse(Int, strs[3])
                vs = Vector{Int}(nv)
                for j in 1:nv
                    vs[j] = parse(Int, sonreadline(io))
                end
                d[k] = vs
            end
            sonreadline(io)
        end
        sonreadline(io)
        push!(b.parameters, Parameter(name, ptyp, xdir, sign, sctyp, posx, posy,
            nom, ref1id, ref1v, ref2id, ref2v, nothing, ps1, ps2))
    elseif startswith(l, "BOX")
        strs = split(l)
        ndiel = parse(Int, strs[2]) + 1
        εeff = length(strs) == 8 ? parse(Float64, strs[8]) : 1.0
        diels = BoxDielectric[]
        for i in 1:ndiel
            l = sonreadline(io)
            strs2 = quotesplit(l)
            bulku = ifelse(strs2[end] == "RSVY", u.resistivity, u.conductivity)
            if (length(strs2) > 8) && (strs2[9] == "A")
                push!(diels, BoxDielectric(
                    sonvarparse(Float64, strs2[1], u.length),
                    sonvarparse.(Float64, strs2[2:5])...,
                    sonvarparse(Float64, strs2[6], bulku),
                    sonvarparse(Int, strs2[7]),
                    strs2[8],
                    sonvarparse.(Float64, strs2[10:13])...,
                    sonvarparse(Float64, strs2[14], bulku)))
            else
                push!(diels, BoxDielectric(
                    sonvarparse(Float64, strs2[1], u.length),
                    sonvarparse.(Float64, strs2[2:5])...,
                    sonvarparse(Float64, strs2[6], bulku),
                    sonvarparse(Int, strs2[7]),
                    strs2[8]))
            end
        end
        b.box = Box(
            sonvarparse.(Float64, strs[3:4], u.length)...,
            sonvarparse.(Int, strs[5:6])...,
            εeff,
            diels
        )
    elseif startswith(l, "TECHLAY")
        strs = split(l)
        lt = if strs[2] == "BRICK"
            brick
        elseif strs[2] == "METAL"
            metal
        elseif strs[2] == "VIA"
            via
        else
            error("unexpected tech layer type")
        end
        name = strs[3]
        dxf = strs[4] == "<UNSPECIFIED>" ? missing : strs[4]
        gdss, gdso = parse(Int, strs[5]), parse(Int, strs[6])
        gbr = length(strs) > 7 ? strs[8] : missing

        strs = split(sonreadline(io))
        level = parse(Int, strs[1])
        nv = parse(Int, strs[2])
        mtype = parse(Int, strs[3])
        local mesh
        mesh = if strs[4] == "N"
            staircase
        elseif strs[4] == "T"
            diagonal
        else
            conformal
        end
        debugid = parse(Int, strs[5])
        xi,yi,xa,ya = (parse.(Int, strs[6:9])...)
        conmax = parse(Float64, strs[10])
        edgemeshing = strs[11] == "Y"

        strs = split(sonreadline(io))
        local tolevel, viameshtype, pads
        if lt == via
            tolevel = parse(Int, strs[2])
            viameshtype = if strs[3] == "RING"
                ring
            elseif strs[3] == "CENTER"
                center
            elseif strs[3] == "VERTICES"
                vertices
            elseif strs[3] == "SOLID"
                solid
            elseif strs[3] == "BAR"
                bar
            else
                error("unexpected via mesh type.")
            end
            pads = strs[4] == "COVERS"
            strs = split(sonreadline(io))
        else
            tolevel = 0
            viameshtype = ring
            pads = false
        end
        readline(io)
        b.techlayers[name] = TechLayer(lt, dxf, gdss, gdso, gbr,
            level, mtype, mesh, debugid, xi, yi, xa, ya, conmax,
            edgemeshing, tolevel, viameshtype, pads)
    elseif startswith(l, "PSB1")
        strs = split(l)
        v = sonvarparse(Float64, strs[3], u.length)
        if strs[2] == "LEFT"
            b.psb[Left] = v
        elseif strs[2] == "RIGHT"
            b.psb[Right] = v
        elseif strs[2] == "TOP"
            b.psb[Top] = v
        else
            b.psb[Bottom] = v
        end
    elseif startswith(l, "DRP1")
        # TODO ref planes
    elseif startswith(l, "EVIA1")
        id = parse(Int, split(sonreadline(io))[2])
        edge = parse(Int, sonreadline(io))
        tolev = parse(Int, split(sonreadline(io))[2])
        push!(b.edgevias, EdgeVia(id, edge, tolev))
    elseif startswith(l, "POR1")
        strs = split(l)
        typ = if strs[2] == "STD"
            standard
        elseif strs[2] == "AGND"
            autognd
        elseif strs[2] == "CUP"
            cocalibrated
        else
            error("unexpected port type: $(strs[2])")
        end
        strs = split(sonreadline(io))
        diag = false
        if strs[1] == "DIAGALLOWED"
            diag = strs[2] == "Y"
            strs = split(sonreadline(io))
        end
        polyid = parse(Int, strs[2])
        edge = parse(Int, sonreadline(io))
        strs = split(sonreadline(io))
        portnum = parse(Int, strs[1])
        resist = parse(Float64, strs[2]) * Ω    # no variables allowed
        react = parse(Float64, strs[3]) * Ω     # no variables allowed
        ind = parse(Float64, strs[4]) * nH      # no variables allowed
        cap = parse(Float64, strs[5]) * pF      # no variables allowed
        pos = Devices.Points.Point(parse(Float64, strs[6])*u.length,
            parse(Float64, strs[7])*u.length)
        push!(b.ports, Port(typ, diag, polyid, edge, portnum,
            resist, react, ind, cap, pos,
            if length(strs) > 7
                (true, strs[8] == "FIX", parse(Float64, strs[9]) * u.length)
            else (false, false, 0.0 * u.length) end...))
    elseif startswith(l, "CUPGRP")
        # TODO calibration group
    elseif startswith(l, "SMD")
        strs = quotesplit(l)
        level, label = parse(Int, strs[2]), strs[3]
        objectid = parse(Int, split(sonreadline(io))[2])
        strs = split(sonreadline(io))
        gndref = if strs[2] == "B"
            boxref
        elseif strs[2] == "F"
            floatingref
        elseif strs[2] == "P"
            userref # TODO userref
        else
            error("unexpected gndref type.")
        end
        strs = split(sonreadline(io))
        twinfo = if strs[2] == "FEED"
            sonreadline(io)  # skip "TWVALUE 1"
            FeedlineWidth()
        elseif strs[2] == "CUST"
            # cannot be a variable
            UserWidth(parse(Float64, split(sonreadline(io))[2]) * u.length)
        elseif strs[2] == "1CELL"
            sonreadline(io)  # skip "TWVALUE 1"
            OneCellWidth()
        else
            error("unexpected terminal width type.")
        end
        # TODO: handle reference plane entries
        strs = split(sonreadline(io))
        sboxl, sboxr, sboxt, sboxb = (parse.(Float64, strs[2:end]).*u.length...,)
        showpackagesize = split(sonreadline(io))[2] == "Y"
        local pboxl, pboxr, pboxb, pboxt, pl, ph, pw
        if showpackagesize
            strs = split(sonreadline(io))
            pboxl, pboxr, pboxt, pboxb = (parse.(Float64, strs[2:end]).*u.length...,)
            strs = split(sonreadline(io))
            pl, pw, ph = (parse.(Float64, strs[2:end]).*u.length...)
        else
            pboxl, pboxr, pboxt, pboxb = (NaN, NaN, NaN, NaN).*u.length
            pl, ph, pw = (NaN, NaN, NaN).*u.length
        end
        strs = split(sonreadline(io))
        lpx, lpy = (parse.(Float64, strs[2:end]).*u.length...)
        strs = quotesplit(sonreadline(io))
        cinfo = if strs[2] == "NONE"
            PortsOnlyComponent()
        elseif strs[2] == "IDEAL"
            cunit = if strs[3] == "RES"
                u.resistance
            elseif strs[3] == "CAP"
                u.capacitance
            elseif strs[3] == "IND"
                u.inductance
            else
                error("unexpected ideal component type.")
            end
            IdealComponent(parse(Float64, strs[4])*cunit)
        elseif strs[2] == "SPARAM"
            DataFileComponent(parse(Int, strs[3]))
        elseif strs[2] == "UMOD"
            # TODO parameters
            UserModelComponent(strs[3], strs[5], strs[6], Dict{String, Any}())
        elseif strs[2] == "SPROJ"
            # TODO parameters
            SonnetProjectComponent(strs[3], strs[4], Dict{String, Any}())
        else
            error("unexpected component type.")
        end
        cports = ComponentPort{typeof(1.0)*u.length}[]
        while (strs = split(sonreadline(io)); strs[1] == "SMDP")
            push!(cports, ComponentPort(
                parse(Int, strs[2]),
                parse(Float64, strs[3]),
                parse(Float64, strs[4]),
                parse(Side, strs[5]),
                parse(Int, strs[6]),
                parse(Int, strs[7])
            ))
        end
        push!(b.components, Component(level, label, objectid, gndref,
            twinfo, sboxl, sboxr, sboxt, sboxb, showpackagesize,
            pboxl, pboxr, pboxt, pboxb, pl, pw, ph, lpx, lpy,
            cinfo, cports))
    elseif startswith(l, "NUM")
        npolys = parse(Int, split(l)[2])
        for i in 1:npolys
            strs = split(sonreadline(io))
            local fillstr
            if isnull(tryparse(Int, strs[1]))
                fillstr = strs[1]
                strs = split(sonreadline(io))
            else
                fillstr = "MET"
            end
            level = parse(Int, strs[1])
            nv = parse(Int, strs[2])
            mtype = parse(Int, strs[3])
            local fill, mesh
            if fillstr == "MET" || fillstr == "VIA"
                if mtype == -1
                    fill = fillstr == "MET" ? Metal() : Via()
                else
                    fill = b.metals[mtype+1]
                end
                if strs[4] == "N"
                    mesh = staircase
                elseif strs[4] == "T"
                    mesh = diagonal
                else
                    mesh = conformal
                end
            else
                mesh = staircase
                if mtype == 0
                    fill = DielectricBrick()
                else
                    fill = dielectricbricks[mtype]
                end
            end
            debugid = parse(Int, strs[5])
            xi,yi,xa,ya = (parse.(Int, strs[6:9])...)
            conmax = parse(Float64, strs[10])
            edgemeshing = strs[11] == "Y"

            strs = split(sonreadline(io))
            local tolevel, viameshtype, pads
            if fillstr == "VIA"
                tolevel = parse(Int, strs[2])
                viameshtype = if strs[3] == "RING"
                    ring
                elseif strs[3] == "CENTER"
                    center
                elseif strs[3] == "VERTICES"
                    vertices
                elseif strs[3] == "SOLID"
                    solid
                elseif strs[3] == "BAR"
                    bar
                else
                    error("unexpected via mesh type.")
                end
                pads = strs[4] == "COVERS"
                strs = split(sonreadline(io))
            else
                tolevel = 0
                viameshtype = ring
                pads = false
            end

            local tlayername, inherit
            if isnull(tryparse(Float64, strs[1]))
                tlayername = strs[1]
                inherit = strs[2] == "INH"
                strs = split(sonreadline(io))
            else
                tlayername = ""
                inherit = false
            end

            pts = Devices.Points.Point{typeof(1.0*u.length)}[]
            for i in 1:nv
                i > 1 && (strs = split(sonreadline(io)))
                push!(pts, Devices.Points.Point(
                    parse(Float64, strs[1])*u.length,
                    parse(Float64, strs[2])*u.length))
            end
            pgon = Devices.Polygons.Polygon(pts)

            push!(b.polygons, Polygon(level, fill, mtype, mesh, debugid,
                xi, yi, xa, ya, conmax, edgemeshing, tolevel, viameshtype,
                pads, tlayername, inherit, pgon))
            sonreadline(io)
        end
    elseif startswith(l, "LORGN")
        strs = split(l)
        b.localorigin =
            Devices.Points.Point(parse(Float64, strs[2])*u.length,
                parse(Float64, strs[3])*u.length)
        b.localoriginlock = strs[4] == "L"
    elseif startswith(l, "END")
        isdone = true
    elseif startswith(l, "VNCELLS")
        # TODO vncells
    elseif startswith(l, "VGMODE")
        b.autoheightvias = true
    elseif startswith(l, "SNPANG")
        ang = parse(Float64, split(l)[2])
        b.snapangle = if ang == 5.0
            ∠5°
        elseif ang == 22.5
            ∠22_5°
        elseif ang == 30
            ∠30°
        elseif ang == 45
            ∠45°
        elseif ang == 90
            ∠90°
        end
    else
        error("Unexpected: ", l)
    end
    # Assign polygon references to the ports?
    return isdone
end

function Base.write(io::IO, x::SnapAngle)
    if x == ∠5°
        println(io, "5")
    elseif x == ∠22_5°
        println(io, "22.5")
    elseif x == ∠30°
        println(io, "30")
    elseif x == ∠45°
        println(io, "45")
    elseif x == ∠90°
        println(io, "90")
    end
end

function Base.write(io::IO, b::GeometryBlock, u=DimensionsBlock())
    println(io, "GEO")
    b.symmetric && println(io, "SYM")
    b.autoheightvias && println(io, "VGMODE STOP")
    if b.snapangle != ∠45°
        print(io, "SNPANG ")
        write(io, b.snapangle)
    end
    for k in keys(b.psb)
        print(io, "PSB1 ")
        print(io, uppercase(string(k)), " ")
        println(io, ustrip(b.psb[k] |> u.length))
    end

    for k in keys(b.refplanes) # TODO
    end

    print(io, "T")
    write(io, b.topcovermetal, u)

    print(io, "B")
    write(io, b.bottomcovermetal, u)

    for m in b.metals; write(io, m, u); end
    for d in b.dimensions; write(io, d, u); end
    for d in b.dielectricbricks; write(io, d, u); end
    write(io, b.box, u)
    for k in keys(b.variables)
        print(io, "VALVAR ", k, ' ')
        write(io, b.variables[k], u)
    end
    for p in b.parameters; write(io, p, u); end
    # TODO VNCELLS
    for k in keys(b.techlayers)
        # TODO
    end
    for v in b.edgevias; write(io, v); end
    println(io, "LORGN ", ustrip(uconvert(u.length, b.localorigin.x)), " ",
        ustrip(uconvert(u.length, b.localorigin.y)), " ",
        ifelse(b.localoriginlock, "L", "U"))
    for p in b.ports; write(io, p, u); end
    for c in b.calibrationgroups; write(io, c, u); end
    for c in b.components; write(io, c, u); end

    println(io, "NUM ", length(b.polygons))
    for p in b.polygons; write(io, p, u); end

    println(io, "END GEO")
end
