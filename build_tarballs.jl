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
    "http://faculty.cse.tamu.edu/davis/SuiteSparse/SuiteSparse-5.0.0.tar.gz" =>
    "7162e3a9fda729b3d46183307e93326e3cde726c72b1ec79a973060b16e6b3be",
]

script = raw"""

# SuiteSparse for KLU

cd $WORKSPACE/srcdir
cd SuiteSparse/SuiteSparse_config/
cat > mk.patch <<'END'
--- SuiteSparse_config.mk
+++ SuiteSparse_config.mk.new
@@ -432,12 +432,13 @@

 SO_OPTS = $(LDFLAGS)

-ifeq ($(UNAME),Windows)
+ifeq ($(UNAME),MSYS_NT-6.3)
     # Cygwin Make on Windows (untested)
     AR_TARGET = $(LIBRARY).lib
     SO_PLAIN  = $(LIBRARY).dll
     SO_MAIN   = $(LIBRARY).$(SO_VERSION).dll
     SO_TARGET = $(LIBRARY).$(VERSION).dll
+    SO_OPTS  += -shared -Wl,-soname -Wl,$(SO_MAIN) -Wl,--no-undefined
     SO_INSTALL_NAME = echo
 else
     # Mac or Linux/Unix
END

patch -l SuiteSparse_config.mk < mk.patch
make library
INSTALL=$WORKSPACE/destdir/ make install
cd ../AMD
make library
INSTALL=$WORKSPACE/destdir/ make install
cd ../COLAMD
make library
INSTALL=$WORKSPACE/destdir/ make install
cd ../BTF
make library
INSTALL=$WORKSPACE/destdir/ make install
cd ../KLU
make library
INSTALL=$WORKSPACE/destdir/ make install

# Now the full Sundials build

cd $WORKSPACE/srcdir/sundials-3.1.0/
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/ -DCMAKE_TOOLCHAIN_FILE=/opt/$target/$target.toolchain -DCMAKE_BUILD_TYPE=Release -DEXAMPLES_ENABLE=OFF -DKLU_ENABLE=ON DKLU_INCLUDE_DIR=$WORKSPACE/srcdir/SuiteSparse/KLU/Include/ -DKLU_LIBRARY_DIR=$WORKSPACE/srcdir/SuiteSparse/lib ..
make -j8
make install
mkdir $WORKSPACE/destdir/bin
mv $WORKSPACE/destdir/lib/*.dll $WORKSPACE/destdir/bin || true

"""

products = prefix -> [
    LibraryProduct(prefix,"libbtf"),
    LibraryProduct(prefix,"libsundials_sunlinsolspfgmr"),
    LibraryProduct(prefix,"libsundials_ida"),
    LibraryProduct(prefix,"libsundials_cvode"),
    LibraryProduct(prefix,"libsundials_cvodes"),
    LibraryProduct(prefix,"libcolamd"),
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
    LibraryProduct(prefix,"libsundials_arkode"),
    LibraryProduct(prefix,"libklu"),
    LibraryProduct(prefix,"libsuitesparseconfig"),
    LibraryProduct(prefix,"libamd")
]


# Build the given platforms using the given sources
hashes = autobuild(pwd(), "Sundials", platforms, sources, script, products)

if !isempty(get(ENV,"TRAVIS_TAG",""))
    print_buildjl(pwd(), products, hashes,
        "https://github.com/JuliaDiffEq/SundialsBuilder/releases/download/$(ENV["TRAVIS_TAG"])")
end
