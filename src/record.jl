"""
	BeForRecord

TODO
"""
struct BeForRecord
	dat::DataFrame
	sampling_rate::Float64
	time_column::String
	sessions::Vector{Int}
	meta::Dict{String, Any}

	function BeForRecord(dat::DataFrame,
				sampling_rate::Real,
				time_column::Union{Nothing, String},
				sessions::Union{Nothing, AbstractVector{Int}},
				meta::Dict{String, Any})

		if isnothing(time_column)
			time_column = ""
		else
			if time_column ∉ names(dat)
				throw(ArgumentError("'$time_column' not in dataframe"))
			end
		end

		for c in findall(names(dat) .!= time_column) # convert to Data to Float64
			dat[!, c] = convert.(Float64, dat[!, c])
		end

		if isnothing(sessions)
			sessions = nrow(dat) > 0 ? [1] : Int[]
		else
			sessions = collect(sessions)
			if sessions[1] > 1
				pushfirst!(sessions, 1)
			elseif sessions[1] < 1
				sessions[1] = 1
			end
		end
		new(disallowmissing(dat, error=false), sampling_rate, time_column,
			sessions, meta)
	end
end;

function BeForRecord(dat::DataFrame,
	sampling_rate::Real;
	time_column::Union{Nothing, String} = nothing,
	sessions::Union{Nothing, AbstractVector{Int}} = nothing,
	meta::Dict = Dict{String, Any}())
	return BeForRecord(dat, Float64(sampling_rate), time_column, sessions, meta)
end

function BeForRecord(arrow_table::Arrow.Table)
	meta = Dict{String, Any}()
	sampling_rate = 0
	sessions = []
	time_column = ""
	for (k, v) in Arrow.getmetadata(arrow_table)
		if k == "sampling_rate"
			sampling_rate = parse(Float64, v)
		elseif k == "sessions"
			sessions = parse.(Int, split(v, ","))
		elseif k == "time_column"
			time_column = v
		else
			push!(meta, k => v)
		end
	end
	return BeForRecord(DataFrame(arrow_table), sampling_rate;
		time_column, sessions, meta)
end


function Base.copy(d::BeForRecord)
	return BeForRecord(copy(d.dat), d.sampling_rate, d.time_column,
		copy(d.sessions), copy(d.meta))
end

Base.propertynames(::BeForRecord) = (:dat, :sampling_rate, :time_column, :sessions,
	:meta, :n_samples, :force_cols, :n_forces)
function Base.getproperty(d::BeForRecord, s::Symbol)
	if s === :n_samples
		return nrow(d.dat)
	elseif s === :force_cols
		return findall(names(d.dat) .!= d.time_column)
	elseif s === :n_forces
		return length(d.force_cols)
	else
		return getfield(d, s)
	end
end

function split_sessions(d::BeForRecord)
	rtn = BeForRecord[]
	for idx in session_range(d)
		dat = BeForRecord(d.dat[idx, :], d.sampling_rate, d.time_column, nothing, d.meta)
		push!(rtn, dat)
	end
	return rtn
end

function time_stamps(d::BeForRecord;
	session::Union{Nothing, Int} = nothing)

	idx = isnothing(session) ? (1:nrow(d.dat)) : session_range(d, session)

	if length(d.time_column) > 0
		return d.dat[idx, d.time_column]
	else
		step = 1000.0 / d.sampling_rate # in ms
		final_time = (length(idx) - 1) * step
		return 0:step:final_time
	end
end

function forces(d::BeForRecord;
	session::Union{Nothing, Int} = nothing)

	idx = isnothing(session) ? (1:nrow(d.dat)) : session_range(d, session)
	return d.dat[idx, d.force_cols]
end

function add_session(d::BeForRecord, session_data::DataFrame)
	dat = vcat(copy(d.dat), session_data)
	sessions = vcat(d.sessions, nrow(d.dat))
	return BeForRecord(dat, d.sampling_rate, d.time_column, sessions, d.meta)
end

function write_feather(d::BeForRecord, filepath::AbstractString;
	compress::Any = :zstd)
	schema = Dict([
		"sampling_rate" => string(d.sampling_rate),
		"time_column" => d.time_column,
		"sessions" => join([string(x) for x in d.sessions], ",")])
	Arrow.write(filepath, d.dat; compress, metadata = merge(schema, d.meta))
end


"""returns sample range of session
"""
function session_range(d::BeForRecord, session::Int)
	t = (session + 1) > length(d.sessions) ? nrow(d.dat) : d.sessions[session+1]-1
	return d.sessions[session]:t
end

session_range(d::BeForRecord) = [session_range(d, s) for s in 1:length(d.sessions)]


"""returns sample index (i) of the closes time in the BeForRecord.
		Takes the next larger element, if the exact time could not be found.

		``time_stamps[i-1] <= t < time_stamps[i]``

"""
function find_samples_by_time(times::AbstractVector, d::BeForRecord)
	ts = time_stamps(d)
	return searchsortedfirst.(Ref(ts), times)
end;

function Base.show(io::IO, mime::MIME"text/plain", x::BeForRecord)
	println(io, "BeForRecord")
	println(io, "  sampling_rate: $(x.sampling_rate), n sessions: $(length(x.sessions)) ")
	println(io, "  time_column $(x.time_column)")
	println(io, "  metadata")
	for (k, v) in x.meta
		println(io, "  - $k: $v")
	end
	println(io, x.dat)
end



