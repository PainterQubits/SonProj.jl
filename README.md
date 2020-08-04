# SonProj

For reading and writing Sonnet project files in Julia.

## Usage

```
julia> using SonProj

julia> p = open("/path/to/sonnetproject.son") do f
    read(f, SonProj.Project)
end
┌─Sonnet project:
│   Geometry project: true
│   Version:          16.54
│   Auto-delete:      false
├─Sonnet header block:
│   License:    <omitted>
│   Last saved: 2018-05-20T16:47:01
│   BUILT_BY_CREATED xgeom 16.54 05/20/2018 16:46:50
│   BUILT_BY_SAVED xgeom 16.54
│   Last saved (medium priority): 2018-05-20T16:47:01
│   Last saved (high priority):   2018-05-20T16:47:01
├─Sonnet dimensions block:
│   Frequency:        GHz
│   Inductance:       nH
│   Length:           mil
│   Angle:            °
│   Conductivity:     m^-1 S
│   Resistance:       Ω
│   Capacitance:      pF
│   Resistivity:      cm Ω
│   Resistance / sq.: Ω
│   Conductance:      S
├─Sonnet geometry block:
│   Symmetric:          false
│   Auto height vias:   false
│   Snap angle:         ∠45°
│   Top cover metal:    SonProj.Metal{SonProj.GeneralModel}("Lossless", 0, SonProj.GeneralModel(0.0, 0.0, 0.0, 0.0))
│   Bottom cover metal: SonProj.Metal{SonProj.GeneralModel}("Lossless", 0, SonProj.GeneralModel(0.0, 0.0, 0.0, 0.0))
│   Metals:
│   Dimensions:
│   Dielectric bricks:
│   Variables:
│   Parameters:
SonProj.Box(160.0, 160.0, 32, 32, 0.0, SonProj.BoxDielectric[SonProj.BoxDielectric(true, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0, "Unnamed", 1.0, 1.0, 0.0, 0.0, 0.0), SonProj.BoxDielectric(true, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0, "Unnamed", 1.0, 1.0, 0.0, 0.0, 0.0)])
│   Technology layers:
│   Edge vias:
│   Ports:
│   Calibration groups:
│   Components:
│   Polygon count: 0
├─Sonnet frequency block:
├─Sonnet control block:
│   Sweep type:              ABS
│   ABS resolution in use:   missing
│   ABS resolution:          missing
│   Compute currents:        false
│   Multi-frequency caching: false
│   Single precision:        false
│   Box resonance info:      false
│   Deembedding:             true
│   Subsections / λ in use:  missing
│   Subsections / λ:         missing
│   Edge check in use:       missing
│   Edge check levels:       missing
│   Edge check tech layers:  missing
│   Max subsection f in use: missing
│   Max subsection f:        missing
│   Estimate ε in use:       missing
│   Estimate ε:              missing
│   Speed:                   0
│   Cache ABS:               1
│   Target ABS:              300
│   Q factor accuracy:       false
│   Enhanced resonance det.: missing
├─Sonnet optimization block:
├─Sonnet variable sweep block
├─Sonnet file out block
└─Sonnet quick start guide block:
    DXF or GDS imported:       false
    Extra metal removed:       false
    Units changed:             false
    Aligned to grid:           false
    Reference planes added:    false
    Viewed response data:      false
    Defined new metals:        false
    Quick start guide enabled: false

julia> open("/path/to/newproject.son", "w") do f
         write(f, p)
       end

julia>
```
