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

	function BeForEpochs(force::Matrix{Float64}, sampling_rate::Real, design::DataFrame,
		baseline::Vector{Float64}, zero_sample::Int)
		lf = size(force, 1)
		lb = length(baseline)
		lf == lb || throw(
			ArgumentError(
				"Number of rows of force ($(lf)) must match the length of baseline ($(lb)).",
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


Base.propertynames(::BeForEpochs) = (:dat, :sampling_rate, :design, :baseline,
	:zero_sample, :n_samples, :n_epochs)
function Base.getproperty(x::BeForEpochs, s::Symbol)
	if s === :n_epochs
		return size(x.dat, 1)
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
	print(io, "  Design: $(names(x.design))")
end

## processing
"""
	extract_epochs(d::BeForRecord, column::Union{Symbol, String};
		zero_samples::AbstractVector{<:Integer},
		n_samples::Integer,
        n_samples_before::Integer,
        design::Union{Nothing, DataFrame}=nothing)

        Parameter
        ---------
		d: BeForRecord
			the data
    	column: str
            name of column containing the force data to be used
        zero_samples: List[int]
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
	zero_samples::AbstractVector{<:Integer},
	n_samples::Integer,
	n_samples_before::Integer,
	design::Union{Nothing, DataFrame}=nothing
)
	dat  = d.dat[:, column]
	samples_fd = nrow(d.dat)
	n_epochs = length(zero_samples)
	ncol = n_samples_before + n_samples
	force_mtx = Matrix{Float64}(undef, n_epochs, ncol)
	for (r, i) in enumerate(zero_samples)
        f = i - n_samples_before
        if f < samples_fd
            t = i + n_samples - 1
            if t > samples_fd
                @warn string("extract epochs: last force epoch is incomplete, ",
                            t-samples_fd, " samples missing.")
                force_mtx[r, :] .= vcat(dat[f:samples_fd], zeros(Float64, t - samples_fd))
            else
                force_mtx[r, :] .= dat[f:t]
            end
        end
    end

	if isnothing(design)
		design = DataFrame()
	end
	return BeForEpochs(force_mtx, d.sampling_rate, copy(design),
		zeros(Float64, n_epochs), n_samples_before + 1)
end;

"""
	adjust_baseline!(d::BeForEpochs, baseline_window::UnitRange{<:Integer})

TODO
"""
function adjust_baseline!(d::BeForEpochs, baseline_window::UnitRange{<:Integer})
	dat = d.dat .+ d.baseline
	bsl = mean(d.dat[:, baseline_window], dims = 2)
	d.dat[:, :] .= dat .- bsl
	d.baseline[:] .= bsl
	return d
end

