"""
	BeForEpochs

Epoch-based response force data, where each epoch is a fixed-length segment of force
samples extracted from a continuous recording.

The data are stored as a 2-D `DimArray` with shape `(n_epochs, n_samples)`. An optional
`baseline` vector (one value per epoch) records the per-epoch mean that was subtracted
during baseline correction.

Fields
------
- `dat`: `(n_epochs × n_samples)` `DimArray` of force values in `Float64`
	with dimensions `(epoch, time)`.
- `sampling_rate`: Sampling rate in Hz.
- `design`: DataFrame with one row per epoch holding trial-level metadata
  (condition labels, participant ID, etc.). May be empty.
- `baseline`: Per-epoch baseline values subtracted during [`adjust_baseline!`](@ref).
  Empty when no baseline correction has been applied.
- `meta`: Arbitrary metadata stored as a string-keyed dictionary.

Computed properties (read-only)
--------------------------------
- `n_epochs`: Number of epochs (rows of `dat`).
- `n_samples`: Number of samples per epoch (columns of `dat`).
- `is_baseline_adjusted`: `true` if a baseline correction has been applied.
- `zero_sample`: 1-based column index in `dat` that corresponds to time zero.

See also: [`BeForRecord`](@ref), [`extract_epochs`](@ref), [`adjust_baseline!`](@ref),
[`subset`](@ref)
"""

struct BeForEpochs
	dat::DimArray{Float64, 2}
	sampling_rate::Real
	design::DataFrame
	baseline::Vector{Float64}
	meta::Dict{String, Any}

	function BeForEpochs(dat::DimArray{Float64, 2},
		sampling_rate::Real,
		design::DataFrame,
		baseline::Vector{Float64},
		meta::Dict{String, Any})
		lf = size(dat, 1)
		lb = length(baseline)
		lb == 0 || lf == lb || throw(
			ArgumentError(
				"If base is defined, number of rows of force ($(lf)) must match the length of baseline ($(lb)).",
			),
		)
		n = nrow(design)
		n == 0 || lf == n || throw(
			ArgumentError(
				"Number of rows of force ($(lf)) must match the number of rows ins the design ($(n)).",
			),
		)
		return new(dat, sampling_rate, design, baseline, meta)
	end
end;

"""
	BeForEpochs(force::Matrix{Float64}, sampling_rate::Real; zero_sample::Int = 1,
		design::Union{Nothing, DataFrame} = nothing, baseline::Union{Nothing,
		Vector{Float64}} = nothing, meta::Union{Nothing, Dict{String, Any}} = nothing)
	BeForEpochs(force::DimArray{Float64, 2}, sampling_rate::Real;
		design::Union{Nothing, DataFrame}=nothing, baseline::Union{Nothing,
		Vector{Float64}} = nothing, meta::Union{Nothing, Dict{String, Any}} = nothing)

Construct a `BeForEpochs` from a force matrix.

Arguments
---------
- `force`: `(n_epochs × n_samples)` matrix of force values.
- `sampling_rate`: Sampling rate in Hz.

Keyword Arguments
-----------------
- `zero_sample`: 1-based column index in `force` corresponding to time zero.
  Defaults to 1.
- `design`: DataFrame with one row per epoch containing trial metadata. Defaults to
  an empty DataFrame.
- `baseline`: Per-epoch baseline values (length must equal `n_epochs`). Defaults to
  an empty vector (no baseline correction applied).

- `meta`: Metadata dictionary. Defaults to an empty dictionary.
"""
function BeForEpochs(force::Matrix{Float64},
	sampling_rate::Real;
	zero_sample::Int = 1,
	design::Union{Nothing, DataFrame} = nothing,
	baseline::Union{Nothing, Vector{Float64}} = nothing,
	meta::Union{Nothing, Dict{String, Any}} = nothing)

	epoch = 1:size(force, 1)
	t = make_time_stamps(size(force, 2), sampling_rate; zero_sample)
	force_dimarray = DimArray(force, (epoch = epoch, time = t))
	return BeForEpochs(force_dimarray, sampling_rate, design, baseline, meta)
