
#################################################################
# This is the source for the `configure` script, to be compiled #
# by autoconf (use `make-configure` in "../../ac").             #
#################################################################

AC_INIT([Racket],[CS],[https://github.com/racket/racket],[racket],[https://racket-lang.org])
AC_CONFIG_SRCDIR([embed-boot.rkt])
AC_CONFIG_HEADERS([cs_config.h])

AC_CONFIG_AUX_DIR(../../lt)
AC_CANONICAL_SYSTEM

AC_DISABLE_OPTION_CHECKING

AC_ARG_ENABLE(shared,     [  --enable-shared         create shared libraries (not currently supported)])
AC_ARG_ENABLE(standalone, [  --enable-standalone     create a standalone shared library])
AC_ARG_ENABLE(pthread,    [  --enable-pthread        link with pthreads (usually auto-enabled if needed)])
m4_include(../ac/iconv_arg.m4)
m4_include(../ac/curses_arg.m4)
AC_ARG_ENABLE(wpo,        [  --enable-wpo            agressively optimize Racket core (enabled by default)])
AC_ARG_ENABLE(compress,   [  --enable-compress       compress compiled code (enabled by default)])
AC_ARG_ENABLE(compressmore, [  --enable-compressmore   compress compiled code even more])
AC_ARG_ENABLE(compressboot, [  --enable-compressboot   compress boot files])
m4_include(../ac/path_arg.m4)
AC_ARG_ENABLE(racket,     [  --enable-racket=<path>  use <path> as Racket for build; or "auto" to create])
AC_ARG_ENABLE(scheme,     [  --enable-scheme=<path>  use <path> as Chez Scheme for build])
AC_ARG_ENABLE(mach,       [  --enable-mach=<mach>    use Chez Scheme machine type <mach>])
AC_ARG_ENABLE(target,     [  --enable-target=<mach>  cross-build for Chez Scheme machine type <mach>])
AC_ARG_ENABLE(pb,         [  --enable-pb             build for platform without native-code backend])
AC_ARG_ENABLE(pbchunk,    [  --enable-pbchunk        enable C chunks for pb boot (enabled by default)])
AC_ARG_ENABLE(check,      [  --enable-check          enable extra safety checks for testing])
m4_include(../ac/portable_arg.m4)
m4_include(../ac/natipkg_arg.m4)
m4_include(../ac/sdk_arg.m4)
m4_include(../ac/instlib_arg.m4)
m4_include(../ac/postlink_arg.m4)
m4_include(../ac/strip_arg.m4)
m4_include(../ac/ubsan_arg.m4)
m4_include(../ac/asan_arg.m4)
m4_include(../ac/vm_arg.m4)
m4_include(../ac/crossany_arg.m4)
AC_ARG_ENABLE(libz,       [  --enable-libz           use installed libz if available])
AC_ARG_ENABLE(liblz4,     [  --enable-liblz4         use installed liblz4 if available])

m4_include(../ac/sdk.m4)

show_explicitly_disabled()
{
  if test "$1" = "no" ; then
    echo "=== $2 disabled"
  fi
}

show_explicitly_enabled()
{
  if test "$1" = "yes" ; then
    echo "=== $2 enabled"
    if test "$3" != "" ; then
      echo "  $3"
    fi
  fi
}

show_explicitly_set()
{
  if test "$1" != "" ; then
    echo "=== $2 set to $1"
  fi
}

if test "${enable_shared}" = "yes" ; then
  echo "=== Canceling --enable-shared"
  echo "    Building Racket CS as a shared library is not currently"
  echo "    supported --- but Racket executables get the benefits of"
  echo "    sharing, anyway, by going through a shared executable"
  enable_shared=no
fi

show_explicitly_enabled "${enable_pthread}" "pthreads"
show_explicitly_disabled "${enable_pthread}" "pthreads"
show_explicitly_disabled "${enable_compress}" "Compressed code"
show_explicitly_disabled "${enable_compressmore}" "Compressed code even more"
show_explicitly_enabled "${enable_compressboot}" "Compressed boot files"
show_explicitly_disabled "${enable_compressboot}" "Compressed boot files"
show_explicitly_enabled "${enable_xonx}" "Unix style"
m4_include(../ac/path_show.m4)
show_explicitly_set "${enable_racket}" "Racket"
show_explicitly_set "${enable_scheme}" "Chez Scheme for build"
show_explicitly_set "${enable_mach}" "machine type"
show_explicitly_set "${enable_target}" "cross-build machine type"
show_explicitly_set "${enable_pb}" "pb machine type"
show_explicitly_disabled "${enable_pbchunk}" "pbchunk"
m4_include(../ac/portable_show.m4)
m4_include(../ac/natipkg_show.m4)
show_explicitly_enabled "${enable_libz}" "Installed libz"
show_explicitly_disabled "${enable_libz}" "Installed libz"
show_explicitly_enabled "${enable_liblz4}" "Installed liblz4"
show_explicitly_disabled "${enable_liblz4}" "Installed liblz4"
m4_include(../ac/iconv_show.m4)
show_explicitly_enabled "${enable_curses}" "curses"
show_explicitly_disabled "${enable_curses}" "curses"
show_explicitly_enabled "${enable_check}" "Extra checks"

m4_include(../ac/vm.m4)

m4_include(../ac/instlib.m4)
m4_include(../ac/sdk_show.m4)
m4_include(../ac/strip_show.m4)

if test "${enable_iconv}" = "" ; then
  enable_iconv=yes
fi

if test "${enable_xonx}" = "" ; then
  enable_xonx=no
fi

m4_include(../ac/path_pkgscope.m4)

m4_include(../ac/crossany.m4)

SUB_CONFIGURE_EXTRAS=

if test "${enable_csdefault}" = "yes" ; then
  CS_INSTALLED=""
else
  CS_INSTALLED=cs
  AC_DEFINE(CS_COMPILED_SUBDIR,1,[Use a subdirectory of "compiled"])
fi

show_explicitly_disabled "${enable_wpo}" "Agressive core optimization"
if test "${enable_wpo}" = "no" ; then
  DISABLE_WPO=t
else  
  DISABLE_WPO=f
fi

############## Install targets ################

PREFIX_PATH_RELATIVE=/../..

m4_include(../ac/path.m4)

############## init variables ################

skip_iconv_check=no
skip_curses_check=no
use_flag_pthread=yes
use_flag_posix_pthread=no

OSX="f"
SIGNED_EXE="f"
MINGW="f"
CONFIGURE_RACKET_SO_COMPILE=""
COMPRESS_COMP=""
BOOT_COMPRESS_COMP=""

FRAMEWORK_INSTALL_DIR='$(libpltdir)'
FRAMEWORK_PREFIX='@executable_path/../lib/'

RACKET=
BOOTFILE_RACKET=
SETUP_BOOT_MODE=--boot

INSTALL_SETUP_FLAGS="--no-user"
INSTALL_SETUP_RACKET_FLAGS=

Z_LIB=''
LZ4_LIB=''

DISABLE_ICONV=no
DISABLE_CURSES=no

PLT_CS_SLSP_SUFFIX=

enable_pthread_by_default=yes

compress_boot_files_by_default=no

use_own_zlibs=no

cs_auto_flags=--disable-auto-flags

COPY_NEW_CFLAGS_TO_CPPFLAGS=no

SCHEME_LIBFFI=no
PBCHUNK_MODE=plain

if test "${CC_FOR_BUILD}" = ""; then
  CC_FOR_BUILD='$(CC) -O2'
fi

ENABLE_EXTRA_CHECKS=no

###### Autoconfigure #######

m4_include(../ac/sdk_ios.m4)

AC_PROG_CC

m4_include(../ac/is_gcc.m4)

# If using gcc, we want all warnings:
if test "$is_gcc" != "" ; then 
  if test "${enable_warning}" != "no" ; then
    CFLAGS="$CFLAGS -Wall"
    cs_auto_flags="${cs_auto_flags} --enable-warning-flags"
  fi
fi

AC_CHECK_LIB(m, fmod)
AC_CHECK_LIB(dl, dlopen)

AC_PROG_RANLIB
if test "$AR" = '' ; then 
  AR="${ac_tool_prefix}ar"
  AC_CHECK_PROG(platform_ar_found, $AR, yes, no)
  if test "$platform_ar_found" = 'no' ; then
    AR="ar"
  fi
fi
if test "$ARFLAGS" = '' ; then 
  ARFLAGS=rc
fi

WINDRES=windres

############## platform tests ################

# At first, `MACH` means the target that we're building for. In
# cross-build mode, `MACH` will be moved to `TARGET_MACH`.

MACH_HOST_CPU="${host_cpu}"
extra_scheme_config_args=

case "$host_os" in
  solaris2*)
    MACH_OS=s2
    LIBS="$LIBS -lsocket -lnsl -lintl"
    use_flag_pthread="no"
    use_flag_posix_pthread="yes"
    ;;
  aix*)
    ;;
  *freebsd*)
    MACH_OS=fb
    CFLAGS="${CFLAGS} -I/usr/local/include"
    LDFLAGS="${LDFLAGS} -L/usr/local/lib"
    LIBS="${LIBS} -lm -lpthread"
    LINK_DYNAMIC="-rdynamic"
    add_iconv_lib="-liconv"
    ;;
  openbsd*)
    MACH_OS=ob
    CFLAGS="${CFLAGS} -I/usr/local/include"
    LDFLAGS="${LDFLAGS} -L/usr/local/lib"
    LIBS="${LIBS} -lm -lpthread"
    LINK_DYNAMIC="-Wl,--export-dynamic"
    add_iconv_lib="-liconv"
    LDFLAGS="${LDFLAGS} -Wl,-zwxneeded"
    ;;
  bitrig*)
    LINK_DYNAMIC="-Wl,--export-dynamic"
    ;;
  dragonfly*)
    LINK_DYNAMIC="-Wl,--export-dynamic"
    ;;
  netbsd*)
    MACH_OS=nb
    LIBS="${LIBS} -lm -lpthread"
    LINK_DYNAMIC="-rdynamic"
    skip_iconv_check=yes
    add_curses_lib="-lterminfo"
    default_post_linker="paxctl +m"
    ;;
  irix*)
    ;;
  linux*|gnu*)
    case "$host_os" in
      linux*)
        MACH_OS=le
        ;;
      *)
        MACH_OS=gnu # Hurd
        ;;
    esac
    case "$host_os" in
      *linux-android*)
        ;;
      *)
        LIBS="${LIBS} -lrt"
        ;;
    esac
    LINK_DYNAMIC="-rdynamic"
    curses_portable_link="/usr/lib/${host_cpu}-${host_os}/libncurses.a /usr/lib/${host_cpu}-${host_os}/libtermcap.a"
    ;;
  osf1*)
    ;;
  hpux*)
    ;;
  *mingw*)
    skip_iconv_check=yes
    skip_curses_check=yes
    use_flag_pthread=no
    use_own_zlibs=yes
    MACH_OS=nt
    LIBS="${LIBS} -lshell32 -luser32 -lole32 -lrpcrt4 -luuid -lws2_32 -ladvapi32 -lwinmm"
    MINGW="t"
    compress_boot_files_by_default=yes
    if `which ${host}-windres > /dev/null` ; then
      WINDRES="${host}-windres"
    fi
    # ".a" is typically not useful, since we always build a DLL:
    if test "${enable_libs}" = "" ; then
      INSTALL_LIBS_ENABLE=no-install
    fi
    ;;
  cygwin*)
    ;;
  darwin*)
    PREFLAGS="$PREFLAGS -DOS_X"
    MACH_OS=osx
    LIBS="${LIBS} -framework CoreFoundation"
    LDFLAGS="${LDFLAGS} -Wl,-headerpad_max_install_names"
    SIGNED_EXE="t"
    if test "${enable_xonx}" = "no" ; then
      OSX="t"
    else
      CONFIGURE_RACKET_SO_COMPILE="PLT_CS_MAKE_UNIX_STYLE_MACOS=y"
      CPPFLAGS="${CPPFLAGS} -DRACKET_XONX"
      strip_needs_dash_s=yes
    fi
    if test "${enable_embedfw}" = "yes" ; then
      strip_needs_dash_s=yes
    fi

    PROPAGATE_SUB_CONFIGURE=no
    m4_include(../ac/sdk_mac.m4)

    if test "${enable_libfw}" = "yes" ; then
      FRAMEWORK_INSTALL_DIR=/Library/Frameworks
      FRAMEWORK_REL_INSTALL=no
    elif test "${enable_userfw}" = "yes" ; then
      FRAMEWORK_INSTALL_DIR=~/Library/Frameworks
      FRAMEWORK_REL_INSTALL=no
    else
      FRAMEWORK_INSTALL_DIR='${libpltdir}'
      FRAMEWORK_REL_INSTALL=yes
    fi

    if test "${enable_mac64}" = "no"; then
      MACH_HOST_CPU="x86"
    fi

    # -pthread is not needed and triggers a warning
    use_flag_pthread=no

    # ncurses.h is always available, except on iOS
    if test "${enable_ios}" != "" ; then
      enable_curses=no
    fi

    use_own_zlibs=yes
    ;;
  nto-qnx*)
    MACH_OS=qnx
    use_flag_pthread=no
    ;;
  *)
    ;;
