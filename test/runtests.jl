using Aqua
using BeForData
using DataFrames
using DimensionalData
using Test

@testset "Aqua.jl" begin
	#Aqua.test_all(BeForData; ambiguities = false, stale_deps = false)
end

df = DataFrame(time = 0:0.5:999.5, Fz = randn(2000),
	Fx = 0:(2000-1),
	trigger = Int.(rand(2000) .> 0.9))
rec = BeForRecord(df, 2000.0; time_column = "time", force_cols = ["Fz", "Fx"])

@testset "Record" begin
	# Write your tests here.
	@test rec.n_samples == 2000
	@test rec.n_forces == 2
	@test rec.sampling_rate == 2000.0
	@test forces(rec) isa DimArray
	@test size(forces(rec)) == (2000, 2)
	@test length(time_stamps(rec)) == 2000
	@test copy(rec) !== rec

	rec2 = add_session(rec, df; reset_timestamps = true)     # append a second session
	@test rec2.n_samples == 4000
	sessions = split_sessions(rec2) # split back into individual records
	@test length(sessions) == 2
	@test all(s -> s.n_samples == 2000, sessions) == true
	@test DataFrame(rec) isa DataFrame
end

@testset "Epochs" begin
	ep = extract_epochs(rec, :Fx, zero_times = [120, 450, 870, 990], n_samples = 100, n_samples_before = 10)
	n_samples = 100 + 10
	@test ep.dat isa DimArray
	@test ep.n_samples == n_samples
	@test size(ep.dat) == (4, n_samples)
	@test ep.sampling_rate == 2000.0
	@test ep.zero_sample == 11
	@test time_stamps(ep)[20] == (1000.0 / ep.sampling_rate) * (20 - ep.zero_sample)
	@test ep.n_epochs == 4
	@test forces(ep)[1:2, 11] == [120.0, 450.0] .* 2
end
