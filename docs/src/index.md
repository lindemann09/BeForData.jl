# BeForData.jl Documentation

**BeForData** is a Julia package for working with behavioural response force data.
It provides two core data structures — `BeForRecord` for continuous recordings and
`BeForEpochs` for trial-based epoch data — together with tools for preprocessing,
epoch extraction, baseline correction, and file I/O.

(c) 2024 Oliver Lindemann, Erasmus University Rotterdam

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

## Citation

If you use BeForData.jl in your research, please cite it as:

> Lindemann, O. (2024). BeForData.jl: A Julia package for behavioural response force
> data. [Computer software]. JuliaHub. https://github.com/lindemann09/BeForData.jl

Or in BibTeX:

```bibtex
@software{lindemann2024beforedata,
  author    = {Lindemann, Oliver},
  title     = {{BeForData.jl}: A {Julia} package for behavioural response force data},
  year      = {2024},
  publisher = {JuliaHub},
  url       = {https://github.com/lindemann09/BeForData.jl}
}
```

## Python

A [Python implementation](https://github.com/lindemann09/befordata) of **BeForData** is also available.