esac

if test "${enable_mach}" != "" ; then
  case "${enable_mach}" in
    t*)
       enable_pthread_by_default=yes
       ;;
    *)
       enable_pthread_by_default=no
       ;;
  esac
fi

if test "${enable_pthread}" = "" ; then
  if test "${enable_pthread_by_default}" = "yes" ; then
    enable_pthread=yes
  fi
fi

if test "${enable_curses}" = "" ; then
  enable_curses=yes
fi

############## machine type ################

thread_prefix=""
if test "${enable_pthread}" = "yes" ; then
  thread_prefix="t"
fi

case "$MACH_HOST_CPU" in
  x86_64)
    MACH="${thread_prefix}a6${MACH_OS}"
    pb_machine_name="${thread_prefix}pb64l"
    ;;
  x86|i*86)
    MACH="${thread_prefix}i3${MACH_OS}"
    pb_machine_name="${thread_prefix}pb32l"
    ;;
  aarch64*|arm64*)
    MACH="${thread_prefix}arm64${MACH_OS}"
    pb_machine_name="${thread_prefix}pb64l"
    ;;
  arm*)
    MACH="${thread_prefix}arm32${MACH_OS}"
    pb_machine_name="${thread_prefix}pb32l"
    ;;
  powerpc64*)
    MACH=""
    pb_machine_name="${thread_prefix}pb64b"
    # MACH="${thread_prefix}ppc64${MACH_OS}"
    ;;
  power*)
    MACH="${thread_prefix}ppc32${MACH_OS}"
    pb_machine_name="${thread_prefix}pb32b"
    ;;
  riscv64*)
    MACH="${thread_prefix}rv64${MACH_OS}"
    pb_machine_name="${thread_prefix}pb64l"
    ;;
  loongarch64*)
    MACH="${thread_prefix}la64${MACH_OS}"
    pb_machine_name="${thread_prefix}pb64l"
    ;;
