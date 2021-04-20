"""
Creates a Dict{String,Any} containing all of the properties of a Linecode. See
OpenDSS documentation for valid fields and ways to specify the different
properties.
"""
function _create_linecode(name::String=""; kwargs...)::Dict{String,Any}
    phases = get(kwargs, :nphases, 3)
    circuit_basefreq = get(kwargs, :circuit_basefreq, 60.0)
    basefreq = get(kwargs, :basefreq, circuit_basefreq)

    r1 = get(kwargs, :r1, 0.058)
    x1 = get(kwargs, :x1, 0.1206)

    if haskey(kwargs, :b1)
        b1 = kwargs[:b1]
        c1 = b1 / (2 * pi * basefreq)
    else
        c1 = get(kwargs, :c1, 3.4)
        b1 = c1 * (2 * pi * basefreq)
    end

    if phases == 1
        r0 = r1
        x0 = x1
        c0 = c1
        b0 = b1
    else
        r0 = get(kwargs, :r0, 0.1784)
        x0 = get(kwargs, :x0, 0.4047)
        if haskey(kwargs, :b0)
            b0 = kwargs[:b0]
            c0 = b0 / (2 * pi * basefreq)
        else
            c0 = get(kwargs, :c0, 1.6)
            b0 = c0 * (2 * pi * basefreq)
        end
    end

    Zs = (complex(r1, x1) * 2.0 + complex(r0, x0)) / 3.0
    Zm = (complex(r0, x0) - complex(r1, x1)) / 3.0

    Ys = (complex(0.0, 2 * pi * basefreq * c1) * 2.0 + complex(0.0, 2 * pi * basefreq * c0)) / 3.0
    Ym = (complex(0.0, 2 * pi * basefreq * c0) - complex(0.0, 2 * pi * basefreq * c1)) / 3.0

    Z = zeros(Complex{Float64}, phases, phases)
    Yc = zeros(Complex{Float64}, phases, phases)
    for i in 1:phases
        Z[i,i] = Zs
        Yc[i,i] = Ys
        for j in 1:i-1
            Z[i,j] = Z[j,i] = Zm
            Yc[i,j] = Yc[j,i] = Ym
        end
    end

    rmatrix = get(kwargs, :rmatrix, real(Z))
    xmatrix = get(kwargs, :xmatrix, imag(Z))
    cmatrix = get(kwargs, :cmatrix, imag(Yc) / (2 * pi * basefreq))

    units = get(kwargs, :units, "none")

    Dict{String,Any}(
        "name" => name,
        "nphases" => phases,
        "r1" => r1 / _convert_to_meters[units],
        "x1" => x1 / _convert_to_meters[units],
        "r0" => r0 / _convert_to_meters[units],
        "x0" => x0 / _convert_to_meters[units],
        "c1" => c1 / _convert_to_meters[units],
        "c0" => c0 / _convert_to_meters[units],
        "units" => "m",
        "rmatrix" => rmatrix / _convert_to_meters[units],
        "xmatrix" => xmatrix / _convert_to_meters[units],
        "cmatrix" => cmatrix / _convert_to_meters[units],
        "basefreq" => basefreq,
        "normamps" => get(kwargs, :normamps, 400.0),
        "emergamps" => get(kwargs, :emergamps, 600.0),
        "faultrate" => get(kwargs, :faultrate, 0.1),
        "pctperm" => get(kwargs, :pctperm, 20.0),
        "repair" => get(kwargs, :repair, 3.0),
        "kron" => get(kwargs, :kron, false),
        "rg" => get(kwargs, :rg, 0.01805),
        "xg" => get(kwargs, :xg, 0.155081),
        "rho" => get(kwargs, :rho, 100.0),
        "neutral" => get(kwargs, :neutral, 3),
        "b1" => b1 / _convert_to_meters[units],
        "b0" => b0 / _convert_to_meters[units],
        "like" => get(kwargs, :like, "")
    )
end



