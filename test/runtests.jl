using Test
using JuMP
using TimerOutputs

using MIPVerify: set_log_level!
using MIPVerify: get_max_index, get_norm

@isdefined(TestHelpers) || include("TestHelpers.jl")

macro timed_testset(name::String, block)
    # copied from https://github.com/KristofferC/Tensors.jl/blob/master/test/runtests.jl#L8
    return quote
        @timeit "$($(esc(name)))" begin
            @testset "$($(esc(name)))" begin
                $(esc(block))
            end
        end
    end
end

@testset "MIPVerify" begin
    reset_timer!()
    set_log_level!("info")

    include("integration.jl")
    include("net_components.jl")
    include("utils.jl")
    include("models.jl")
    include("batch_processing_helpers.jl")

    @testset "get_max_index" begin
        @test_throws MethodError get_max_index([])
        @test get_max_index([3]) == 1
        @test get_max_index([3, 1, 4]) == 3
        @test get_max_index([3, 1, 4, 1, 5, 9, 2]) == 6
    end

    @testset "get_norm" begin
        @testset "real-valued arrays" begin
            xs = [1, -2, 3]
            @test get_norm(1, xs) == 6
            @test get_norm(2, xs) == sqrt(14)
            @test get_norm(Inf, xs) == 3
            @test_throws DomainError get_norm(3, xs)
        end
        @testset "variable-valued arrays" begin
            @testset "l1" begin
                m = TestHelpers.get_new_model()
                x1 = @variable(m, lower_bound = 1, upper_bound = 5)
                x2 = @variable(m, lower_bound = -8, upper_bound = -2)
                x3 = @variable(m, lower_bound = 3, upper_bound = 10)
                xs = [x1, x2, x3]
                n_1 = get_norm(1, xs)
                n_2 = get_norm(2, xs)
                n_inf = get_norm(Inf, xs)

                @objective(m, Min, n_1)
                optimize!(m)
                @test JuMP.objective_value(m) ≈ 6

                if Base.find_package("Gurobi") != nothing
                    # Skip these tests if Gurobi is not installed.
                    # Cbc does not solve problems with quadratic objectives
                    @objective(m, Min, n_2)
                    optimize!(m)
                    @test JuMP.objective_value(m) ≈ 14
                end

                @objective(m, Min, n_inf)
                optimize!(m)
                @test JuMP.objective_value(m) ≈ 3

                @test_throws DomainError get_norm(3, xs)
            end
        end
    end

    println()
    print_timer()
    println()
    println()
end
