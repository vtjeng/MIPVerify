using Test
using JuMP
using MIPVerify
using MIPVerify: check_size, increment!
@isdefined(TestHelpers) || include("../../TestHelpers.jl")

@testset "conv2d.jl" begin

    @testset "Conv2d" begin
        @testset "Base.show" begin
            filter = ones(3, 3, 2, 5)
            p = Conv2d(filter)
            io = IOBuffer()
            Base.show(io, p)
            @test String(take!(io)) == "Conv2d(2, 5, kernel_size=(3, 3), stride=(1, 1), padding=same)"
        end
        @testset "With Bias" begin
            @testset "Matched Size" begin
                out_channels = 5
                filter = ones(3, 3, 2, out_channels)
                bias = ones(out_channels)
                p = Conv2d(filter, bias)
                @test p.filter == filter
                @test p.bias == bias
            end
            @testset "Unmatched Size" begin
                filter_out_channels = 4
                bias_out_channels = 5
                filter = ones(3, 3, 2, filter_out_channels)
                bias = ones(bias_out_channels)
                @test_throws AssertionError Conv2d(filter, bias)
            end
        end
        @testset "No Bias" begin
            filter = ones(3, 3, 2, 5)
            p = Conv2d(filter)
            @test p.filter == filter
        end
        @testset "JuMP Variables" begin
            m = Model()
            filter_size = (3, 3, 2, 5)
            filter = map(_ -> @variable(m), CartesianIndices(filter_size))
            p = Conv2d(filter)
            @test p.filter == filter
        end
        @testset "check_size" begin
            filter = ones(3, 3, 2, 5)
            p = Conv2d(filter)
            @test check_size(p, (3, 3, 2, 5)) === nothing
            @test_throws AssertionError check_size(p, (3, 3, 2, 4))
        end
    end

    @testset "increment!" begin
        @testset "Real * Real" begin
            @test 7 == increment!(1, 2, 3)
        end
        @testset "JuMP.AffExpr * Real" begin
            m = TestHelpers.get_new_model()
            x = @variable(m, start=100)
            y = @variable(m, start=1)
            s = 5*x+3*y
            t = 3*x+2*y
            increment!(s, 2, t)
            @test getvalue(s)==1107
            increment!(s, t, -1)
            @test getvalue(s)==805
            increment!(s, x, 3)
            @test getvalue(s)==1105
            increment!(s, y, 2)
            @test getvalue(s)==1107
        end
    end

    @testset "conv2d" begin
        input_size = (1, 4, 4, 2)
        input = reshape(collect(1:prod(input_size)), input_size) .- 16
        filter_size = (3, 3, 2, 1)
        filter = reshape(collect(1:prod(filter_size)), filter_size) .- 9
        bias_size = (1, )
        bias = [1]
        true_output_raw = [
            225  381  405  285;
            502  787  796  532;
            550  823  832  532;
            301  429  417  249;      
        ]
        true_output = reshape(transpose(true_output_raw), (1, 4, 4, 1))
        p = Conv2d(filter, bias)
        @testset "Numerical Input, Numerical Layer Parameters" begin
            evaluated_output = MIPVerify.conv2d(input, p)
            @test evaluated_output == true_output
        end
        @testset "Numerical Input, Variable Layer Parameters" begin
            m = TestHelpers.get_new_model()
            filter_v = map(_ -> @variable(m), CartesianIndices(filter_size))
            bias_v = map(_ -> @variable(m), CartesianIndices(bias_size))
            p_v = Conv2d(filter_v, bias_v)
            output_v = MIPVerify.conv2d(input, p_v)
            @constraint(m, output_v .== true_output)
            solve(m)

            p_solve = MIPVerify.Conv2d(getvalue(filter_v), getvalue(bias_v))
            solve_output = MIPVerify.conv2d(input, p_solve)
            @test solve_output≈true_output
        end
        @testset "Variable Input, Numerical Layer Parameters" begin
            m = TestHelpers.get_new_model()
            input_v = map(_ -> @variable(m), CartesianIndices(input_size))
            output_v = MIPVerify.conv2d(input_v, p)
            @constraint(m, output_v .== true_output)
            solve(m)

            solve_output = MIPVerify.conv2d(getvalue(input_v), p)
            @test solve_output≈true_output
        end
    end

    @testset "conv2d with non-unit stride" begin
        input_size = (1, 6, 6, 2)
        input = reshape(collect(1:prod(input_size)), input_size) .- 36
        filter_size = (3, 3, 2, 1)
        filter = reshape(collect(1:prod(filter_size)), filter_size) .- 9
        bias_size = (1, )
        bias = [1]
        stride = 2
        true_output_raw = [
            1597  1615  1120;
            1705  1723  1120;
            903   879   513 ;
        ]
        true_output = reshape(transpose(true_output_raw), (1, 3, 3, 1))
        p = Conv2d(filter, bias, stride)
        @testset "Numerical Input, Numerical Layer Parameters" begin
            evaluated_output = MIPVerify.conv2d(input, p)
            @test evaluated_output == true_output
        end
        @testset "Numerical Input, Variable Layer Parameters" begin
            m = TestHelpers.get_new_model()
            filter_v = map(_ -> @variable(m), CartesianIndices(filter_size))
            bias_v = map(_ -> @variable(m), CartesianIndices(bias_size))
            p_v = Conv2d(filter_v, bias_v, stride)
            output_v = MIPVerify.conv2d(input, p_v)
            @constraint(m, output_v .== true_output)
            solve(m)

            p_solve = MIPVerify.Conv2d(getvalue(filter_v), getvalue(bias_v), stride)
            solve_output = MIPVerify.conv2d(input, p_solve)
            @test solve_output≈true_output
        end
        @testset "Variable Input, Numerical Layer Parameters" begin
            m = TestHelpers.get_new_model()
            input_v = map(_ -> @variable(m), CartesianIndices(input_size))
            output_v = MIPVerify.conv2d(input_v, p)
            @constraint(m, output_v .== true_output)
            solve(m)

            solve_output = MIPVerify.conv2d(getvalue(input_v), p)
            @test solve_output≈true_output
        end
    end

    @testset "conv2d with stride 2, odd input shape with even filter shape" begin
        input_size = (1, 5, 5, 2)
        input = reshape(collect(1:prod(input_size)), input_size) .- 25
        filter_size = (4, 4, 2, 1)
        filter = reshape(collect(1:prod(filter_size)), filter_size) .- 16
        bias_size = (1, )
        bias = [1]
        stride = 2
        true_output_raw = [
            1756  2511  1310;
            3065  4097  1969;
            1017  1225  501 ;
        ]
        true_output = reshape(transpose(true_output_raw), (1, 3, 3, 1))
        p = Conv2d(filter, bias, stride)
        @testset "Numerical Input, Numerical Layer Parameters" begin
            evaluated_output = MIPVerify.conv2d(input, p)
            @test evaluated_output == true_output
        end
        @testset "Numerical Input, Variable Layer Parameters" begin
            m = TestHelpers.get_new_model()
            filter_v = map(_ -> @variable(m), CartesianIndices(filter_size))
            bias_v = map(_ -> @variable(m), CartesianIndices(bias_size))
            p_v = Conv2d(filter_v, bias_v, stride)
            output_v = MIPVerify.conv2d(input, p_v)
            @constraint(m, output_v .== true_output)
            solve(m)

            p_solve = MIPVerify.Conv2d(getvalue(filter_v), getvalue(bias_v), stride)
            solve_output = MIPVerify.conv2d(input, p_solve)
            @test solve_output≈true_output
        end
        @testset "Variable Input, Numerical Layer Parameters" begin
            m = TestHelpers.get_new_model()
            input_v = map(_ -> @variable(m), CartesianIndices(input_size))
            output_v = MIPVerify.conv2d(input_v, p)
            @constraint(m, output_v .== true_output)
            solve(m)

            solve_output = MIPVerify.conv2d(getvalue(input_v), p)
            @test solve_output≈true_output
        end
    end
end