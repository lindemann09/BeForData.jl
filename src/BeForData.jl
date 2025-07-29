module BeForData

using Statistics: mean
using DataFrames
using DSP: Lowpass, filtfilt, Butterworth, digitalfilter

export BeForRecord,
        forces,
        time_stamps,
        split_sessions,
        session_range,
        add_session,
        vcat,
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

## Arrow (using Arrow)
function write_feather end
export write_feather

end
