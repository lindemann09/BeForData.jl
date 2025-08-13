module FilteringExt

using DSP
using BeForData

export filtfilt_record,
        lowpass_filter

function BeForData.filtfilt_record(coef::FilterCoefficients, rec::BeForRecord)::BeForRecord

	rtn = copy(rec)
	for r in session_range(rtn)
		for c in rtn.force_cols
			rtn.dat[r, c] = filtfilt(coef, rtn.dat[r, c])
		end
	end
	return rtn
end

function BeForData.filtfilt_record(b::AbstractVector, a::AbstractVector, rec::BeForRecord)::BeForRecord

	rtn = copy(rec)
	for r in session_range(rtn)
		for c in rtn.force_cols
			rtn.dat[r, c] = filtfilt(b, a, rtn.dat[r, c])
		end
	end
	return rtn
end

function BeForData.lowpass_filter(rec::BeForRecord;
	cutoff::Real,
	order::Integer)

	butter_flt = digitalfilter(Lowpass(cutoff), Butterworth(order);
		fs = rec.sampling_rate)
	rtn = filtfilt_record(butter_flt, rec)

	rtn.meta["filter"] = "butterworth: cutoff="*string(cutoff)*", order="*string(order)
	return rtn
end

function BeForData.lowpass_filter(fe::BeForEpochs;
	cutoff::Real,
	order::Integer = 4,
	center_data::Bool = true,
	suppress_warning::Bool = false,
) # FIXME old method, maybe remove center_data
	suppress_warning || @warn "It's suggested to filter the data (i.e. BeForRecord) " *
							  "before creating epochs, because each epoch will be filter individually. " *
							  "This might causes artifacts"

	rtn = copy(fe)
	sampling_rate = rtn.sampling_rate
	for row in eachrow(rtn.dat)
		row[:] = lowpass_filter(vec(row);
			sampling_rate, cutoff, order, center_data)
	end
	return rtn
end;

end # module