esac

if test "${MACH}" = "" ; then
  default_mach_was_empty=yes
else
  default_mach_was_empty=no
fi

if test "${enable_mach}" != "" ; then
  MACH="${enable_mach}"
  if test "${enable_pb}" = "yes" ; then
    pb_machine_name="${enable_mach}"
  fi
elif test "${enable_pb}" = "yes" -a "${pb_machine_name}" != "" ; then
  if test "$MACH" = "" ; then
    # Use specified pb variant as host machine
    MACH=${pb_machine_name}
  fi
elif test "$MACH" = "" -o "$MACH_OS" = "" ; then
   echo "Platform is not supported natively by Racket CS."
   echo 'Try `--enable-pb --enable-mach=<machine>`, instead,'
   echo 'where <machine> is something like "tpb64l":'
   echo ' * prefix the machine name with "t" to get threading'
   echo ' * next is always "pb"'
   echo ' * next is "32" or "64" for the word size'
   echo ' * last is "l" for little endian or "b" for big endian'
   exit 1
fi

# For a pb build where Racket is supplied as "auto" and MACH was not originally
# empty, force cross-build mode on the assumption that the host is not
# a pb build (because it should be created with default configure options)
if test "${enable_pb}" = "yes" ; then
  if test "${enable_racket}" = "auto" ; then
    if test "${enable_target}" = "" ; then
      if test "${default_mach_was_empty}" = "no" ; then
        enable_target="${MACH}"
      fi
    fi
  fi