"Transformer codes contain all of the same properties as a transformer except bus, buses, bank, xfmrcode"
function _create_xfmrcode(name::String=""; kwargs...)
    windings = isempty(name) ? 3 : get(kwargs, :windings, 2)
    phases = get(kwargs, :phases, 3)

    prcnt_rs = fill(0.2, windings)
    if haskey(kwargs, Symbol("%rs"))
        prcnt_rs = kwargs[Symbol("%rs")]
    elseif haskey(kwargs, Symbol("%loadloss"))
        prcnt_rs[1] = prcnt_rs[2] = kwargs[Symbol("%loadloss")] / 2.0
    end

    temp = Dict{String,Any}(
        "taps" => get(kwargs, :taps, fill(1.0, windings)),
        "conns" => get(kwargs, :conns, fill(WYE, windings)),
        "kvs" => get(kwargs, :kvs, fill(12.47, windings)),
        "kvas" => get(kwargs, :kvas, fill(10.0, windings)),
        "%rs" => prcnt_rs,
        "rneuts" => fill(0.0, windings),
        "xneuts" => fill(0.0, windings)
    )

    for wdg in [:wdg, :wdg_2, :wdg_3]
        if haskey(kwargs, wdg)
            suffix = kwargs[wdg] == 1 ? "" : "_$(kwargs[wdg])"
            for key in [:bus, :tap, :conn, :kv, :kva, Symbol("%r"), :rneut, :xneut]
                subkey = Symbol(string(key, suffix))
                if haskey(kwargs, subkey)
                    temp[string(key, "s")][kwargs[wdg]] = kwargs[subkey]
                end
            end
        end
    end

    xfmrcode = Dict{String,Any}(
        "name" => name,
        "phases" => phases,
        "windings" => windings,
        # Per wdg
        "wdg" => 1,
        "conn" => temp["conns"][1],
        "kv" => temp["kvs"][1],
        "kva" => temp["kvas"][1],
        "tap" => temp["taps"][1],
        "%r" => temp["%rs"][1],
        "rneut" => temp["rneuts"][1],
        "xneut" => temp["xneuts"][1],

        "wdg_2" => 2,
        "conn_2" => temp["conns"][2],
        "kv_2" => temp["kvs"][2],
        "kva_2" => temp["kvas"][2],
        "tap_2" => temp["taps"][2],
        "%r_2" => temp["%rs"][2],
        "rneut_2" => temp["rneuts"][2],
        "xneut_2" => temp["xneuts"][2],

        # General
        "conns" => temp["conns"],
        "kvs" => temp["kvs"],
        "kvas" => temp["kvas"],
        "taps" => temp["taps"],
        "xhl" => get(kwargs, :xhl, 7.0),
        "xht" => get(kwargs, :xht, 35.0),
        "xlt" => get(kwargs, :xlt, 30.0),
        "xscarray" => get(kwargs, :xscarry, Float64[]),
        "thermal" => get(kwargs, :thermal, 2.0),
        "n" => get(kwargs, :n, 0.8),
        "m" => get(kwargs, :m, 0.8),
        "flrise" => get(kwargs, :flrise, 65.0),
        "hsrise" => get(kwargs, :hsrise, 15.0),
        "%loadloss" => get(kwargs, Symbol("%loadloss"), sum(temp["%rs"][1:2])),
        "%noloadloss" => get(kwargs, Symbol("%noloadloss"), 0.0),
        "normhkva" => get(kwargs, :normhkva, 1.1 * temp["kvas"][1]),
        "emerghkva" => get(kwargs, :emerghkva, 1.5 * temp["kvas"][1]),
        "sub" => get(kwargs, :sub, false),
        "maxtap" => get(kwargs, :maxtap, 1.10),
        "mintap" => get(kwargs, :mintap, 0.90),
        "numtaps" => get(kwargs, :numtaps, 32),
        "subname" => get(kwargs, :subname, ""),
        "%imag" => get(kwargs, Symbol("%imag"), 0.0),
        "ppm_antifloat" => get(kwargs, :ppm_antifloat, 1.0),
        "%rs" => temp["%rs"],
        "xrconst" => get(kwargs, :xrconst, false),
        "x12" => get(kwargs, :xhl, 7.0),
        "x13" => get(kwargs, :xht, 35.0),
        "x23" => get(kwargs, :xlt, 30.0),
        "leadlag" => get(kwargs, :leadlag, "lag"),
        "wdgcurrents" => get(kwargs, :wdgcurrents, String[]),
        "core" => get(kwargs, :core, ""),
        "rdcohms" => get(kwargs, :rdcohms, 0.85 * temp["%rs"]),
        # Inherited Properties
        "faultrate" => get(kwargs, :faultrate, 0.1),
        "basefreq" => get(kwargs, :basefreq, 60.0),
        "enabled" => get(kwargs, :enabled, true),
        "like" => get(kwargs, :like, "")
    )

    if windings == 3
        xfmrcode3 = Dict{String,Any}(
            "wdg_3" => 3,
            "conn_3" => temp["conns"][3],
            "kv_3" => temp["kvs"][3],
            "kva_3" => temp["kvas"][3],
            "tap_3" => temp["taps"][3],
            "%r_3" => temp["%rs"][3],
            "rneut_3" => temp["rneuts"][3],
            "xneut_3" => temp["xneuts"][3],
        )

        merge!(xfmrcode, xfmrcode3)
    end

    return xfmrcode
