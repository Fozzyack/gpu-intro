const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .safe });

    const exe = b.addExecutable(.{
        .name = "simple-dots",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const cuda_path = b.option([]const u8, "cuda-path", "CUDA Toolkit directory") orelse "/opt/cuda";
    const cuda = b.addSystemCommand(&.{
        b.pathJoin(&.{ cuda_path, "bin/nvcc" }),
        "-c",
        "-O2",
        "-arch=sm_89", // RTX 4080 Super (Ada).
        "-Xcompiler=-fPIC",
    });
    cuda.addFileArg(b.path("src/dot.cu"));
    cuda.addArg("-o");
    exe.root_module.addObjectFile(cuda.addOutputFileArg("dot.o"));
    exe.root_module.link_libc = true;
    // nvcc's generated host code uses the C++ runtime (guards/exceptions).
    exe.root_module.link_libcpp = true;
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ cuda_path, "lib64" }) });
    exe.root_module.addRPath(.{ .cwd_relative = b.pathJoin(&.{ cuda_path, "lib64" }) });
    exe.root_module.linkSystemLibrary("cudart", .{});

    b.installArtifact(exe);
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run executable");
    run_step.dependOn(&run_exe.step);

    const tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run CPU reference tests (no GPU required)").dependOn(&run_tests.step);
}