fi

if test "${build_os}_${build_cpu}" != "${host_os}_${host_cpu}" ; then
  BUILD_THREAD_PREFIX="${thread_prefix}"
  case "$build_os" in
    solaris2*)
      BUILD_OS=s2
      ;;
    *freebsd*)
      BUILD_OS=fb
      ;;
    openbsd*)
      BUILD_OS=ob
      ;;
    netbsd*)
      BUILD_OS=nb
      ;;
    linux*)
      BUILD_OS=le
      ;;
    gnu*) # Hurd - must come after linux*
      BUILD_OS=gnu
      ;;
    *mingw*)
      BUILD_OS=nt
      ;;
    darwin*)
      BUILD_OS=osx
      ;;
    nto-qnx*)
      BUILD_OS=qnx
      ;;
    *)
      echo "unknown build OS"
      exit 1
      ;;
  esac
  case "$build_cpu" in
    x86_64)
      BUILD_MACH="${BUILD_THREAD_PREFIX}a6${BUILD_OS}"
      ;;
    x86|i*86)
      BUILD_MACH="${BUILD_THREAD_PREFIX}i3${BUILD_OS}"
      ;;
    aarch64*|arm64*)
      BUILD_MACH="${BUILD_THREAD_PREFIX}arm64${BUILD_OS}"
      ;;
    arm*)
      BUILD_MACH="${BUILD_THREAD_PREFIX}arm32${BUILD_OS}"
      ;;
    powerpc64*)
      BUILD_MACH="${BUILD_THREAD_PREFIX}ppc64${BUILD_OS}"
      ;;
    power*)
      BUILD_MACH="${BUILD_THREAD_PREFIX}ppc32${BUILD_OS}"
      ;;
    riscv64*)
      BUILD_MACH="${BUILD_THREAD_PREFIX}rv64${BUILD_OS}"
      ;;
    loongarch64*)
      BUILD_MACH="${BUILD_THREAD_PREFIX}la64${BUILD_OS}"
      ;;
    *)
      echo "unknown build CPU"
      exit 1
      ;;
  esac
  TARGET_MACH=${MACH}
  MACH=${BUILD_MACH}
  CROSS_MODE="cross"
