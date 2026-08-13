const ColumnIndex = Union{Symbol, AbstractString}
const TOptionalRowSelect = Union{Nothing, BitVector, Vector{<:Integer}}

"""
    peak_differences(fe::BeForEpochs, window_size::Integer)
	peak_differences(force_mtx::AbstractMatrix{T}, window_size::Integer) where T <: AbstractFloat

Vector of peak differences for each row in `force_mtx`. The peak difference is defined
	as the maximum absolute difference between two samples that are `window_size` samples apart.
"""
peak_differences(fe::BeForEpochs, window_size::Integer) = peak_differences(fe.dat, window_size)
function peak_differences(force_mtx::AbstractMatrix{T}, window_size::Integer) where T <: AbstractFloat
	# peak difference per row
	nc = size(force_mtx, 2)
	rtn = T[]
	for row in eachrow(force_mtx)
		peak = 0.0
		for i in 1:(nc-window_size)
			@inbounds diff = abs(row[i+window_size] - row[i])
			if peak < diff
				peak = diff
			end
		end
		push!(rtn, peak)
	end
	return rtn
end;

"""
	epoch_rejection_ids(fe::BeForEpochs; force_range::UnitRange, max_difference::Integer,
		max_diff_windows_size::Integer)

Return BitVector indicating 'good' epochs
"""
function epoch_rejection_ids(fe::BeForEpochs;
	force_range::UnitRange, # criteria for good trial
	max_difference::Integer, # criteria for good trial
	max_diff_windows_size::Integer,
)
	min = minimum(fe)
	max = maximum(fe)
	peak_diff = peak_differences(fe.dat, max_diff_windows_size)
	good = min .>= force_range.start .&&
		   max .<= force_range.stop .&&
		   abs.(peak_diff) .<= max_difference
	return good
end

"""
	epoch_rejection(fe::BeForEpochs; force_range::UnitRange, max_difference::Integer,
		max_diff_windows_size::Integer)

BeForEpochs fitting the criteria for 'good' epochs
"""
function epoch_rejection(fe::BeForEpochs;
	force_range::UnitRange, # criteria for good trial
	max_difference::Integer, # criteria for good trial
	max_diff_windows_size::Integer,
)
	good = epoch_rejection_ids(fe; force_range, max_difference, max_diff_windows_size)
	return subset(fe, good)
end

function aggregate(fe::BeForEpochs,
	agg_fnc::Function,
	rows::TOptionalRowSelect,
	new_design::Union{DataFrame, DataFrameRow})

	if isnothing(rows)
		dat = agg_fnc(fe.dat, dims = 1)
		bsl = agg_fnc(fe.baseline)
	else
		dat = agg_fnc(fe.dat[rows, :], dims = 1)
		bsl = agg_fnc(fe.baseline[rows, :])
		if bsl isa AbstractMatrix
			bsl = first(bsl)
		end
	end

	if new_design isa DataFrameRow
		new_design = DataFrame(new_design)
	elseif nrow(new_design) > 1
		throw(ArgumentError("Design has to be a DataFrame with one or no rows or DataFrameRow."))
	end

	if !(bsl isa Vector)
		bsl = [bsl]
	end
	meta = copy(fe.meta)
	meta["agg_fnc"] = string(agg_fnc)
	return BeForEpochs(dat, fe.sampling_rate;
		baseline = bsl,
		design=new_design, meta)
end

aggregate(fe::BeForEpochs, agg_fnc::Function, rows::TOptionalRowSelect) = aggregate(fe, agg_fnc, rows, DataFrame())
aggregate(fe::BeForEpochs, agg_fnc::Function, new_design::Union{DataFrame, DataFrameRow}) = aggregate(fe, agg_fnc, nothing, new_design)

"""
	aggregate(fe::BeForEpochs, agg_fnc::Function rows::Union{Nothing, BitVector, Vector{<:Integer}}, design::Union{DataFrame, DataFrameRow})
	aggregate(fe::BeForEpochs, agg_fnc::Function, rows::Union{Nothing, BitVector, Vector{<:Integer}})
	aggregate(fe::BeForEpochs, agg_fnc::Function, new_design::Union{DataFrame, DataFrameRow})
	aggregate(fe::BeForEpochs, agg_fnc::Function;
			condition::ColumnIndex = :all,
			subject_id::Union{Nothing, ColumnIndex} = nothing)
BeForEpochs object with aggregated data. The aggregation is performed
using the function `agg_fnc` (e.g., `mean`, `median` for `Statistics.jl`). The aggregation can be
done across all epochs, or grouped by a condition and/or subject ID.
"""
function aggregate(
	fe::BeForEpochs,
	agg_fnc::Function;
	condition::Union{Nothing, ColumnIndex} = :all, # condition column name
	subject_id::Union{Nothing, ColumnIndex} = nothing,
)
	if isnothing(condition)
		condition = :all
	end

	if condition == :all
		if isnothing(subject_id)
			return aggregate(fe, agg_fnc, nothing)
		end
		conditions = nothing
	else
		conditions = fe.design[:, condition]
	end
	rtn_array = BeForEpochs[]

	# aggregate per subject
	if isnothing(subject_id)
		for cond in unique(conditions)
			ids = findall(conditions .== cond)
			design = DataFrame(condition => cond)
			push!(rtn_array, aggregate(fe, agg_fnc, ids, design))
		end
	else
		subject_ids = fe.design[:, subject_id]
		for sid in unique(subject_ids)
			subj_rows = subject_ids .== sid
			if isnothing(conditions)
				design = DataFrame(:subject_id => sid)
				push!(rtn_array, aggregate(fe, agg_fnc, subj_rows, design))
			else
				for cond in unique(conditions)
					design = DataFrame(:subject_id => sid, condition => cond)
					ids = findall(subj_rows .&& conditions .== cond)
					push!(rtn_array, aggregate(fe, agg_fnc, ids, design))
				end
			end
		end
	end
	rtn = reduce(vcat, rtn_array)
	rtn.meta["agg_fnc"] = string(agg_fnc)
	return rtn
end;

function Base.diff(fe::BeForEpochs; dims::Integer)
    mtx = fe.dat
    if dims == 1
        z = zeros(Float64, 1, size(mtx, 2))
        dat = vcat(z, diff(mtx; dims=1))
    elseif dims == 2
        z = zeros(Float64, size(mtx, 1), 1)
        dat = hcat(z, diff(mtx; dims=2))
    else
        throw(ArgumentError("dims has to be 1 or 2 and not $dims"))
    end
    return BeForEpochs(dat, fe.sampling_rate; design=fe.design, baseline=fe.baseline,
            zero_sample=fe.zero_sample,  meta=copy(fe.meta))
end;


"""
    minimum(fe:BeForEpochs)

Minimum of each epoch.
"""
Base.minimum(fe::BeForEpochs) = return vec(minimum(fe.dat, dims=2))

"""
    maximum(fe:BeForEpochs)

Maximum of each epoch.
"""
Base.maximum(fe::BeForEpochs) = return vec(maximum(fe.dat, dims=2))