end



"""
Creates a Dict{String,Any} containing all expected properties for a LoadShape
element. See OpenDSS documentation for valid fields and ways to specify
different properties.
"""
function _create_loadshape(name::String=""; kwargs...)
    if haskey(kwargs, :minterval)
        interval = kwargs[:minterval] / 60
    elseif haskey(kwargs, :sinterval)
        interval = kwargs[:sinterval] / 60 / 60
    else
        interval = get(kwargs, :interval, 1.0)
    end

    pmult = get(kwargs, :pmult, Float64[])
    qmult = get(kwargs, :qmult, pmult)

    npts = get(kwargs, :npts, length(pmult) == 0 && length(qmult) == 0 ? 0 : minimum(Int[length(a) for a in [pmult, qmult] if length(a) > 0]))

    pmult = pmult[1:npts]
    qmult = qmult[1:npts]

    hour = get(kwargs, :hour, collect(range(1.0, step=interval, length=npts)))[1:npts]

    Dict{String,Any}(
        "name" => name,
        "npts" => npts,
        "interval" => interval,
        "minterval" => interval * 60,
        "sinterval" => interval * 3600,
        "pmult" => pmult,
        "qmult" => qmult,
        "hour" => hour,
        "mean" => get(kwargs, :mean, mean(pmult)),
        "stddev" => get(kwargs, :stddev, std(pmult)),
        "csvfile" => get(kwargs, :csvfile, ""),
        "sngfile" => get(kwargs, :sngfile, ""),
        "dblfile" => get(kwargs, :dblfile, ""),
        "pqcsvfile" => get(kwargs, :pqcsvfile, ""),
        "action" => get(kwargs, :action, ""),
        "useactual" => get(kwargs, :useactual, true),
        "pmax" => get(kwargs, :pmax, 1.0),
        "qmax" => get(kwargs, :qmax, 1.0),
        "pbase" => get(kwargs, :pbase, 0.0),
        "like" => get(kwargs, :like, "")
    )
end


"""
Creates a Dict{String,Any} containing all expected properties for a GrowthShape
element. See OpenDSS documentation for valid fields and ways to specify
different properties.
"""
function _create_growthshape(name::String=""; kwargs...)
    Dict{String,Any}(
        "name" => name,
        "npts" => get(kwargs, :npts, length(get(kwargs, :year, Float64[]))),
        "year" => get(kwargs, :year, Float64[]),
        "mult" => get(kwargs, :mult, Float64[]),
        "csvfile" => get(kwargs, :csvfile, ""),
        "sngfile" => get(kwargs, :sngfile, ""),
        "dblfile" => get(kwargs, :dblfile, ""),
        "like" => get(kwargs, :like, ""),
    )
end