else
  TARGET_MACH=${MACH}
  CROSS_MODE=""
fi

if test "${enable_target}" != "" ; then
  TARGET_MACH=${enable_target}
  CROSS_MODE="cross"
fi

# From this point on, `MACH` means the build machine, and
# `TARGET_MACH` is the target that we're building for (which
# is different in cross-build mode).

############## Racket and Chez Scheme ################

SCHEME_SRC_DIR=${srcdir}/../../ChezScheme

if test "${enable_scheme}" != "" ; then
   if test -d "${enable_scheme}" ; then
     # Directory exists, so use it as a build directory
     echo "Using supplied Scheme path as a build directory"
     SCHEME_DIR="${enable_scheme}/ChezScheme"
   else
     # Directory does not exist, so assume it's an executable
     echo "Using supplied Scheme path as an executable"
     SCHEME="${enable_scheme}"
   fi     
fi

if test "${enable_racket}" != "" ; then
  if test "${enable_racket}" != "auto" ; then
    SETUP_BOOT_MODE=--chain
  fi
  # In non-cross mode, we interpret `--enable-racket` to supply a
  # Racket used only for generating Chez Scheme boot files
  if test "${CROSS_MODE}" = "cross" ; then
    RACKET="${enable_racket}"
  elif test "${enable_racket}" != "auto" ; then
    BOOTFILE_RACKET="${enable_racket}"
  fi
fi

if test "${enable_compress}" != "no" ; then
  COMPRESS_COMP="--compress"
fi
if test "${enable_compressmore}" = "yes" ; then
  COMPRESS_COMP="--compress-more"
fi

if test "${enable_compressboot}" = "yes" ; then
  BOOT_COMPRESS_COMP="--compress"
