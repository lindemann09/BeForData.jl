"""
	BeForRecord

Continuous force platform recording with optional multi-session support.

Fields
------
- `dat`: DataFrame containing the raw data. All non-time columns are force channels
  stored as `Float64`.
- `sampling_rate`: Sampling rate in Hz.
- `time_column`: Name of the column in `dat` that holds time stamps. An empty string
  indicates that no time column is present; time stamps are then computed from
  `sampling_rate` starting at 0 ms.
- `sessions`: 1-based sample indices that mark the start of each session. The first
  entry is always 1.
- `meta`: Arbitrary metadata stored as a string-keyed dictionary.
- `force_cols`: Column indices (into `dat`) of the force channels. Set automatically
  by the constructor.

Computed properties (read-only)
--------------------------------
- `n_samples`: Total number of samples across all sessions.
- `n_forces`: Number of force channels.

See also: [`BeForEpochs`](@ref), [`forces`](@ref), [`time_stamps`](@ref),
[`split_sessions`](@ref), [`extract_epochs`](@ref)
"""
struct BeForRecord
	dat::DataFrame
	sampling_rate::Float64
	time_column::String
	sessions::Vector{Int}
	meta::Dict{String, Any}
	force_cols::AbstractVector{Int} # set by constructor

	function BeForRecord(dat::DataFrame,
				sampling_rate::Real,
				time_column::String,
				sessions::AbstractVector{Int},
				meta::Dict{String, Any})

		force_cols = findall(names(dat) .!= time_column)

		for c in force_cols # convert to Data to Float64
			dat[!, c] = convert.(Float64, dat[!, c])
		end

		sessions = collect(sessions)
		if sessions[1] > 1
			pushfirst!(sessions, 1)
		elseif sessions[1] < 1
			sessions[1] = 1
		end
		new(disallowmissing(dat, error=false), sampling_rate, time_column,
			sessions, meta, force_cols)
	end
end;

"""
	BeForRecord(dat::DataFrame, sampling_rate::Real;
		time_column=nothing, sessions=nothing, meta=Dict())

Construct a `BeForRecord` from a DataFrame.

Arguments
---------
- `dat`: DataFrame where each column is either the time column or a force channel.
  Force columns are converted to `Float64` automatically.
- `sampling_rate`: Sampling rate in Hz.

Keyword Arguments
-----------------
- `time_column`: Name of the column in `dat` holding time stamps. If `nothing`, time
  stamps are generated from `sampling_rate` starting at 0 ms.
- `sessions`: 1-based sample indices marking the start of each session. Defaults to
  `[1]` (single session covering all samples).
- `meta`: Optional metadata dictionary.
"""
function BeForRecord(dat::DataFrame,
			sampling_rate::Real;
			time_column::Union{Nothing, String} = nothing,
			sessions::Union{Nothing, AbstractVector{Int}} = nothing,
			meta::Dict = Dict{String, Any}())
	if isnothing(time_column)
		time_column = ""
	else
		if time_column ∉ names(dat)
			throw(ArgumentError("'$time_column' not in dataframe"))
		end
	end
	if isnothing(sessions)
		sessions = nrow(dat) > 0 ? [1] : Int[]
	end
	return BeForRecord(dat, Float64(sampling_rate), time_column, sessions, meta)
end

"""
	copy(d::BeForRecord) -> BeForRecord

Return a deep copy of `d`, including copies of the underlying DataFrame, session
indices, and metadata dictionary.
"""
function Base.copy(d::BeForRecord)
	return BeForRecord(copy(d.dat), d.sampling_rate, d.time_column,
		copy(d.sessions), copy(d.meta))
end

Base.propertynames(::BeForRecord) = (:dat, :sampling_rate, :time_column, :sessions,
	:meta, :force_cols, :n_samples, :n_forces)
function Base.getproperty(d::BeForRecord, s::Symbol)
	if s === :n_samples
		return nrow(d.dat)
	elseif s === :n_forces
		return length(d.force_cols)
	else
		return getfield(d, s)
	end
end

"""
	split_sessions(d::BeForRecord) -> Vector{BeForRecord}

Split a multi-session `BeForRecord` into a vector of single-session records.

Each returned record contains only the samples belonging to one session. Metadata
is shared (not deep-copied) across the resulting records.

See also: [`session_range`](@ref), [`add_session`](@ref)
"""
function split_sessions(d::BeForRecord)
	rtn = BeForRecord[]
	for idx in session_range(d)
		dat = BeForRecord(d.dat[idx, :], d.sampling_rate;
			time_column = d.time_column, meta = d.meta)
		push!(rtn, dat)
	end
	return rtn
end

"""
	time_stamps(d::BeForRecord; session=nothing) -> AbstractVector

Return the time stamps for `d` in milliseconds.

If `d` has a `time_column`, the values from that column are returned directly.
Otherwise, an evenly-spaced range starting at 0 ms is generated from `sampling_rate`.

Arguments
---------
- `session`: If an integer, return time stamps only for that session (1-based index).
  If `nothing` (default), return time stamps for all samples.

See also: [`forces`](@ref), [`find_samples_by_time`](@ref)
"""
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

"""
	forces(d::BeForRecord; session=nothing) -> DataFrame

Return the force data from `d` as a DataFrame.

Arguments
---------
- `session`: If an integer, return data only for that session (1-based index).
  If `nothing` (default), return data for all samples.

See also: [`time_stamps`](@ref), [`session_range`](@ref)
"""
function forces(d::BeForRecord;
	session::Union{Nothing, Int} = nothing)

	idx = isnothing(session) ? (1:nrow(d.dat)) : session_range(d, session)
	return d.dat[idx, d.force_cols]
end

"""
	add_session(d::BeForRecord, session_data::DataFrame) -> BeForRecord

Return a new `BeForRecord` with `session_data` appended as an additional session.

The new session begins at the sample immediately following the last sample of `d`.
`session_data` must have the same columns as `d.dat`.

See also: [`split_sessions`](@ref), [`session_range`](@ref)
"""
function add_session(d::BeForRecord, session_data::DataFrame)
	dat = vcat(copy(d.dat), session_data)
	sessions = vcat(d.sessions, nrow(d.dat))
	return BeForRecord(dat, d.sampling_rate, d.time_column, sessions, d.meta)
end


"""
	session_range(d::BeForRecord, session::Int) -> UnitRange{Int}
	session_range(d::BeForRecord) -> Vector{UnitRange{Int}}

Return the sample index range for the given session (1-based), or a vector of
ranges for all sessions when called without a session argument.

The range covers all samples from the session's start up to and including the last
sample before the next session (or the end of the record for the last session).

See also: [`split_sessions`](@ref), [`forces`](@ref), [`time_stamps`](@ref)
"""
function session_range(d::BeForRecord, session::Int)
	t = (session + 1) > length(d.sessions) ? nrow(d.dat) : d.sessions[session+1]-1
	return d.sessions[session]:t
end

session_range(d::BeForRecord) = [session_range(d, s) for s in 1:length(d.sessions)]


"""
	find_samples_by_time(times::AbstractVector, d::BeForRecord) -> Vector{Int}

Return the sample indices in `d` that correspond to the given `times` (in ms).

For each value in `times`, the index of the first time stamp that is greater than or
equal to that value is returned. If no exact match exists, the next larger time stamp
is used:

```math
\\text{time\\_stamps}[i-1] \\leq t < \\text{time\\_stamps}[i]
```

See also: [`time_stamps`](@ref), [`extract_epochs`](@ref)
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



