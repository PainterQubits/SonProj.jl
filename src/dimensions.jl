import Unitful
import Unitful: Hz, kHz, MHz, GHz, THz, PHz
import Unitful: mil, inch, ft, nm, μm, mm, cm, m
import Unitful: fH, pH, nH, μH, mH, H
import Unitful: fF, pF, nF, μF, mF, F
import Unitful: °
import Unitful: mΩ, Ω, kΩ, MΩ, GΩ, TΩ
import Unitful: S, mS, μS
import Unitful: dB_rp
import Unitful: Units, NoUnits, NoDims, Dimensions
using Unitful:  dimension

struct Variable{T}
    name::String
end
Unitful.dimension(::Variable{T}) where T = T
Unitful.dimension(::Type{Variable{T}}) where T = T
Unitful.uconvert(u::Units, v::Variable) = Variable{dimension(u)}(v.name)
Unitful.ustrip(v::Variable) = v

function Base.show(io::IO, v::Variable{T}) where {T}
    if get(io, :son, false) == true
        print(io, "\"", v.name, "\"")
    else
        if T == NoDims
            print(io, "Dimensionless variable \"", v.name, "\"")
        else
            print(io, "Variable \"", v.name, "\" assuming dimensions: ", T)
        end
    end
end
const SReal{T} = Union{T, Variable{dimension(1.0)}}
for (n,d) in ((:Frequency, dimension(1.0Hz)),
              (:Inductance, dimension(1.0nH)),
              (:Length, dimension(1.0m)),
              (:ElectricalConductivity, dimension(1.0S/m)),
              (:ElectricalResistance, dimension(1.0Ω)),
              (:Capacitance, dimension(1.0F)),
              (:ElectricalResistivity, dimension(1.0Ω*m)),
              (:ElectricalConductance, dimension(1.0S)))
    @eval const $n = Union{Unitful.$n, Variable{$d}}
end
const Attenuation = Union{Unitful.Wavenumber,
    Variable{dimension(Unitful.Wavenumber)}}

module SonnetUnits
    import Unitful
    import Unitful: H, Ω, dimension
    Unitful.@dimension SQ "□" Square
    Unitful.@refunit □ "□" Square SQ false
    Unitful.@derived_dimension SheetResistance dimension(Ω/□)
    Unitful.@derived_dimension SheetInductance dimension(H/□)
end
import .SonnetUnits: □
for (n,d) in ((:SheetResistance, dimension(1.0Ω/□)),
              (:SheetInductance, dimension(1.0nH/□)))
    @eval const $n = Union{SonnetUnits.$n, Variable{$d}}
end

const FrequencyUnits = Union{typeof.([Hz, kHz, MHz, GHz, THz, PHz])...}
const LengthUnits = Union{typeof.([mil, inch, ft, nm, μm, mm, cm, m])...}
const InductanceUnits = Union{typeof.([fH, pH, nH, μH, mH, H])...}
const CapacitanceUnits = Union{typeof.([fF, pF, nF, μF, mF, F])...}
const ResistanceUnits = Union{typeof.([mΩ, Ω, kΩ, MΩ, GΩ, TΩ])...}
const ConductivityUnits = Union{typeof.([S/m, S/cm, mS/cm, μS/cm])...}
const ResistivityUnits  = Union{typeof.([Ω*cm, Ω*m])...}
const SheetResistanceUnits = Union{typeof.([Ω/□, mΩ/□])...}
const AngleUnits = typeof(°)
const ConductanceUnits = typeof(S)
const LossFactor = Union{<:ElectricalConductivity,
                          <:ElectricalResistivity,
                          <:ElectricalResistance}
const IntrinsicLossFactor = Union{<:ElectricalConductivity,
                                  <:ElectricalResistivity}

defaultunits() = (GHz, nH, mil, °, S/m, Ω, pF, Ω*cm, Ω/□, S)
defaultset() = (true, true, true, true, false, true, true, false, false, true)

struct DimensionsBlock{
        A <: FrequencyUnits,
        B <: InductanceUnits,
        C <: LengthUnits,
        D <: AngleUnits,
        E <: ConductivityUnits,
        F <: ResistanceUnits,
        G <: CapacitanceUnits,
        H <: ResistivityUnits,
        J <: SheetResistanceUnits,
        K <: ConductanceUnits} <: Block
    frequency::A
    inductance::B
    length::C
    angle::D
    conductivity::E
    resistance::F
    capacitance::G
    resistivity::H
    sheetresistance::J
    conductance::K

    DimensionsBlock{A,B,C,D,E,F,G,H,J,K}() where {A,B,C,D,E,F,G,H,J,K} =
        new{A,B,C,D,E,F,G,H,J,K}(A(), B(), C(), D(), E(), F(), G(), H(), J(), K())