elif test "${compress_boot_files_by_default}" = "yes" ; then
  if test "${enable_compressboot}" != "no" ; then
    BOOT_COMPRESS_COMP="--compress"
  fi
fi

############## Strip tool ################

m4_include(../ac/strip.m4)

############## post-linker ################

m4_include(../ac/postlink.m4)

############## natipkg ################

if test "${enable_natipkg}" = "yes" ; then
  CONFIGURE_RACKET_SO_COMPILE="${CONFIGURE_RACKET_SO_COMPILE} PLT_CS_SLSP_SUFFIX=-natipkg"
  PLT_CS_SLSP_SUFFIX="-natipkg"
fi

############## ubsan ################

m4_include(../ac/ubsan.m4)

############## ubsan ################

m4_include(../ac/asan.m4)

############## C flags ################

AC_LANG_C

############## iconv ################

m4_include(../ac/iconv.m4)
if test "${enable_iconv}" = "no" ; then
  add_iconv_lib=
fi
if test "${add_iconv_lib}" != "" ; then
    LIBS="${LIBS} ${add_iconv_lib}"
fi

############## curses ################

m4_include(../ac/curses.m4)

############### pthread ###################

if test "${enable_pthread}" = "yes" ; then
  if test "${use_flag_pthread}" = "yes" ; then
    PREFLAGS="$PREFLAGS -pthread"
    LDFLAGS="$LDFLAGS -pthread"
  fi
  if test "${use_flag_posix_pthread}" = "yes" ; then
    PREFLAGS="$PREFLAGS -D_POSIX_PTHREAD_SEMANTICS -D_REENTRANT"
  fi
  AC_DEFINE(RKTIO_USE_PTHREADS, 1, [Pthread enabled])
fi

############## zlib and LZ4 ################

if test "${enable_libz}" != "no" ; then
  if test ! -d "$SCHEME_SRC_DIR/zlib" ; then
    echo "No libz in Scheme directory, so trying installed"
    enable_libz=yes
  fi
fi

if test "${enable_liblz4}" != "no" ; then
  if test ! -d "$SCHEME_SRC_DIR/lz4" ; then
    echo "No lz4 in Scheme directory, so trying installed"
    enable_liblz4=yes
  fi
fi

if test "${use_own_zlibs}" = "no" ; then
  if test "${enable_libz}" = "" ; then
    enable_libz=yes
  fi
  if test "${enable_liblz4}" = "" ; then
    enable_liblz4=yes
  fi
fi

if test "${enable_libz}" = "yes" ; then
  AC_MSG_CHECKING([for libz])

  OLD_LIBS="${LIBS}"
  LIBS="${LIBS} -lz"
  AC_TRY_LINK([#include <zlib.h>],
              [zlibVersion();],
             have_zlib=yes,
             have_zlib=no)
  AC_MSG_RESULT($have_zlib)

  if test "${have_zlib}" = "no" ; then
    LIBS="${OLD_LIBS}"
    echo "Building own libz"
  else
    Z_LIB="-lz"
  fi
fi

if test "${enable_liblz4}" = "yes" ; then
  AC_MSG_CHECKING([for liblz4])

  OLD_LIBS="${LIBS}"
  LIBS="${LIBS} -llz4"
  AC_TRY_LINK([#include <lz4.h>],
              [LZ4_versionString();],
             have_lz4=yes,
             have_lz4=no)
  AC_MSG_RESULT($have_lz4)

  if test "${have_lz4}" = "no" ; then
    LIBS="${OLD_LIBS}"
    echo "Building own liblz4"
  else
    LZ4_LIB="-llz4"
  fi
fi

############## libffi in pb mode ################

KERNEL_MACH="${MACH}"
KERNEL_TARGET_MACH="${TARGET_MACH}"

if test "${enable_pb}" = "yes" ; then
  enable_libffi=yes
  enable_foreign=yes
  SCHEME_LIBFFI=yes
  TARGET_MACH=${pb_machine_name}
  if test "${CROSS_MODE}" != "cross" ; then
    MACH=${pb_machine_name}
  fi
  CONFIGURE_RACKET_SO_COMPILE="${CONFIGURE_RACKET_SO_COMPILE} PLT_CS_MACHINE_TYPE=${KERNEL_TARGET_MACH}"
  if test "${enable_pbchunk}" != "no" ; then
    PBCHUNK_MODE=pbchunk
  fi
fi

libffi_unavailable_message="did not find working configuration"
complain_if_libffi_fails=yes
m4_include(../ac/libffi.m4)

############## other inferred machine properties ################

AC_CHECK_SIZEOF([void *])

m4_include(../ac/valid_sizeof.m4)

############## etxra checks ################

if test "${enable_check}" = "yes" ; then
  ENABLE_EXTRA_CHECKS=yes
fi

############## subconfigure ################

# Before libtool setup

CPPFLAGS="$CPPFLAGS $PREFLAGS"

SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} CC="'"'"${CC}"'"'
SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} CFLAGS="'"'"${CFLAGS}"'"'
SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} LDFLAGS="'"'"${LDFLAGS}"'"'
SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} LIBS="'"'"${LIBS}"'"'
SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} AR="'"'"${AR}"'"'
SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} ARFLAGS="'"'"${ARFLAGS}"'"'
SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} RANLIB="'"'"${RANLIB}"'"'
SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} WINDRES="'"'"${WINDRES}"'"'
SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} CPPFLAGS="'"'"${CPPFLAGS}"'"'