end

function BeForEpochs(force::DimArray{Float64, 2},
	sampling_rate::Real;
	design::Union{Nothing, DataFrame} = nothing,
	baseline::Union{Nothing, Vector{Float64}} = nothing,
	meta::Union{Nothing, Dict{String, Any}} = nothing)

	if isnothing(baseline)
		baseline = Float64[]
	end
	if isnothing(design)
		design = DataFrame()
	end
	if isnothing(meta)
		meta = Dict{String, Any}()
	end
	return BeForEpochs(force, sampling_rate, design, baseline, meta)
end

Base.propertynames(::BeForEpochs) = (:dat, :sampling_rate, :design, :baseline,
	:zero_sample, :n_samples, :meta, :n_epochs, :is_baseline_adjusted)
function Base.getproperty(x::BeForEpochs, s::Symbol)
	if s === :n_epochs
		return size(x.dat, 1)
	elseif s === :is_baseline_adjusted
		return length(x.baseline) > 0
	elseif s === :n_samples
		return size(x.dat, 2)
	elseif s === :zero_sample
		return findfirst(x.dat.dims[2] .== 0)
	else
		return getfield(x, s)
	end
end

"""
	copy(fe::BeForEpochs)

Return a deep copy of `fe`, including copies of the force data, design DataFrame,
baseline vector, and metadata dictionary.

Returns
-------
A new `BeForEpochs`.
"""
function Base.copy(fe::BeForEpochs)
	return BeForEpochs(copy(fe.dat), fe.sampling_rate, copy(fe.design),
		copy(fe.baseline), copy(fe.meta))
end

function Base.show(io::IO, mime::MIME"text/plain", x::BeForEpochs)
	txt = "BeForEpochs"
	if length(x.baseline) > 0
		txt *= " (baseline adjusted)"
	end
	print(io, txt)
	println(io, "  $(x.n_epochs) epochs")
	println(io, "  $(x.n_samples) samples, sampling rate: $(x.sampling_rate), zero sample: $(x.zero_sample)")
	println(io, "  metadata")
	for (k, v) in x.meta
		println(io, "  - $k: $v")
	end
	if nrow(x.design) > 0
		print(io, "  Design: $(names(x.design))")
	else
		print(io, "  No design information")
	end
end

"""
	forces(d::BeForEpochs)

Return the epoch-by-time force data of `d` as a `DimArray` with shape
`(n_epochs, n_samples)`.

Returns
-------
A `DimArray{Float64,2}`.

See also: [`forces(::BeForRecord)`](@ref), [`adjust_baseline!`](@ref)
"""
forces(d::BeForEpochs) = d.dat

"""
	time_stamps(d::BeForEpochs)

Return the epoch time axis (in ms).

The returned vector corresponds to the `time` dimension of `d.dat` and is shared
across all epochs.

Returns
-------
The epoch time axis as an abstract vector-like object (in ms).

See also: [`forces`](@ref), [`find_samples_by_time`](@ref)
"""
time_stamps(d::BeForEpochs) = dims(d.dat, 2)

