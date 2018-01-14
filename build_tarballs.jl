using BinaryBuilder

# These are the platforms built inside the wizard
platforms = [
  BinaryProvider.Windows(:x86_64),
  BinaryProvider.Windows(:i686),
  BinaryProvider.Linux(:x86_64, :glibc),
  BinaryProvider.MacOS(),
  BinaryProvider.Linux(:i686, :glibc),
  BinaryProvider.Linux(:aarch64, :glibc),
  BinaryProvider.Linux(:armv7l, :glibc),
  BinaryProvider.Linux(:powerpc64le, :glibc),
]


# If the user passed in a platform (or a few, comma-separated) on the
# command-line, use that instead of our default platforms
if length(ARGS) > 0
    platforms = platform_key.(split(ARGS[1], ","))
end
info("Building for $(join(triplet.(platforms), ", "))")

# Collection of sources required to build SundialsBuilder
sources = [
    "https://computation.llnl.gov/projects/sundials/download/sundials-3.1.0.tar.gz" =>
    "18d52f8f329626f77b99b8bf91e05b7d16b49fde2483d3a0ea55496ce4cdd43a",
]

script = raw"""
cd $WORKSPACE/srcdir
cd $WORKSPACE/srcdir/sundials-3.1.0/
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/ -DCMAKE_TOOLCHAIN_FILE=/opt/$target/$target.toolchain -DCMAKE_BUILD_TYPE=Release -DEXAMPLES_ENABLE=OFF ..
make -j8
make install
mkdir $WORKSPACE/destdir/bin
mv $WORKSPACE/destdir/lib/*.dll $WORKSPACE/destdir/bin || true

"""

products = prefix -> [
    LibraryProduct(prefix,"libsundials_sunlinsolspfgmr"),
    LibraryProduct(prefix,"libsundials_ida"),
    LibraryProduct(prefix,"libsundials_cvode"),
    LibraryProduct(prefix,"libsundials_cvodes"),
    LibraryProduct(prefix,"libsundials_sunmatrixdense"),
    LibraryProduct(prefix,"libsundials_sunlinsolspbcgs"),
    LibraryProduct(prefix,"libsundials_idas"),
    LibraryProduct(prefix,"libsundials_nvecserial"),
    LibraryProduct(prefix,"libsundials_sunlinsoldense"),
    LibraryProduct(prefix,"libsundials_sunlinsolspgmr"),
    LibraryProduct(prefix,"libsundials_sunlinsolpcg"),
    LibraryProduct(prefix,"libsundials_sunlinsolsptfqmr"),
    LibraryProduct(prefix,"libsundials_sunmatrixsparse"),
    LibraryProduct(prefix,"libsundials_sunlinsolband"),
    LibraryProduct(prefix,"libsundials_sunmatrixband"),
    LibraryProduct(prefix,"libsundials_kinsol"),
    LibraryProduct(prefix,"libsundials_arkode")
]


# Build the given platforms using the given sources
hashes = autobuild(pwd(), "Sundials", platforms, sources, script, products)

if !isempty(get(ENV,"TRAVIS_TAG",""))
    print_buildjl(pwd(), products, hashes,
        "https://github.com/JuliaDiffEq/SundialsBuilder/releases/download/$(ENV["TRAVIS_TAG"])")
end