# Make sure the --enable-pthread result is propagated:
if test "${enable_pthread}" = "yes" ; then
  SUB_CONFIGURE_EXTRAS="$SUB_CONFIGURE_EXTRAS --enable-pthread"
else
  SUB_CONFIGURE_EXTRAS="$SUB_CONFIGURE_EXTRAS --disable-pthread"
fi

# Make sure the --enable-iconv result is propagated:
if test "${enable_iconv}" = "yes" ; then
  SUB_CONFIGURE_EXTRAS="$SUB_CONFIGURE_EXTRAS --enable-iconv"
else
  SUB_CONFIGURE_EXTRAS="$SUB_CONFIGURE_EXTRAS --disable-iconv"
fi
# Make sure the --enable-icu result is propagated:
if test "${enable_icu}" = "yes" ; then
  SUB_CONFIGURE_EXTRAS="$SUB_CONFIGURE_EXTRAS --enable-icu"
else
  SUB_CONFIGURE_EXTRAS="$SUB_CONFIGURE_EXTRAS --disable-icu"
fi
# Make sure the --enable-icu-dll result is propagated:
if test "${enable_icu_dll}" = "yes" ; then
  SUB_CONFIGURE_EXTRAS="$SUB_CONFIGURE_EXTRAS --enable-icu-dll"
else
  SUB_CONFIGURE_EXTRAS="$SUB_CONFIGURE_EXTRAS --disable-icu-dll"
fi

############## libtool ################

if test "${enable_shared}" = "yes" ; then
  echo "Configuring libtool"

  # Assuming an absolute "${libdir}":
  abslibdir="${libdir}"

  if test ! -d "../../lt" ; then
    mkdir "../../lt"
  fi
  abssrcdir=`(cd ${srcdir}; pwd)`

  if test "${LIBTOOLPROG}" = "" ; then  
    (cd ../../lt; sh ${abssrcdir}/../../lt/configure --enable-shared --disable-static)
    LIBTOOLPROG=`pwd`/../../lt/libtool
  fi

  if test "${need_gcc_static_libgcc}" = "yes" ; then
    need_gcc_static_libgcc=""
    if test "$CC" = "gcc" ; then 
      gcc_vers_three=`${CC} -v 2>&1 | grep "version 3[.]"`
      if test "$gcc_vers_three" = "" ; then
        need_gcc_static_libgcc=""
      else
        need_gcc_static_libgcc=" -XCClinker -static-libgcc"
      fi
    fi
  fi

  # Use only for standalone builds:
  AR="${LIBTOOLPROG} --mode=link --tag=CC $CC${need_gcc_static_libgcc}${ar_libtool_no_undefined} -release ${rktio_version} -rpath ${abslibdir} \$(ARLIBFLAGS) -o"
  # Used for a librktio convenience library:
  STATIC_AR="${LIBTOOLPROG} --mode=link --tag=CC $CC -o"
  ARFLAGS=""
  RANLIB=":"
  
  RKTLINKER="${LIBTOOLPROG} --mode=link --tag=CC $CC${need_gcc_static_libgcc}"
  CC="${LIBTOOLPROG} --mode=compile --tag=CC $CC"
  LTO="lo"
  LTA="la"
  STRIP_LIB_DEBUG=":"
  LIBSFX=la
  ICP_LIB="${LIBTOOLPROG} --mode=install install${ICP_STRIP_FLAG}"

  CONFIGURE_RACKET_SO_COMPILE="PLT_CS_MAKE_LINK_SHARED=y"