"""
Creates a Dict{String,Any} containing all expected properties for a XYCurve
object. See OpenDSS documentation for valid fields and ways to specify
different properties.
"""
function _create_xycurve(name::String=""; kwargs...)
    if haskey(kwargs, :points)
        xarray = Float64[]
        yarray = Float64[]

        i = 1
        for point in kwargs[:points]
            if i % 2 == 1
                push!(xarray, point)
            else
                push!(yarray, point)
            end
            i += 1
        end
    else
        xarray = get(kwargs, :xarray, Float64[])
        yarray = get(kwargs, :yarray, Float64[])
    end

    npts = min(length(xarray), length(yarray))

    points = Float64[]
    for (x, y) in zip(xarray, yarray)
        push!(points, x)
        push!(points, y)
    end

    Dict{String,Any}(
        "name" => name,
        "npts" => npts,
        "points" => points,
        "yarray" => yarray,
        "xarray" => xarray,
        "csvfile" => get(kwargs, :csvfile, ""),
        "sngfile" => get(kwargs, :sngfile, ""),
        "dblfile" => get(kwargs, :dblfile, ""),
        "x" => get(kwargs, :x, isempty(xarray) ? 0.0 : xarray[1]),
        "y" => get(kwargs, :y, isempty(yarray) ? 0.0 : yarray[1]),
        "xshift" => get(kwargs, :xshift, 0),
        "yshift" => get(kwargs, :yshift, 0),
        "xscale" => get(kwargs, :xscale, 1.0),
        "yscale" => get(kwargs, :yscale, 1.0),
        "like" => get(kwargs, :like, ""),
    )
end


"""
Creates a Dict{String,Any} containing all expected properties for a Spectrum
object. See OpenDSS documentation for valid fields and ways to specify
different properties.
"""
function _create_spectrum(name::String=""; kwargs...)
    Dict{String,Any}(
        "name" => name,
        "numharm" => get(kwargs, :numharm, 0),
        "harmonic" => get(kwargs, :harmonic, Float64[]),
        "%mag" => get(kwargs, Symbol("%mag"), Float64[]),
        "angle" => get(kwargs, :angle, Float64[]),
        "csvfile" => get(kwargs, :csvfile, ""),
        "like" => get(kwargs, :like, ""),
    )
end


"""
Creates a Dict{String,Any} containing all of the properties of LineGeometry. See
OpenDSS documentation for valid fields and ways to specify the different
properties.
"""
function _create_linegeometry(name::String=""; kwargs...)::Dict{String,Any}
    nconds = get(kwargs, :nconds, 3)
    conds = filter(x->startswith(string(x), "cond"), keys(kwargs))

    temp = Dict{String,Any}(
        "wires" => get(kwargs, :wires, fill("", nconds)),
        "cncables" => get(kwargs, :cncables, fill("", nconds)),
        "tscables" => get(kwargs, :tscables, fill("", nconds)),
        "xs" => fill(0.0, nconds),
        "hs" => fill(0.0, nconds),
        "unitss" => fill("ft", nconds),
    )

    for cond in conds
        suffix = kwargs[cond] == 1 ? "" : "_$(kwargs[cond])"
        for key in [:wire, :x, :h, :units, :cncable, :tscable]
            subkey = Symbol(string(key, suffix))
            if haskey(kwargs, subkey)
                temp[string(key, "s")][kwargs[cond]] = kwargs[subkey]
            end
        end
    end

    Dict{String,Any}(
        "name" => name,
        "nconds" => get(kwargs, :nconds, 3),
        "nphases" => get(kwargs, :nphases, 3),
        "cond" => get(kwargs, :cond, 1),
        "wire" => get(kwargs, :wire, ""),
        "x" => get(kwargs, :x, 0.0) * _convert_to_meters[get(kwargs, :units, "ft")],
        "h" => get(kwargs, :h, 0.0) * _convert_to_meters[get(kwargs, :units, "ft")],
        "units" => "m",
        "normamps" => get(kwargs, :normamps, 400.0),
        "emergamps" => get(kwargs, :emergamps, 600.0),
        "reduce" => get(kwargs, :reduce, false),
        "spacing" => get(kwargs, :spacing, ""),
        "wires" => get(kwargs, :wires, temp["wires"]),
        "cncable" => get(kwargs, :cncable, ""),
        "tscable" => get(kwargs, :tscable, ""),
        "cncables" => get(kwargs, :cncables, temp["cncables"]),
        "tscables" => get(kwargs, :tscables, temp["tscables"]),
        "seasons" => get(kwargs, :seasons, 1),
        "ratings" => get(kwargs, :ratings, Float64[0]),
        "like" => get(kwargs, :like, ""),
        # internal properties
        "xs" => temp["xs"] .* [_convert_to_meters[u] for u in temp["unitss"]],
        "hs" => temp["hs"] .* [_convert_to_meters[u] for u in temp["unitss"]],
        "unitss" => fill("m", nconds),
    )
