"""
	BeForEpochs

TODO
"""

struct BeForEpochs
	dat::Matrix{Float64}
	sampling_rate::Real
	design::DataFrame
	baseline::Vector{Float64}
	zero_sample::Int

	function BeForEpochs(force::Matrix{Float64},
						sampling_rate::Real,
						design::DataFrame,
						baseline::Vector{Float64},
						zero_sample::Int)
		lf = size(force, 1)
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
		return new(force, sampling_rate, design, baseline, zero_sample)
	end
end;

function BeForEpochs(force::Matrix{Float64},
					sampling_rate::Real;
					design::Union{Nothing, DataFrame} = nothing,
					baseline::Union{Nothing, Vector{Float64}} = nothing,
					zero_sample::Int = 0)
	if isnothing(baseline)
		baseline = Float64[]
	end
	if isnothing(design)
		design = DataFrame()
	end
	return BeForEpochs(force, sampling_rate, design,
					baseline, zero_sample)

end


Base.propertynames(::BeForEpochs) = (:dat, :sampling_rate, :design, :baseline,
	:zero_sample, :n_samples, :n_epochs, :is_baseline_adjusted)
function Base.getproperty(x::BeForEpochs, s::Symbol)
	if s === :n_epochs
		return size(x.dat, 1)
	elseif s === :is_baseline_adjusted
		return length(x.baseline) > 0
	elseif s === :n_samples
		return size(x.dat, 2)
	else
		return getfield(x, s)
	end
end

"""
	copy(fe::BeForEpochs)

TODO
"""
function Base.copy(fe::BeForEpochs)
	return BeForEpochs(copy(fe.dat), fe.sampling_rate, copy(fe.design),
		copy(fe.baseline), fe.zero_sample)
end

function Base.show(io::IO, mime::MIME"text/plain", x::BeForEpochs)
	println(io, "BeForEpochs")
	println(io, "  $(x.n_epochs) epochs")
	println(io, "  $(x.n_samples) samples, sampling rate: $(x.sampling_rate), zero sample: $(x.zero_sample)")
	if nrow(x.design) > 0
		print(io, "  Design: $(names(x.design))")
	else
		print(io, "  No design information")
	end
end

forces(d::BeForEpochs) = d.dat

## processing
"""
	extract_epochs(d::BeForRecord, column::Union{Symbol, String};
		zero_samples::Union{Nothing, AbstractVector{<:Integer}} = nothing,
		zero_times::Union{Nothing, AbstractVector{<:Real}} = nothing,
		n_samples::Integer,
        n_samples_before::Integer,
        design::Union{Nothing, DataFrame}=nothing)

        Parameter
        ---------
		d: BeForRecord
			the data
    	column: str
            name of column containing the force data to be used
        zero_samples: List[int], optional
            zero sample that define the epochs
        zero_times: List[int], optional
            zero sample that define the epochs
        n_samples: int
            number of samples to be extract (from zero sample on)
        n_samples_before: int, optional
            number of samples to be extracted before the zero sample (default=0)

        design: pd.DataFrame, optional
            design information

        Note
        ----
        use `find_times` to detect zero samples with time-based

"""
function extract_epochs(d::BeForRecord,
	column::Union{Symbol, String, Int};
	zero_samples::Union{Nothing, AbstractVector{<:Integer}} = nothing,
	zero_times::Union{Nothing, AbstractVector{<:Real}} = nothing,
	n_samples::Integer,
	n_samples_before::Integer,
	design::Union{Nothing, DataFrame}=nothing
)
	(isnothing(zero_samples) && isnothing(zero_times)) && throw(
		ArgumentError("Define either the samples or times where to extract the epochs " *
						"(i.e. parameter zero_samples or zero_time)"))

	(isnothing(zero_samples) != isnothing(zero_times)) || throw(
		ArgumentError("Define only one the samples or times where to extract the epochs, " *
						"not both."))

	if !isnothing(zero_times)
		ts = time_stamps(d)
		zero_samples = [_find_larger_or_equal(zt, ts) for zt in zero_times]
		return extract_epochs(d, column; zero_samples, n_samples,
					n_samples_before, design)
	end

	dat  = d.dat[:, column]
	samples_fd = d.n_samples # samples for data
	n_epochs = length(zero_samples)
	ncol = n_samples_before + n_samples
	force_mtx = Matrix{Float64}(undef, n_epochs, ncol)
	for (r, sz) in enumerate(zero_samples)
        from = sz - n_samples_before
        if from < samples_fd
            to = sz + n_samples - 1
            if to > samples_fd
                @warn string("extract epochs: last force epoch is incomplete, ",
                            to-samples_fd, " samples missing.")
                force_mtx[r, :] .= vcat(dat[from:samples_fd], zeros(Float64, to - samples_fd))
            else
                force_mtx[r, :] .= dat[from:to]
            end
        end
    end

	if isnothing(design)
		design = DataFrame()
	end
	return BeForEpochs(force_mtx, d.sampling_rate, copy(design),
						Float64[], n_samples_before + 1)
end;

"""
	adjust_baseline!(d::BeForEpochs, baseline_window::UnitRange{<:Integer})

TODO
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
	return BeForEpochs(vcat(d.dat, other.dat), d.sampling_rate, design,
				baseline, d.zero_sample)
end

### helper functions
function _find_larger_or_equal(needle::Real, sorted_array::AbstractVector{<:Real})
	cnt::Int = 0
	for x in sorted_array
		cnt = cnt + 1
		if x >= needle
			return cnt
		end
	end
	return nothing
end;