end
DimensionsBlock() = DimensionsBlock{typeof.(defaultunits())...}()
DimensionsBlock(
    a::FrequencyUnits,
    b::InductanceUnits,
    c::LengthUnits,
    d::AngleUnits,
    e::ConductivityUnits,
    f::ResistanceUnits,
    g::CapacitanceUnits,
    h::ResistivityUnits,
    j::SheetResistanceUnits,
    k::ConductanceUnits) = DimensionsBlock{typeof.((a,b,c,d,e,f,g,h,j,k))...}()

DimensionsBlock(a::FrequencyUnits, z::DimensionsBlock) =
    DimensionsBlock(a, z.inductance, z.length, z.angle, z.conductivity,
        z.resistance, z.capacitance, z.resistivity, z.sheetresistance,
        z.conductance)
DimensionsBlock(b::InductanceUnits, z::DimensionsBlock) =
    DimensionsBlock(z.frequency, b, z.length, z.angle, z.conductivity,
        z.resistance, z.capacitance, z.resistivity, z.sheetresistance,
        z.conductance)
DimensionsBlock(c::LengthUnits, z::DimensionsBlock) =
    DimensionsBlock(z.frequency, z.inductance, c, z.angle, z.conductivity,
        z.resistance, z.capacitance, z.resistivity, z.sheetresistance,
        z.conductance)
DimensionsBlock(d::AngleUnits, z::DimensionsBlock) =
    DimensionsBlock(z.frequency, z.inductance, z.length, d, z.conductivity,
        z.resistance, z.capacitance, z.resistivity, z.sheetresistance,
        z.conductance)
DimensionsBlock(e::ConductivityUnits, z::DimensionsBlock) =
    DimensionsBlock(z.frequency, z.inductance, z.length, z.angle, e,
        z.resistance, z.capacitance, z.resistivity, z.sheetresistance,
        z.conductance)
DimensionsBlock(f::ResistanceUnits, z::DimensionsBlock) =
    DimensionsBlock(z.frequency, z.inductance, z.length, z.angle, z.conductivity,
        f, z.capacitance, z.resistivity, z.sheetresistance, z.conductance)
DimensionsBlock(g::CapacitanceUnits, z::DimensionsBlock) =
    DimensionsBlock(z.frequency, z.inductance, z.length, z.angle, z.conductivity,
        z.resistance, g, z.resistivity, z.sheetresistance, z.conductance)
DimensionsBlock(h::ResistivityUnits, z::DimensionsBlock) =
    DimensionsBlock(z.frequency, z.inductance, z.length, z.angle, z.conductivity,
        z.resistance, z.capacitance, h, z.sheetresistance, z.conductance)
DimensionsBlock(j::SheetResistanceUnits, z::DimensionsBlock) =
    DimensionsBlock(z.frequency, z.inductance, z.length, z.angle, z.conductivity,
        z.resistance, z.capacitance, z.resistivity, j, z.conductance)
DimensionsBlock(k::ConductanceUnits, z::DimensionsBlock) =
    DimensionsBlock(z.frequency, z.inductance, z.length, z.angle, z.conductivity,
        z.resistance, z.capacitance, z.resistivity, z.sheetresistance, k)

DimensionsBlock(a::Units) = DimensionsBlock(a, DimensionsBlock())
DimensionsBlock(a::Units, b::Units...) = DimensionsBlock(a, DimensionsBlock(b...))

function Base.show(io::IO, b::DimensionsBlock)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Sonnet dimensions block:")
    println(io, leaf, "  Frequency:        ", b.frequency)
    println(io, leaf, "  Inductance:       ", b.inductance)
    println(io, leaf, "  Length:           ", b.length)
    println(io, leaf, "  Angle:            ", b.angle)
    println(io, leaf, "  Conductivity:     ", b.conductivity)
    println(io, leaf, "  Resistance:       ", b.resistance)
    println(io, leaf, "  Capacitance:      ", b.capacitance)
    println(io, leaf, "  Resistivity:      ", b.resistivity)
    println(io, leaf, "  Sheet resistance: ", b.sheetresistance)
    println(io, leaf, "  Conductance:      ", b.conductance)
end

