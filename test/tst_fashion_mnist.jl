module FashionMNIST_Tests
using Base.Test
using ColorTypes
using MLDatasets

@testset "Constants" begin
    @test FashionMNIST.TRAINIMAGES == "train-images-idx3-ubyte.gz"
    @test FashionMNIST.TRAINLABELS == "train-labels-idx1-ubyte.gz"
    @test FashionMNIST.TESTIMAGES  == "t10k-images-idx3-ubyte.gz"
    @test FashionMNIST.TESTLABELS  == "t10k-labels-idx1-ubyte.gz"
    @test length(FashionMNIST.CLASSES) == 10
    @test length(unique(FashionMNIST.CLASSES)) == 10

    @test endswith(FashionMNIST.DEFAULT_DIR, "MLDatasets/datasets/fashion_mnist")
end

const _TRAINIMAGES = joinpath(FashionMNIST.DEFAULT_DIR, FashionMNIST.TRAINIMAGES)
const _TRAINLABELS = joinpath(FashionMNIST.DEFAULT_DIR, FashionMNIST.TRAINLABELS)
const _TESTIMAGES = joinpath(FashionMNIST.DEFAULT_DIR, FashionMNIST.TESTIMAGES)
const _TESTLABELS = joinpath(FashionMNIST.DEFAULT_DIR, FashionMNIST.TESTLABELS)

if isfile(_TRAINIMAGES)
    info("Skipping (pre-)download tests: FashionMNIST dataset already exists.")
    @assert all(map(isfile, [_TRAINIMAGES, _TRAINLABELS, _TESTIMAGES, _TESTLABELS])) "Only some files of the dataset are already present"
else
    @assert all(map(!isfile, [_TRAINIMAGES, _TRAINLABELS, _TESTIMAGES, _TESTLABELS])) "Only some files of the dataset are already present"
    if isinteractive()
        info("Skipping download-error tests: interactive session running.")
    else
        @testset "Pre-download Errors" begin
            @test_throws ErrorException FashionMNIST.download()
            @test_throws ErrorException FashionMNIST.traintensor()
            @test_throws ErrorException FashionMNIST.trainlabels()
            @test_throws ErrorException FashionMNIST.traindata()
            @test_throws ErrorException FashionMNIST.testtensor()
            @test_throws ErrorException FashionMNIST.testlabels()
            @test_throws ErrorException FashionMNIST.testdata()
        end
    end
    @testset "Download" begin
        @test FashionMNIST.download(i_accept_the_terms_of_use=true) == nothing
    end
end

@testset "Images" begin
    # Sanity check that the first trainimage is not the first testimage
    @test FashionMNIST.traintensor(1) != FashionMNIST.testtensor(1)
    # Make sure other integer types work as indicies
    @test FashionMNIST.traintensor(0xBAE) == FashionMNIST.traintensor(2990)

    @testset "Test that traintensor are the train images" begin
        for i = rand(1:60_000, 10)
            @test FashionMNIST.traintensor(i) == MNIST.Reader.readimages(_TRAINIMAGES, i) ./ 255.0
        end
    end
    @testset "Test that testtensor are the test images" begin
        for i = rand(1:10_000, 10)
            @test FashionMNIST.testtensor(i) == MNIST.Reader.readimages(_TESTIMAGES, i) ./ 255.0
        end
    end

    # These tests check if the functions return internaly consistent
    # results for different parameters (e.g. index as int or as vector).
    # That means no matter how you specify an index, you will always
    # get the same result for a specific index.
    for (image_fun, nimages) in ((FashionMNIST.traintensor, 60_000),
                                 (FashionMNIST.testtensor,  10_000))
        @testset "$image_fun" begin
            # whole image set
            A = @inferred image_fun()
            @test typeof(A) <: Array{Float64,3}
            @test size(A) == (28,28,nimages)

            @test_throws AssertionError image_fun(-1)
            @test_throws AssertionError image_fun(0)
            @test_throws AssertionError image_fun(nimages+1)

            @testset "load single images" begin
                # Sample a few random images to compare
                for i = rand(1:nimages, 10)
                    A_i = @inferred image_fun(i)
                    @test typeof(A_i) <: Array{Float64,2}
                    @test size(A_i) == (28,28)
                    @test A_i == A[:,:,i]
                end
            end

            @testset "load multiple images" begin
                A_5_10 = @inferred image_fun(5:10)
                @test typeof(A_5_10) <: Array{Float64,3}
                @test size(A_5_10) == (28,28,6)
                for i = 1:6
                    @test A_5_10[:,:,i] == A[:,:,i+4]
                end

                # also test edge cases `1`, `nimages`
                indices = [10,3,9,1,nimages]
                A_vec   = image_fun(indices)
                A_vec_f = image_fun(Vector{Int32}(indices))
                @test typeof(A_vec)   <: Array{Float64,3}
                @test typeof(A_vec_f) <: Array{Float64,3}
                @test size(A_vec)   == (28,28,5)
                @test size(A_vec_f) == (28,28,5)
                for i in 1:5
                    @test A_vec[:,:,i] == A[:,:,indices[i]]
                    @test A_vec[:,:,i] == A_vec_f[:,:,i]
                end
            end
        end
    end
