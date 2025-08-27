module ArrowExt

using Arrow
using DataFrames
using BeForData

export write_feather

const BSL_COL_NAME = "__befor_baseline__"

"""
Arrow data format use 0-based index. The session information
will be therefor converted to 1-based indexing as used in Julia.
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
		time_column, sessions, meta)
end

"""
Arrow data format use 0-based index. The zero_sample
will be therefore converted to 1-based indexing as used in Julia.
"""
function BeForData.BeForEpochs(arrow_table::Arrow.Table;
			sampling_rate::Union{Nothing, Real}=nothing,
			zero_sample::Union{Nothing, Int}=nothing,
			)
	for (k, v) in Arrow.getmetadata(arrow_table)
		if isnothing(sampling_rate) && k == "sampling_rate"
			sampling_rate = parse(Float64, v)
		elseif isnothing(zero_sample) && k == "zero_sample"
			zero_sample = parse(Int64, v) + 1
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
	BeForEpochs(mtx, sampling_rate, design, baseline, zero_sample)
end

"""
Arrow data format use 0-based index. The session information
will be therefore converted.
"""
function BeForData.write_feather(d::BeForRecord, filepath::AbstractString;
	compress::Any = :zstd)
	schema = Dict([
		"sampling_rate" => string(d.sampling_rate),
		"time_column" => d.time_column,
		"sessions" => join(string.(d.sessions .- 1), ",")
	])
	metadata = merge(schema, values_to_string(d.meta))
	Arrow.write(filepath, d.dat; compress, metadata)
end

"""
Arrow data format use 0-based index. The zero_sample
will be therefore converted.
"""
function BeForData.write_feather(d::BeForEpochs, filepath::AbstractString;
	compress::Any = :zstd)

	schema = Dict([
		"sampling_rate" => string(d.sampling_rate),
		"zero_sample" => string(d.zero_sample - 1)])

	# build dataframe
	cn = [string(x) for x in 1:d.dat.size[2]] # column names for data
	df = hcat(DataFrame(d.dat, cn), d.design)
	if d.is_baseline_adjusted
		df[!, BSL_COL_NAME] = d.baseline
	end

	Arrow.write(filepath, df; compress, metadata = schema)
end

function values_to_string(d::Dict)
    rtn = copy(d)
    for (key, value) in rtn
        if value isa AbstractVector
            rtn[key] = join(string.(value), ",")
        else
            rtn[key] = string(value)
        end
    end
    return rtn
end


end