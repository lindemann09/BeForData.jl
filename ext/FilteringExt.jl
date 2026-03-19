module FilteringExt

using DSP
using BeForData

export filtfilt_record,
        lowpass_filter

"""
	filtfilt_record(coef::FilterCoefficients, rec::BeForRecord) -> BeForRecord

Apply the DSP filter `coef` to every force channel in `rec` using zero-phase
forward-backward filtering (`filtfilt`). Each session is filtered independently.

Returns a new `BeForRecord`; the original is not modified.

See also: [`lowpass_filter`](@ref)
"""
function BeForData.filtfilt_record(coef::FilterCoefficients, rec::BeForRecord)::BeForRecord

	rtn = copy(rec)
	for r in session_range(rtn)
		for c in rtn.force_cols
			rtn.dat[r, c] = filtfilt(coef, rtn.dat[r, c])
		end
	end
	return rtn
end

"""
	filtfilt_record(b::AbstractVector, a::AbstractVector, rec::BeForRecord) -> BeForRecord

Apply a filter specified by numerator coefficients `b` and denominator coefficients
`a` to every force channel in `rec` using zero-phase forward-backward filtering.
Each session is filtered independently.

Returns a new `BeForRecord`; the original is not modified.

See also: [`lowpass_filter`](@ref)
"""
function BeForData.filtfilt_record(b::AbstractVector, a::AbstractVector, rec::BeForRecord)::BeForRecord

	rtn = copy(rec)
	for r in session_range(rtn)
		for c in rtn.force_cols
			rtn.dat[r, c] = filtfilt(b, a, rtn.dat[r, c])
		end
	end
	return rtn
end

"""
	lowpass_filter(rec::BeForRecord; cutoff::Real, order::Integer) -> BeForRecord

Apply a Butterworth low-pass filter to every force channel in `rec`.

The filter is designed with the given `cutoff` frequency (in Hz, relative to
`rec.sampling_rate`) and polynomial `order`, then applied via zero-phase
forward-backward filtering. Filter parameters are stored in the metadata of the
returned record.

Returns a new `BeForRecord`; the original is not modified.

See also: [`filtfilt_record`](@ref)
"""
function BeForData.lowpass_filter(rec::BeForRecord;
	cutoff::Real,
	order::Integer)

	butter_flt = digitalfilter(Lowpass(cutoff), Butterworth(order);
		fs = rec.sampling_rate)
	rtn = filtfilt_record(butter_flt, rec)

	rtn.meta["filter"] = "butterworth: cutoff="*string(cutoff)*", order="*string(order)
	return rtn
end

### DEPRECATED METHODS

"""
	lowpass_filter(fe::BeForEpochs; cutoff::Real, order::Integer=4,
		suppress_warning::Bool=false) -> BeForEpochs

!!! warning "Deprecated"
    Filtering `BeForEpochs` directly is deprecated. Apply [`lowpass_filter`](@ref)
    to the source `BeForRecord` *before* extracting epochs to avoid filter edge
    artifacts at epoch boundaries.

Apply a Butterworth low-pass filter independently to each epoch row in `fe`.

Returns a new `BeForEpochs`; the original is not modified.
"""
function BeForData.lowpass_filter(fe::BeForEpochs;
	cutoff::Real,
	order::Integer = 4,
	suppress_warning::Bool = false,
)
	suppress_warning || @warn "It's suggested to filter the data (i.e. BeForRecord) " *
						  "before creating epochs, because otherwise each epoch will be filtered individually. " *
						  "This might causes artifacts."

	rtn = copy(fe)
	flt = digitalfilter(Lowpass(cutoff), Butterworth(order);
				fs = rtn.sampling_rate)
	for row in eachrow(rtn.dat)
		dat = vec(row)
		row[:] = filtfilt(flt, dat); # filtfilt(flt, dat .- dat[1]) .+ dat[1] # filter centred data
	end
	return rtn
end;

end # module