## processing
"""
	extract_epochs(d::BeForRecord, column;
		zero_samples=nothing, zero_times=nothing,
		n_samples, n_samples_before=0,
		design=nothing, suppress_warnings=false)

Extract fixed-length epochs from a continuous `BeForRecord`.

Exactly one of `zero_samples` or `zero_times` must be provided to define the epoch
onset positions.

Arguments
---------
- `d`: Source `BeForRecord`.
- `column`: Column name (`Symbol`, `String`) or integer index of the force channel
  to extract.

Keyword Arguments
-----------------
- `zero_samples`: Integer sample indices (1-based) at which each epoch starts at
  time zero.
- `zero_times`: Time values (in ms) corresponding to epoch time zero. These are
	converted to sample indices with [`find_samples_by_time`](@ref).
- `n_samples`: Number of samples to extract *after* (and including) the zero sample.
- `n_samples_before`: Number of samples to extract *before* the zero sample.
  Defaults to 0. The zero sample in the returned `BeForEpochs` is
  `n_samples_before + 1`.
- `design`: Optional DataFrame with one row per epoch containing trial metadata.
- `suppress_warnings`: If `true`, suppress warnings about incomplete epochs that
  extend beyond the end of the recording (missing samples are zero-padded).
  Defaults to `false`.

Returns
-------
A `BeForEpochs` with `length(zero_samples)` rows and
`n_samples_before + n_samples` columns.

See also: [`BeForEpochs`](@ref), [`adjust_baseline!`](@ref),
[`find_samples_by_time`](@ref), [`forces(::BeForRecord)`](@ref)
"""
function extract_epochs(d::BeForRecord,
	column::Union{Symbol, String, Integer};
	zero_samples::Union{Nothing, AbstractVector{<:Integer}} = nothing,
	zero_times::Union{Nothing, AbstractVector{<:Real}} = nothing,
	n_samples::Integer,
	n_samples_before::Integer,
	design::Union{Nothing, DataFrame} = nothing,
	suppress_warnings::Bool = false,
)
	(isnothing(zero_samples) && isnothing(zero_times)) && throw(
		ArgumentError("Define either the samples or times where to extract the epochs " *
					  "(i.e. parameter zero_samples or zero_time)"))

	(isnothing(zero_samples) != isnothing(zero_times)) || throw(
		ArgumentError("Define only one the samples or times where to extract the epochs, " *
					  "not both."))

	if !isnothing(zero_times)
		return extract_epochs(d, column; zero_samples = find_samples_by_time(zero_times, d),
			n_samples, n_samples_before, design, suppress_warnings)
	end

	dat = forces(d, column)
	samples_fd = d.n_samples # samples for data
	n_epochs = length(zero_samples)
	ncol = n_samples_before + n_samples
	force_mtx = Matrix{Float64}(undef, n_epochs, ncol)
	for (r, sz) in enumerate(zero_samples)
		from = sz - n_samples_before
		if from < samples_fd
			to = sz + n_samples - 1
			if to > samples_fd
				suppress_warnings && @warn "extract epochs: force epoch " * string(r) *
										   " is incomplete, " * string(to - samples_fd) *
										   " samples missing."
				force_mtx[r, :] .= vcat(dat[from:samples_fd], zeros(Float64, to - samples_fd))
			else
				force_mtx[r, :] .= dat[from:to]
			end
		end
	end

	if isnothing(design)
		design = DataFrame()
	end
	meta = Dict{String, Any}("record meta" => copy(d.meta))

	return BeForEpochs(force_mtx, d.sampling_rate; design = copy(design),
		baseline = Float64[], zero_sample = n_samples_before + 1, meta = meta)
end;

"""
	adjust_baseline!(d::BeForEpochs, baseline_window::UnitRange{<:Integer})

Subtract a per-epoch baseline from the force data in-place.

The baseline for each epoch is computed as the mean of the samples in
`baseline_window` (column indices into `d.dat`). If a previous baseline correction
has already been applied, the original (uncorrected) data are first restored before
recomputing the new baseline.

The per-epoch baseline values are stored in `d.baseline` so the correction can be
undone or tracked.

Returns `d` (mutated in place).

Returns
-------
The mutated `BeForEpochs` object `d`.

See also: [`extract_epochs`](@ref), [`BeForEpochs`](@ref)
"""
function adjust_baseline!(d::BeForEpochs, baseline_window::UnitRange{<:Integer})
	if length(d.baseline) > 0
		dat = d.dat .+ d.baseline
	else
		dat = d.dat
	end
	bsl = mean(dat[:, baseline_window], dims = 2)
	d.dat[:, :] .= dat .- bsl
	if length(d.baseline) > 0
		d.baseline[:] .= bsl
	else
		append!(d.baseline, bsl)
	end
	return d
