module BeForData

using Arrow
using DataFrames
using DSP
using Statistics: mean

export BeForRecord,
        forces,
        time_stamps,
        write_feather,
        session_rows,
        add_session,
        find_samples_by_time

export BeForEpochs,
        extract_epochs,
        adjust_baseline!

export scale_force!,
        lowpass_filter,
        moving_average,
        detrend,
        detect_sessions

include("record.jl")
include("epochs.jl")
include("preprocessing.jl")

end