end


"""
Creates a Dict{String,Any} containing all of the properties of WireData. See
OpenDSS documentation for valid fields and ways to specify the different
properties.
"""
function _create_wiredata(name::String=""; kwargs...)::Dict{String,Any}
    if haskey(kwargs, :diam) || haskey(kwargs, :radius)
        radunits = get(kwargs, :radunits, "none")
        if haskey(kwargs, :diam)
            diam = kwargs[:diam]
            radius = kwargs[:diam] / 2
        elseif haskey(kwargs, :radius)
            radius = kwargs[:radius]
            diam = 2 * kwargs[:radius]
        end

        if !haskey(kwargs, :gmrac)
            gmrac = 0.7788 * kwargs[:radius]
            gmrunits = get(kwargs, :radunits, "none")
        else
            gmrac = kwargs[:gmrac]
            gmrunits = get(kwargs, :gmrunits, "none")
        end
    elseif haskey(kwargs, :gmrac) && !haskey(kwargs, :diag) && !haskey(kwargs, :radius)
        radius = kwargs[:gmrac] / 0.7788
        diam = 2 * kwargs[:radius]
        radunits = get(kwargs, :gmrunits, "none")
        gmrac = kwargs[:gmrac]
        gmrunits = radunits
    else
        radius = 1
        diam = 2
        gmrac = 0.7788
        radunits = "none"
        gmrunits = "none"
    end

    Dict{String,Any}(
        "name" => name,
        "rdc" => get(kwargs, :rdc, get(kwargs, :rac, 0.0)) / _convert_to_meters[get(kwargs, :runits, "none")],
        "rac" => get(kwargs, :rac, get(kwargs, :rdc, 0.0)) / _convert_to_meters[get(kwargs, :runits, "none")],
        "runits" => "m",
        "gmrac" => gmrac * _convert_to_meters[gmrunits],
        "gmrunits" => "m",
        "radius" => radius * _convert_to_meters[radunits],
        "capradius" => get(kwargs, :capradius, radius / 0.7788) * _convert_to_meters[radunits],
        "radunits" => "m",
        "normamps" => get(kwargs, :normamps, get(kwargs, :emergamps, 600.0) / 1.5),
        "emergamps" => get(kwargs, :emergamps, get(kwargs, :normamps, 400.0) * 1.5),
        "diam" => diam * _convert_to_meters[radunits],
        "like" => get(kwargs, :like, ""),
    )
end


"""
Creates a Dict{String,Any} containing all of the properties of LineSpacing. See
OpenDSS documentation for valid fields and ways to specify the different
properties.
"""
function _create_linespacing(name::String=""; kwargs...)::Dict{String,Any}
    Dict{String,Any}(
        "name" => name,
        "nconds" => get(kwargs, :nconds, 3),
        "nphases" => get(kwargs, :nphases, get(kwargs, :nconds, 3)),
        "x" => get(kwargs, :x, zeros(Float64, get(kwargs, :nconds, 3))) .* fill(_convert_to_meters[get(kwargs, :units, "ft")]),
        "h" => get(kwargs, :h, zeros(Float64, get(kwargs, :nconds, 3))) .* fill(_convert_to_meters[get(kwargs, :units, "ft")]),
        "units" => "m",
        # internal properties
        "xs" => get(kwargs, :x, zeros(Float64, get(kwargs, :nconds, 3))) .* fill(_convert_to_meters[get(kwargs, :units, "ft")]),
        "hs" => get(kwargs, :h, zeros(Float64, get(kwargs, :nconds, 3))) .* fill(_convert_to_meters[get(kwargs, :units, "ft")]),
        "unitss" => fill("m", get(kwargs, :nconds, 3))
    )
end