end

@testset "Labels" begin
    # Sanity check that the first trainlabel is not the first testlabel
    @test FashionMNIST.trainlabels(2) != FashionMNIST.testlabels(2)

    # Check a few hand picked examples. I looked at both the pictures and
    # the native output to make sure these values are correspond to the
    # image at the same index.
    @test FashionMNIST.trainlabels(1) === 9
    @test FashionMNIST.trainlabels(5) === 0
    @test FashionMNIST.trainlabels(60_000) === 5
    @test FashionMNIST.testlabels(1) === 9
    @test FashionMNIST.testlabels(10_000) === 5

    # These tests check if the functions return internaly consistent
    # results for different parameters (e.g. index as int or as vector).
    # That means no matter how you specify an index, you will always
    # get the same result for a specific index.
    # -- However, technically these tests do not check if these are the
    #    actual FashionMNIST labels of that index!
    for (label_fun, nlabels) in
                ((FashionMNIST.trainlabels, 60_000),
                 (FashionMNIST.testlabels,  10_000))
        @testset "$label_fun" begin
            # whole label set
            A = @inferred label_fun()
            @test typeof(A) <: Vector{Int64}
            @test size(A) == (nlabels,)

            @testset "load single label" begin
                # Sample a few random labels to compare
                for i = rand(1:nlabels, 10)
                    A_i = @inferred label_fun(i)
                    @test typeof(A_i) <: Int64
                    @test A_i == A[i]
                end
            end

            @testset "load multiple labels" begin
                A_5_10 = @inferred label_fun(5:10)
                @test typeof(A_5_10) <: Vector{Int64}
                @test size(A_5_10) == (6,)
                for i = 1:6
                    @test A_5_10[i] == A[i+4]
                end

                # also test edge cases `1`, `nlabels`
                indices = [10,3,9,1,nlabels]
                A_vec   = @inferred label_fun(indices)
                A_vec_f = @inferred label_fun(Vector{Int32}(indices))
                @test typeof(A_vec)   <: Vector{Int64}
                @test typeof(A_vec_f) <: Vector{Int64}
                @test size(A_vec)   == (5,)
                @test size(A_vec_f) == (5,)
                for i in 1:5
                    @test A_vec[i] == A[indices[i]]
                    @test A_vec[i] == A_vec_f[i]
                end
            end
        end
    end
end

# Check against the already tested tensor and labels functions
@testset "Data" begin
    for (data_fun, feature_fun, label_fun, nobs) in
            ((FashionMNIST.traindata, FashionMNIST.traintensor, FashionMNIST.trainlabels, 60_000),
            (FashionMNIST.testdata,  FashionMNIST.testtensor,  FashionMNIST.testlabels,  10_000))
        @testset "check $data_fun against $feature_fun and $label_fun" begin
            data, labels = @inferred data_fun()
            @test data == feature_fun()
            @test labels == label_fun()

            for i = rand(1:nobs, 10)
                d_i, l_i = @inferred data_fun(i)
                @test d_i == feature_fun(i)
                @test l_i == label_fun(i)
            end

            data, labels = @inferred data_fun(5:10)
            @test data == feature_fun(5:10)
            @test labels == label_fun(5:10)

            data, labels = data_fun(5:10, decimal=false)
            @test data == feature_fun(5:10, decimal=false)
            @test labels == label_fun(5:10)

            indices = [10,3,9,1,nobs]
            data, labels = @inferred data_fun(indices)
            @test data == feature_fun(indices)
            @test labels == label_fun(indices)
        end
    end
end

@testset "convert2features" begin
    data = FashionMNIST.traintensor(1)
    @test @inferred(FashionMNIST.convert2features(data)) == vec(data)

    data = FashionMNIST.traintensor(3:4)
    @test @inferred(FashionMNIST.convert2features(data)) == reshape(data, (28*28, 2))
end

@testset "convert2images" begin
    data = FashionMNIST.traintensor(1)
    A = FashionMNIST.convert2image(data)
    @test A[1] == 1.0
    @test size(A) == (28,28)
    @test eltype(A) == Gray{Float64}
    @test FashionMNIST.convert2image(vec(data)) == A

    data = FashionMNIST.traintensor(1:2)
    A = FashionMNIST.convert2image(data)
    @test A[1] == 1.0
    @test size(A) == (28,28,2)
    @test eltype(A) == Gray{Float64}
    @test FashionMNIST.convert2image(vec(data)) == A
    @test FashionMNIST.convert2image(FashionMNIST.convert2features(data)) == A
end

end