else
  ICP=cp
  LTO="o"
  LTA="a"
  RKTLINKER="${CC}"
  STATIC_AR="$AR"
  LIBSFX=so
  ICP_LIB=cp
  if test "${make_darwin_dylib}" = "yes" ; then
     LIBSFX="dylib"
     AR="${RKTLINKER} --shared -o"
     ARFLAGS=""
     LIBS="${LIBS} -framework CoreFoundation"
     ICP_LIB=cp
  fi
fi

############## final output ################

case "$srcdir" in
    /*)
        upsrcdir="$srcdir"
        ;;
    *)
        upsrcdir="../$srcdir"
        ;;
esac

m4_include(../ac/rktio_keep.m4)

RKTIO_CONFIGURE_ARGS="${keep_configure_args} ${SUB_CONFIGURE_EXTRAS}"

AC_SUBST(CC)
AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LD)
AC_SUBST(LDFLAGS)
AC_SUBST(LIBS)
AC_SUBST(LINK_DYNAMIC)
AC_SUBST(AR)
AC_SUBST(ARFLAGS)
AC_SUBST(RANLIB)
AC_SUBST(STATIC_AR)
AC_SUBST(WINDRES)
AC_SUBST(ICP)
AC_SUBST(ICP_LIB)
AC_SUBST(STRIP_DEBUG)
AC_SUBST(STRIP_LIB_DEBUG)
AC_SUBST(RKTLINKER)
AC_SUBST(POST_LINKER)
AC_SUBST(RKTL_PRE)
AC_SUBST(RKTL_POST)
AC_SUBST(RACKET)
AC_SUBST(BOOTFILE_RACKET)
AC_SUBST(SCHEME)
AC_SUBST(SCHEME_DIR)
AC_SUBST(MACH)
AC_SUBST(TARGET_MACH)
AC_SUBST(KERNEL_TARGET_MACH)
AC_SUBST(CROSS_MODE)
AC_SUBST(SETUP_BOOT_MODE)
AC_SUBST(OSX)
AC_SUBST(SIGNED_EXE)
AC_SUBST(MINGW)
AC_SUBST(Z_LIB)
AC_SUBST(LZ4_LIB)
AC_SUBST(DISABLE_ICONV)
AC_SUBST(DISABLE_CURSES)
AC_SUBST(CONFIGURE_RACKET_SO_COMPILE)
AC_SUBST(COMPRESS_COMP)
AC_SUBST(BOOT_COMPRESS_COMP)
AC_SUBST(FRAMEWORK_INSTALL_DIR)
AC_SUBST(FRAMEWORK_REL_INSTALL)
AC_SUBST(CROSS_COMPILE_TARGET_KIND)
AC_SUBST(CS_INSTALLED)
AC_SUBST(CS_COMPILED_SUBDIR)
AC_SUBST(DISABLE_WPO)
AC_SUBST(ENABLE_EXTRA_CHECKS)
AC_SUBST(SCHEME_LIBFFI)
AC_SUBST(PBCHUNK_MODE)
AC_SUBST(INSTALL_SETUP_FLAGS)
AC_SUBST(INSTALL_SETUP_RACKET_FLAGS)
AC_SUBST(INSTALL_LIBS_ENABLE)
AC_SUBST(PLT_CS_SLSP_SUFFIX)
AC_SUBST(RKTIO_CONFIGURE_ARGS)
AC_SUBST(CC_FOR_BUILD)
AC_SUBST(CFLAGS_FOR_BUILD)
AC_SUBST(upsrcdir)

makefiles="Makefile"

AC_OUTPUT($makefiles)

cp ${srcdir}/buildmain.zuo main.zuo

show_path_results