end

"""
	vcat(d::BeForEpochs, other::BeForEpochs)

Concatenate two `BeForEpochs` objects along the epoch dimension.

Both objects must have matching `n_samples`, `sampling_rate`, `zero_sample`, baseline
adjustment state, and design column names. The metadata of `d` (the first argument)
is used for the result; the metadata of `other` is discarded.

Returns
-------
A new `BeForEpochs` containing all epochs from `d` followed by `other`.

See also: [`subset`](@ref)
"""
function Base.vcat(d::BeForEpochs, other::BeForEpochs)

	if other.n_samples != d.n_samples
		throw(ArgumentError("Number of samples per epoch must match (got $(d.n_samples) and $(other.n_samples))."))
	end
	if other.sampling_rate != d.sampling_rate
		throw(ArgumentError("Sampling rates must match (got $(d.sampling_rate) and $(other.sampling_rate))."))
	end
	if other.zero_sample != d.zero_sample
		throw(ArgumentError("Zero sample indices must match (got $(d.zero_sample) and $(other.zero_sample))."))
	end
	if other.is_baseline_adjusted != d.is_baseline_adjusted
		throw(ArgumentError("One data structure is baseline adjusted, the other not."))
	end
	if any(names(other.design) .!= names(d.design))
		throw(ArgumentError("Design column names are not the same."))
	end
	baseline = vcat(d.baseline, other.baseline)
	design = vcat(d.design, other.design)
	return BeForEpochs(vcat(d.dat, other.dat), d.sampling_rate; design,
		baseline, zero_sample = d.zero_sample, meta = d.meta)
end


"""
	subset(fe::BeForEpochs, rows)
	subset(fe::BeForEpochs, args...)

Return a subset of `fe` containing only the selected epochs.

**Row-index form** – `rows` is a vector or tuple of integer indices (1-based) specifying
which epochs to keep.

**DataFrames form** – `args...` are passed directly to `DataFrames.subset` applied to
`fe.design`. Epochs whose design rows satisfy the condition are retained. Requires
`fe.design` to be non-empty.

Both forms copy the relevant slice of `fe.dat`, the `baseline` vector, and the design
DataFrame.

Returns
-------
A new `BeForEpochs` containing only the selected epochs.

See also: [`vcat`](@ref), [`extract_epochs`](@ref)
"""
function DataFrames.subset(fe::BeForEpochs, rows::Base.AbstractVecOrTuple{Integer})
	force = fe.dat[rows, :]
	if length(fe.baseline) > 0
		bsln = fe.baseline[rows]
	else
		bsln = copy(fe.baseline)
	end
	subset_design = fe.design[rows, :]
	return BeForEpochs(force, fe.sampling_rate; design = subset_design,
		baseline = bsln, zero_sample = fe.zero_sample, meta = copy(fe.meta))
end

function DataFrames.subset(fe::BeForEpochs, args...)
	df = copy(fe.design)
	df.row_xxx .= 1:nrow(df)
	df = subset(df, args...)
	return subset(fe, df[:, :row_xxx])
end

### helper functions
"""
	find_samples_by_time(times::Real, d::BeForEpochs)
	find_samples_by_time(times::AbstractVector{<:Real}, d::BeForEpochs)

Map one or more time values (in ms) to sample indices on the epoch time axis.

For each queried time, the index of the first sample whose time stamp is greater
than or equal to that value is returned.

Returns a single integer if `times` is a single value, or a vector of integers if
`times` is a vector.

Returns
-------
Returns an integer index for scalar input, or a vector of indices for vector input.

See also: [`time_stamps`](@ref), [`extract_epochs`](@ref)
"""
find_samples_by_time(times::Union{Real, AbstractVector{<:Real}}, d::BeForEpochs) =
	find_larger_or_equal(time_stamps(d).val, times)
