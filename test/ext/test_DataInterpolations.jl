using SparseConnectivityTracer
using SparseConnectivityTracer: DEFAULT_GRADIENT_TRACER, DEFAULT_HESSIAN_TRACER
using SparseConnectivityTracer: trace_input, Dual, primal
using DataInterpolations
using DataInterpolations: AbstractInterpolation
using Test

myprimal(x) = x
myprimal(d::Dual) = primal(d)

#===========#
# Test data #
#===========#

tquery = 2.0
t = [0.0, 1.0, 2.5, 4.0, 6.0];

u = sin.(t) # vector
du = cos.(t)
ddu = -sin.(t)

um = rand(2, length(t)); # matrix

#==================#
# Test definitions #
#==================#

struct InterpolationTest{N,I<:AbstractInterpolation} # N = output dim. of interpolation
    interp::I
    is_der1_zero::Bool
    is_der2_zero::Bool
end
function InterpolationTest(
    N, interp::I; is_der1_zero=false, is_der2_zero=false
) where {I<:AbstractInterpolation}
    return InterpolationTest{N,I}(interp, is_der1_zero, is_der2_zero)
end
testname(t::InterpolationTest{N}) where {N} = "$N-dim $(typeof(t.interp))"

# Interpolations with scalar outputs
function test_interpolation(t::InterpolationTest{1})
    Jref = [Int(!t.is_der1_zero);;]
    Href = [Int(!t.is_der2_zero);;]

    @testset "Jacobian Global" begin
        J = jacobian_sparsity(t.interp, tquery, TracerSparsityDetector())
        @test J ≈ Jref
    end
    @testset "Jacobian Local" begin
        J = jacobian_sparsity(t.interp, tquery, TracerLocalSparsityDetector())
        @test J ≈ Jref
    end
    @testset "Hessian Global" begin
        H = hessian_sparsity(t.interp, tquery, TracerSparsityDetector())
        @test H ≈ Href
    end
    @testset "Hessian Local" begin
        H = hessian_sparsity(t.interp, tquery, TracerLocalSparsityDetector())
        @test H ≈ Href
    end
end

# Interpolations with vector-valued outputs
function test_interpolation(t::InterpolationTest{N}) where {N} # N ≠ 1
    Jref = t.is_der1_zero ? zeros(N) : ones(N)
    Href = t.is_der2_zero ? zeros(N) : ones(N)

    @testset "Jacobian Global" begin
        J = jacobian_sparsity(t.interp, tquery, TracerSparsityDetector())
        @test J ≈ Jref
    end
    @testset "Jacobian Local" begin
        J = jacobian_sparsity(t.interp, tquery, TracerLocalSparsityDetector())
        @test J ≈ Jref
    end
    @testset "Hessian Global" begin
        H = hessian_sparsity(t.interp, tquery, TracerSparsityDetector())
        @test H ≈ Href
    end
    @testset "Hessian Local" begin
        H = hessian_sparsity(t.interp, tquery, TracerLocalSparsityDetector())
        @test H ≈ Href
    end
end

function test_output(t::InterpolationTest)
    @testset "Output sizes and values" begin
        out_ref = t.interp(tquery)
        s_ref = size(out_ref)

        @testset "$T" for T in (DEFAULT_GRADIENT_TRACER, DEFAULT_HESSIAN_TRACER)
            t_tracer = trace_input(T, tquery)
            out_tracer = t.interp(t_tracer)
            s_tracer = size(out_tracer)
            @test s_tracer == s_ref
        end
        @testset "$T" for T in (
            Dual{typeof(tquery),DEFAULT_GRADIENT_TRACER},
            Dual{typeof(tquery),DEFAULT_HESSIAN_TRACER},
        )
            t_dual = trace_input(T, tquery)
            out_dual = t.interp(t_dual)
            s_dual = size(out_dual)
            @test s_dual == s_ref
            @test myprimal.(out_dual) ≈ out_ref
        end
    end
end

#===========#
# Run tests #
#===========#

interpolation_tests = (
    InterpolationTest(1, ConstantInterpolation(u, t); is_der1_zero=true, is_der2_zero=true),
    InterpolationTest(1, LinearInterpolation(u, t); is_der2_zero=true),
    InterpolationTest(1, QuadraticInterpolation(u, t)),
    InterpolationTest(1, LagrangeInterpolation(u, t)),
    InterpolationTest(1, AkimaInterpolation(u, t)),
    InterpolationTest(1, QuadraticSpline(u, t)),
    InterpolationTest(1, CubicSpline(u, t)),
    InterpolationTest(1, BSplineInterpolation(u, t, 3, :ArcLen, :Average)),
    InterpolationTest(1, BSplineApprox(u, t, 3, 4, :ArcLen, :Average)),
    InterpolationTest(1, CubicHermiteSpline(du, u, t)),
    InterpolationTest(1, PCHIPInterpolation(u, t)),
    InterpolationTest(1, QuinticHermiteSpline(ddu, du, u, t)),
)

@testset "Test interpolations" begin
    @testset "$(testname(t))" for t in interpolation_tests
        test_interpolation(t)
        test_output(t)
    end
end
