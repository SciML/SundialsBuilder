using BinaryBuilder

# These are the platforms built inside the wizard
platforms = [
  BinaryProvider.Windows(:i686),
  BinaryProvider.Windows(:x86_64),
  BinaryProvider.MacOS(),
  BinaryProvider.Linux(:x86_64, :glibc),
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
    "http://faculty.cse.tamu.edu/davis/SuiteSparse/SuiteSparse-4.5.3.tar.gz" =>
    "6199a3a35fbce82b155fd2349cf81d2b7cddaf0dac218c08cb172f9bc143f37a",
]

script = raw"""

# SuiteSparse for KLU

cd $WORKSPACE/srcdir
cd SuiteSparse/SuiteSparse_config/

cat > mk.patch <<'END'
--- SuiteSparse_config.mk.orig
+++ SuiteSparse_config.mk
@@ -426,12 +426,13 @@

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

cat > mk2.patch <<'END'
--- SuiteSparse_config/SuiteSparse_config.h	2015-07-15 03:26:41.000000000 +0000
+++ SuiteSparse_config/SuiteSparse_config.h	2016-07-01 00:55:57.157465600 +0000
@@ -54,7 +54,11 @@
 #ifdef _WIN64
 
 #define SuiteSparse_long __int64
+#ifdef _MSVC_VER
 #define SuiteSparse_long_max _I64_MAX
+#else
+#define SuiteSparse_long_max LLONG_MAX
+#endif
 #define SuiteSparse_long_idd "I64d"
 
 #else
END
patch -l SuiteSparse_config.h < mk2.patch

make -j8 library
INSTALL=$WORKSPACE/destdir/ make install
cd ../AMD
make -j8 library
INSTALL=$WORKSPACE/destdir/ make install
cd ../COLAMD
make -j8 library
INSTALL=$WORKSPACE/destdir/ make install
cd ../BTF
make -j8 library
INSTALL=$WORKSPACE/destdir/ make install
cd ../KLU
make -j8 library
INSTALL=$WORKSPACE/destdir/ make install

echo "KLU Includes"
ls $WORKSPACE/destdir/include
echo "KLU Lib"
ls $WORKSPACE/destdir/lib

# Now the full Sundials build

cd $WORKSPACE/srcdir/sundials-3.1.0/
mkdir build
cd config
cp FindKLU.cmake FindKLU.cmake.orig

cat > file.patch <<'END'
--- FindKLU.cmake.orig
+++ FindKLU.cmake
@@ -61,9 +61,9 @@
 if (NOT SUITESPARSECONFIG_LIBRARY)
     set(SUITESPARSECONFIG_LIBRARY_NAME suitesparseconfig)
     # NOTE: no prefix for this library on windows
-    if (WIN32)
-        set(CMAKE_FIND_LIBRARY_PREFIXES "")
-    endif()
+#    if (WIN32)
+#        set(CMAKE_FIND_LIBRARY_PREFIXES "")
+#    endif()
     FIND_LIBRARY( SUITESPARSECONFIG_LIBRARY ${SUITESPARSECONFIG_LIBRARY_NAME} ${KLU_LIBRARY_DIR} NO_DEFAULT_PATH)
     mark_as_advanced(SUITESPARSECONFIG_LIBRARY)
 endif ()
END
patch -l FindKLU.cmake.orig file.patch -o FindKLU.cmake
cd ../build


if [[ $target == i686-* ]] || [[ $target == arm-* ]]; then 
echo "***   32-bit BUILD   ***"
cmake -DCMAKE_INSTALL_PREFIX=/ -DCMAKE_TOOLCHAIN_FILE=/opt/$target/$target.toolchain -DCMAKE_BUILD_TYPE=Release -DEXAMPLES_ENABLE=OFF -DKLU_ENABLE=ON -DKLU_INCLUDE_DIR="$WORKSPACE/destdir/include/" -DKLU_LIBRARY_DIR="$WORKSPACE/destdir/lib" -DCMAKE_FIND_ROOT_PATH="$WORKSPACE/destdir" -DSUNDIALS_INDEX_TYPE=int32_t ..
else
echo "***   64-bit BUILD   ***"
cmake -DCMAKE_INSTALL_PREFIX=/ -DCMAKE_TOOLCHAIN_FILE=/opt/$target/$target.toolchain -DCMAKE_BUILD_TYPE=Release -DEXAMPLES_ENABLE=OFF -DKLU_ENABLE=ON -DKLU_INCLUDE_DIR="$WORKSPACE/destdir/include/" -DKLU_LIBRARY_DIR="$WORKSPACE/destdir/lib" -DCMAKE_FIND_ROOT_PATH="$WORKSPACE/destdir" ..
fi

make -j8
make install
mkdir $WORKSPACE/destdir/bin
cp -L $WORKSPACE/destdir/lib/*.dll $WORKSPACE/destdir/bin || true

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
