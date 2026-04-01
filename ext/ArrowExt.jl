module ArrowExt

using Arrow
using DimensionalData
using DataFrames
using BeForData
using JSON

export write_feather

const BSL_COL_NAME = "__befor_baseline__"

"""
	BeForRecord(arrow_table::Arrow.Table;
		sampling_rate=nothing, time_column=nothing, sessions=nothing) -> BeForRecord

Construct a `BeForRecord` from an `Arrow.Table`, typically loaded from a Feather file
written by [`write_feather`](@ref).

Sampling rate, session start indices, and time column name are read from the table's
Arrow metadata when not provided explicitly. Session indices are stored 0-based in the
Arrow format and are converted to 1-based Julia indices automatically.

See also: [`write_feather(::BeForRecord, ...)`](@ref)
"""
function BeForData.BeForRecord(arrow_table::Arrow.Table;
			sampling_rate::Union{Nothing, Real} = nothing,
			time_column::Union{Nothing, String} = nothing,
			sessions::Union{Nothing, AbstractVector{Int}}=nothing)


	meta = Dict{String, Any}()
	for (k, v) in Arrow.getmetadata(arrow_table)
		if isnothing(sampling_rate) && k == "sampling_rate"
			sampling_rate = parse(Float64, v)
		elseif isnothing(sessions) &&  k == "sessions"
			sessions = parse.(Int, split(v, ",")) .+ 1
		elseif isnothing(time_column) && k == "time_column"
			time_column = v
		else
			push!(meta, k => v)
		end
	end
	if isnothing(sampling_rate)
		throw(ArgumentError("No sampling rate defined!"))
	end
	return BeForRecord(DataFrame(arrow_table), sampling_rate;
		force_cols = nothing, time_column, sessions, meta)
end

"""
	BeForEpochs(arrow_table::Arrow.Table;
		sampling_rate=nothing, zero_sample=nothing) -> BeForEpochs

Construct a `BeForEpochs` from an `Arrow.Table`, typically loaded from a Feather file
written by [`write_feather`](@ref).

Sampling rate and zero sample index are read from the table's Arrow metadata when not
provided explicitly. The zero sample is stored 0-based in the Arrow format and is
converted to 1-based Julia indexing automatically. The baseline column (if present) and
design columns are separated from the force data automatically.

See also: [`write_feather(::BeForEpochs, ...)`](@ref)
"""
function BeForData.BeForEpochs(arrow_table::Arrow.Table;
			sampling_rate::Union{Nothing, Real}=nothing,
			zero_sample::Union{Nothing, Int}=nothing,
			)
	meta = Dict{String, Any}()
	for (k, v) in Arrow.getmetadata(arrow_table)
		if isnothing(sampling_rate) && k == "sampling_rate"
			sampling_rate = parse(Float64, v)
		elseif isnothing(zero_sample) && k == "zero_sample"
			zero_sample = parse(Int64, v) + 1
		else
			push!(meta, k => v)
		end
	end
	if isnothing(sampling_rate)
		throw(ArgumentError("No sampling rate defined!"))
	end
	if isnothing(zero_sample)
		zero_sample = 1
	end

	dat = DataFrame(arrow_table)
	if BSL_COL_NAME in names(dat)
		baseline::Vector{Float64} = dat[:, BSL_COL_NAME]
		select!(dat, Not(BSL_COL_NAME))
	else
		baseline = Float64[]
	end
	# count columns_name that have not int as name
	n_epoch_samples = ncol(dat)
	for cn in reverse(names(dat))
			try
				parse(Int, cn)
				break
			catch e
				if e isa ArgumentError
					n_epoch_samples -= 1
				else
					rethrow(e)
				end
			end
	end
	design = dat[:, n_epoch_samples+1:ncol(dat)]
	mtx = Matrix{Float64}(dat[:, 1:n_epoch_samples])
	if haskey(meta, "record meta")
		recm = replace(meta["record meta"], "'" => '\"')
		meta["record meta"] = Dict(JSON.parse(recm))
	end
	BeForEpochs(mtx, sampling_rate; design, baseline, zero_sample, meta)
end

"""
	write_feather(rec::BeForRecord, filepath::AbstractString; compress=:zstd)

Save `rec` to an Arrow/Feather file at `filepath`.

Sampling rate, time column name, and session start indices are stored as Arrow
metadata. Session indices are converted from 1-based Julia indexing to 0-based Arrow
indexing. The default compression is `:zstd`; pass `compress=nothing` to disable.

See also: [`BeForRecord(::Arrow.Table, ...)`](@ref)
"""
function BeForData.write_feather(rec::BeForRecord, filepath::AbstractString;
	compress::Any = :zstd)
	schema = Dict([
		"sampling_rate" => string(rec.sampling_rate),
		"time_column" => rec.time_column,
		"sessions" => join(string.(rec.sessions .- 1), ",")
	])
	metadata = merge(schema, values_to_string(rec.meta))
	Arrow.write(filepath, DataFrame(rec); compress, metadata)
end

"""
	write_feather(ep::BeForEpochs, filepath::AbstractString; compress=:zstd)

Save `ep` to an Arrow/Feather file at `filepath`.

The force matrix columns are named with 1-based integer strings. Design columns are
appended after the force columns. If `ep` is baseline-adjusted, the baseline vector is
stored in a special column `"__befor_baseline__"`. The zero sample index is converted
from 1-based Julia indexing to 0-based Arrow indexing and stored as Arrow metadata.

See also: [`BeForEpochs(::Arrow.Table, ...)`](@ref)
"""
function BeForData.write_feather(ep::BeForEpochs, filepath::AbstractString;
	compress::Any = :zstd)

	schema = Dict([
		"sampling_rate" => string(ep.sampling_rate),
		"zero_sample" => string(ep.zero_sample - 1)])
	metadata = merge(schema, values_to_string(ep.meta))

	if ep.dat isa DimArray
		mtx = Matrix(ep.dat	)
	else
		# old version TODO is deprecated
		mtx = ep.dat
	end
	cn = string.(1:size(mtx, 2)) # column names for data
	df = hcat(DataFrame(mtx, cn), ep.design)
	if ep.is_baseline_adjusted
		df[!, BSL_COL_NAME] = ep.baseline
	end

	Arrow.write(filepath, df; compress, metadata)
end

function values_to_string(d::AbstractDict)
    rtn = Dict()
    for (key, value) in d
        if value isa AbstractVector
            rtn[key] = join(string.(value), ",")
        else
            if value isa AbstractDict
                rtn[key] = JSON.json(value)
            else
                rtn[key] = string(value)
            end
        end
    end
    return rtn
end

end