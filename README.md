# BeForData.jl

[![Julia](https://img.shields.io/badge/Julia-1.10%2B-blue)](https://julialang.org)
[![GitHub license](https://img.shields.io/github/license/lindemann09/befordata.jl)](https://github.com/lindemann09/befordata.jl/blob/master/LICENSE)
[![Build Status](https://github.com/lindemann09/BeForData.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/lindemann09/BeForData.jl/actions/workflows/CI.yml?query=branch%3Amain)

**BeForData** is a Julia package for working with behavioural response force data.
It provides two core data structures — `BeForRecord` for continuous recordings and
`BeForEpochs` for trial-based epoch data — together with tools for preprocessing,
epoch extraction, baseline correction, and file I/O.

**Author:** Oliver Lindemann, Erasmus University Rotterdam

> A [Python implementation](https://github.com/lindemann09/befordata) is also available.

---

## Overview

Force platform recordings are typically collected as one long continuous signal,
sometimes spanning multiple experimental sessions or blocks. **BeForData** separates
this workflow into two stages:

1. **`BeForRecord`** – holds the raw, continuous time-series with one or more sessions,
   optional time stamps, and arbitrary metadata.
2. **`BeForEpochs`** – holds the segmented, trial-aligned force matrix extracted from a
   `BeForRecord`, along with an optional trial design table and baseline information.

Optional extensions add support for reading/writing [Apache Arrow](https://arrow.apache.org/)
(Feather) files, applying [DSP](https://github.com/JuliaDSP/DSP.jl) filters, and
loading [XDF](https://github.com/xdf-modules/xdf-Julia) streams.

---

## Installation

```julia
using Pkg
Pkg.add("BeForData")
```

Optional extension packages can be added independently:

```julia
Pkg.add("Arrow")   # file I/O
Pkg.add("DSP")     # filtering
Pkg.add("XDF")     # XDF stream loading
```

---

## Core Types

### `BeForRecord`

A continuous force recording with one or more sessions.

```julia
using DataFrames, BeForData

# Create from a DataFrame
df = DataFrame(time = 0:0.5:999.5, Fz = randn(2000))
rec = BeForRecord(df, 2000.0; time_column = "time")

# Access data
forces(rec)           # DataFrame of force channels
time_stamps(rec)      # time vector in ms

# Multi-session support
rec2 = add_session(rec, df)     # append a second session
sessions = split_sessions(rec2) # split back into individual records
```

Key properties: `n_samples`, `n_forces`, `sampling_rate`, `sessions`, `meta`.

### `BeForEpochs`

A trial-by-sample force matrix extracted from a `BeForRecord`.

```julia
# Extract epochs around event onsets (sample indices)
onsets = [100, 400, 700, 1000]
epochs = extract_epochs(rec, "Fz";
    zero_samples    = onsets,
    n_samples       = 200,
    n_samples_before = 50)

# Or use time stamps (ms) directly
epochs = extract_epochs(rec, "Fz";
    zero_times       = [50.0, 200.0, 350.0, 500.0],
    n_samples        = 200,
    n_samples_before = 50)

# Baseline correction using samples before time zero
adjust_baseline!(epochs, 1:50)

# Attach trial design information
using DataFrames
design = DataFrame(condition = ["A","B","A","B"])
epochs = extract_epochs(rec, "Fz"; zero_samples = onsets,
    n_samples = 200, n_samples_before = 50, design = design)

# Subset by row indices or design conditions
subset(epochs, [1, 3])                         # rows 1 and 3
subset(epochs, :condition => x -> x .== "A")  # condition A only
```

Key properties: `n_epochs`, `n_samples`, `sampling_rate`, `zero_sample`,
`is_baseline_adjusted`, `design`, `meta`.

---

## Preprocessing

```julia
# Scale all force channels (e.g. convert raw sensor units to Newtons)
scale_force!(rec, 0.00981)

# Smooth with a centred moving average
smoothed = moving_average(rec, 20)   # 20-sample window

# Remove a slow drift by subtracting a wide moving average
detrended = detrend(rec, 500)        # 500-sample window
```

### Filtering (requires `DSP`)

```julia
using DSP
# Butterworth low-pass filter
filtered = lowpass_filter(rec; cutoff = 10.0, order = 4)

# Apply arbitrary DSP filter coefficients
coef = digitalfilter(Lowpass(10.0), Butterworth(4); fs = rec.sampling_rate)
filtered = filtfilt_record(coef, rec)
```

---

## File I/O (requires `Arrow`)

```julia
using Arrow

# Save and reload a continuous recording
write_feather(rec, "recording.feather")
rec2 = BeForRecord(Arrow.Table("recording.feather"))

# Save and reload epoch data
write_feather(epochs, "epochs.feather")
epochs2 = BeForEpochs(Arrow.Table("epochs.feather"))
```

---

## Loading XDF Streams (requires `XDF`)

```julia
using XDF
streams = load_xdf("experiment.xdf")

# Inspect a stream
xdf_channel_info(streams, "ForcePlate")

# Convert directly to BeForRecord
rec = BeForRecord(streams, "ForcePlate", 1000.0)
```

---

## Citation

If you use BeForData.jl in your research, please cite it as:

```
Lindemann, O. (2025). BeForData.jl: A Julia package for behavioural response force data.
Erasmus University Rotterdam. https://github.com/lindemann09/BeForData.jl
```

Or in BibTeX:

```bibtex
@software{lindemann2025beforedata,
  author    = {Lindemann, Oliver},
  title     = {{BeForData.jl}: A {Julia} package for behavioural response force data},
  year      = {2025},
  publisher = {GitHub},
  institution = {Erasmus University Rotterdam},
  url       = {https://github.com/lindemann09/BeForData.jl}
}
```

---

## License

(c) Oliver Lindemann — see [LICENSE](LICENSE) for details.
