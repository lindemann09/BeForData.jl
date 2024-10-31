"""
	BeForRecord

TODO
"""
struct BeForRecord
	dat::DataFrame
	sampling_rate::Float64
	columns::Vector{String}
	sessions::Vector{Int}
	time_column::String
	meta::Dict{String, Any}

	function BeForRecord(dat::DataFrame, sampling_rate::Real,
				columns::Vector{String}, sessions::AbstractVector{Int},
				time_column::String, meta::Dict{String, Any})

		for c in columns # convert to Data to Float64
			dat[!, c] = convert.(Float64, dat[!, c])
		end
		new(disallowmissing(dat, error=false), sampling_rate, columns,
			collect(sessions), time_column, meta)
	end
end;


function BeForRecord(dat::DataFrame, sampling_rate::Real;
	columns::Union{Nothing, AbstractString, Vector{<:AbstractString}} = nothing,
	sessions::Union{Nothing, AbstractVector{Int}} = nothing,
	time_column::String = "",
	meta::Dict = Dict{String, Any}())

	if isnothing(sessions)
		sessions = nrow(dat) > 0 ? [1] : Int[]
	end
	if isnothing(columns)
		columns = names(dat)
	end
	return BeForRecord(dat, Float64(sampling_rate), string_list(columns), sessions,
		time_column, meta)
end

function BeForRecord(arrow_table::Arrow.Table)
	meta = Dict{String, Any}()
	sampling_rate = 0
	columns = String[]
	sessions = []
	time_column = ""
	for (k, v) in Arrow.getmetadata(arrow_table)
		if k == "sampling_rate"
			sampling_rate = parse(Float64, v)
		elseif k == "columns"
			columns = string.(split(v, ","))
		elseif k == "sessions"
			sessions = parse.(Int, split(v, ","))
		elseif k == "time_column"
			time_column = v
		else
			push!(meta, k => v)
		end
	end
	return BeForRecord(DataFrame(arrow_table), sampling_rate;
		columns, sessions, time_column, meta)
end


function Base.copy(d::BeForRecord)
	return BeForRecord(copy(d.dat), d.sampling_rate, copy(d.columns),
		copy(d.sessions), d.time_column, copy(d.meta))
end

Base.propertynames(::BeForRecord) = (:dat, :sampling_rate, :columns, :sessions,
	:meta, :n_samples, :n_forces, :n_sessions, :time_column, :time_stamps)
function Base.getproperty(d::BeForRecord, s::Symbol)
	if s === :n_samples
		return nrow(d.dat)
	elseif s === :n_forces
		return length(d.columns)
	elseif s === :n_sessions
		return length(d.sessions)
	elseif s === :time_stamps
		return _time_stamps(d)
	else
		return getfield(d, s)
	end
end

function _time_stamps(d::BeForRecord)
	if length(d.time_column) > 0
		return d.dat[:, d.time_column]
	else
		step = 1000.0 / d.sampling_rate
		final_time = (nrow(d.dat) - 1) * step
		return 0:step:final_time
	end
end

function add_session(d::BeForRecord, session_data::DataFrame)
	dat = vcat(copy(d.dat), session_data)
	sessions = vcat(d.sessions, nrow(d.dat))
	return BeForRecord(dat, d.sampling_rate, d.columns, sessions, d.meta)
end

function get_data(d::BeForRecord;
	columns::Union{Nothing, AbstractString, Vector{<:AbstractString}} = nothing,
	session::Union{Nothing, Int} = nothing)

	if isnothing(columns)
		columns = names(dat)
	end
	if isnothing(session)
		return d.dat[!, columns]
	else
		return d.dat[session_rows(d, session), columns]
	end
end

function get_forces(d::BeForRecord; session::Union{Nothing, Int} = nothing)
	return get_data(d.columns; session)
end


function write_feather(d::BeForRecord, filepath::AbstractString;
	compress::Any = :zstd)
	schema = Dict([
		"sampling_rate" => string(d.sampling_rate),
		"columns" => join(d.columns, ","),
		"time_column" => d.time_column,
		"sessions" => join([string(x) for x in d.sessions], ",")])
	Arrow.write(filepath, d.dat; compress, metadata = merge(schema, d.meta))
end

function add_column!(d::BeForRecord, name::String, data::AbstractVector;
	is_force_column::Bool = false)
	d.dat[!, name] = data
	is_force_column && push!(d.columns, name)
	return nothing
end

function drop_column!(d::BeForRecord, name::String)
	select!(d.dat, Not(name))
	filter!(x -> x != name, d.columns)
	return nothing
end

function session_rows(d::BeForRecord, session::Int)
	# helper function
	f = d.sessions[session] + 1 # julia index
	t = session + 1 > length(d.sessions) ? nrow(d.dat) : d.sessions[session+1]
	return f:t
end

"""returns sample index (i) of the closes time in the BeForRecord.
		Takes the next larger element, if the exact time could not be found.

		``time_stamps[i-1] <= t < time_stamps[i]``

"""
function find_samples_by_time(times::AbstractVector, d::BeForRecord)
	ts = d.time_stamps
	return searchsortedfirst.(Ref(ts), times)
end;

function Base.show(io::IO, mime::MIME"text/plain", x::BeForRecord)
	println(io, "BeForRecord")
	println(io, "  sampling_rate: $(x.sampling_rate), n sessions: $(x.n_sessions) ")
	println(io, "  columns $(x.columns)")
	println(io, "  time_column $(x.time_column)")
	println(io, "  metadata")
	for (k, v) in x.meta
		println(io, "  - $k: $v")
	end
	println(io, x.dat)
end


### helper

string_list(x::AbstractString) = [x]
string_list(x::Vector{<:AbstractString}) = x