function Base.read(io::IO, ::Type{DimensionsBlock})
    l = sonreadline(io)
    f, ind, len, ang, cdvy, res, cap, rsvy, sres, con = defaultunits()
    while !eof(io) && !startswith(l, "END")
        strs = split(l)
        tag, unitstr = strs[1], strs[2]
        if tag == "FREQ"
            f = Dict( "HZ"  => Hz,
                      "kHZ" => kHz,
                      "MHZ" => MHz,
                      "GHZ" => GHz,
                      "THZ" => THz,
                      "PHZ" => PHz )[unitstr]
        elseif tag == "IND"
            ind = Dict( "FH" => fH,
                        "PH" => pH,
                        "NH" => nH,
                        "UH" => μH,
                        "MH" => mH,
                        "H"  => H )[unitstr]
        elseif tag == "LNG"
            len = Dict( "MIL" => mil,
                        "IN"  => inch,
                        "FT"  => ft,
                        "UM"  => μm,
                        "MM"  => mm,
                        "CM"  => cm,
                        "M"   => m )[unitstr]
        elseif tag == "ANG"
        elseif tag == "CON"
        elseif tag == "CAP"
            cap = Dict( "FF" => fF,
                        "PF" => pF,
                        "NF" => nF,
                        "UF" => μF,
                        "MF" => mF,
                        "F"  => F )[unitstr]
        elseif tag == "RES"
            res = Dict( "WOH" => mΩ,
                        "OH"  => Ω,
                        "KOH" => kΩ,
                        "MOH" => MΩ,
                        "GOH" => GΩ,
                        "TOH" => TΩ )[unitstr]
        elseif tag == "RSVY"
            rsvy = Dict( "OHMM" => Ω*m,
                         "OHCM" => Ω*cm )[unitstr]
        elseif tag == "CDVY"
            cdvy = Dict( "SM"   => S/m,
                         "SCM"  => S/cm,
                         "MSCM" => mS/cm,
                         "USCM" => μS/cm )[unitstr]
        elseif tag == "SRES"
            sres = Dict( "MOSQ" => mΩ/□,
                         "OHSQ" => Ω/□ )[unitstr]
        else
            error("unexpected token: ", tag)
        end
        l = sonreadline(io)
    end
    if startswith(l, "END")
        return DimensionsBlock(f, ind, len, °, cdvy, res, cap, rsvy, sres, S)
    else
        error("unexpected end of dimensions block.")
    end
end

freqstr(x) = uppercase(string(x))
rsvystr(x) = ifelse(x === Ω*m, "OHMM", "OHCM")
sresstr(x) = ifelse(x === Ω/□, "OHSQ", "MOSQ")
function indstr(x)
    str = string(x)
    return if str[1] == 'μ'
        "UH"
    else
        uppercase(str)
    end
end
function capstr(x)
    str = string(x)
    return if str[1] == 'μ'
        "UF"
    else
        uppercase(str)
    end
end
angstr(x) = "DEG"
function lngstr(x)
    return if x == inch
        "IN"
    elseif x == μm
        "UM"
    else
        uppercase(string(x))
    end
end
function cdvystr(x)
    return if x == S/m
        "SM"
    elseif x == S/cm
        "SCM"
    elseif x == mS/cm
        "MSCM"
    else
        "USCM"
    end
end
constr(x) = "/OH"
function resstr(x)
    return if x == mΩ
        "WOH"
    elseif x == Ω
        "OH"
    elseif x == kΩ
        "KOH"
    elseif x == MΩ
        "MOH"
    elseif x == GΩ
        "GOH"
    else
        "TOH"
    end
end
function Base.write(io::IO, obj::DimensionsBlock)
    # There are some arbitrary entries which need not always be written...
    println(io, "DIM")
    obj.conductivity == S/m || println(io, "CDVY ", cdvystr(obj.conductivity))
    println(io, "FREQ ", freqstr(obj.frequency))
    println(io, "IND ", indstr(obj.inductance))
    println(io, "LNG ", lngstr(obj.length))
    println(io, "ANG ", angstr(obj.angle))
    println(io, "CON ", constr(obj.conductance))
    println(io, "CAP ", capstr(obj.capacitance))
    println(io, "RES ", resstr(obj.resistance))
    obj.resistivity == Ω*cm || println(io, "RSVY ", rsvystr(obj.resistivity))
    obj.sheetresistance == Ω/□ || println(io, "SRES ", sresstr(obj.sheetresistance))
    println(io, "END DIM")
end

# Ignore DimensionsBlock third argument if a block doesn't support them
Base.write(io::IO, b::Block, u) = write(io, b)
