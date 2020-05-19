
##################################################################
# This is the source for the `cfg-racket' script, to be compiled #
# by autoconf (use `../ac/make-configure`).                      #
##################################################################

# Remember:
#  CFLAGS - C compilation only
#  CPPFLAGS - C pre-processing and compilation for configure-time testing ONLY
#  COMPFLAGS - C compilation, but not configure-time tests
#  PREFLAGS - C preprocessing, but not configure-time tests
#  OPTIONS - C flags, not needed for configure-time tests
#  MZOPTIONS - Racket-only flags
#  MROPTIONS - GRacket-only flags
#  CGCOPTIONS - Boehm-GC-only flags
#  GC2OPTIONS - GC2-only flags
#
# Note: we use CPPFLAGS for configure-time testing only because
# it used to include C++ flags that we didn't want for Racket.
# hence PREFLAGS, which is initialized to the original CPPFLAGS.
#
# CC_FOR_BUILD is used for the Boehm GC build. In contrast to some
# other build processes, CC_FOR_BUILD needs to be consistent with CC
# in terms of its platform selection, and so it receives CFLAGS,
# PREFLAGS, and COMPFLAGS, too. If that doesn't work out, use
# `--enable-sgc', instead.

AC_INIT([Racket])
AC_CONFIG_SRCDIR(racket/src/bignum.c)
AC_CONFIG_HEADERS([racket/mzconfig.h])

AC_CONFIG_AUX_DIR(lt)
AC_CANONICAL_SYSTEM

AC_ARG_ENABLE(gracket, [  --enable-gracket        build GRacket as well as Racket (enabled by default)], , enable_gracket=yes )
AC_ARG_ENABLE(jit,     [  --enable-jit            support JIT compiler (enabled by default)], , enable_jit=yes)
AC_ARG_ENABLE(foreign, [  --enable-foreign        support foreign calls (enabled by default)], , enable_foreign=yes)
AC_ARG_ENABLE(places,  [  --enable-places         support places (3m only; usually enabled by default)])
AC_ARG_ENABLE(futures, [  --enable-futures        support futures (usually enabled by default)])
AC_ARG_ENABLE(float,   [  --enable-float          support single-precision floats (enabled by default)], , enable_float=yes)
AC_ARG_ENABLE(floatinstead, [  --enable-floatinstead   use single-precision by default (NOT RECOMMENDED)])
AC_ARG_ENABLE(extflonum,    [  --enable-extflonum      support extflonums (enabled by default, if available)], , enable_extflonum=default)

AC_ARG_ENABLE(racket,  [  --enable-racket=<path>  use <path> as Racket to build; or "auto" to create])

m4_include(../ac/path_arg.m4)

m4_include(../ac/natipkg_arg.m4)

AC_ARG_ENABLE(shared,  [  --enable-shared         create shared libraries (ok, but not recommended)])
AC_ARG_ENABLE(dynlib,  [  --enable-dynlib         same as --enable-shared])
AC_ARG_ENABLE(lt,      [  --enable-lt=<prog>      use <prog> instead of libtool; disable to use bundled], LIBTOOLPROG="$enableval", enable_lt=default)
m4_include(../ac/instlib_arg.m4)

AC_ARG_ENABLE(libffi,  [  --enable-libffi         use installed libffi (enabled by default for Unix)], , enable_libffi=default)

m4_include(../ac/sdk_arg.m4)

AC_ARG_ENABLE(csdefault,  [  --enable-csdefault      use CS as default build])
AC_ARG_ENABLE(cgcdefault, [  --enable-cgcdefault     use CGC as default build (NOT RECOMMENDED)])
AC_ARG_ENABLE(sgc,     [  --enable-sgc            use Senora GC instead of Boehm GC (enabled by default)], , enable_sgc=yes)
AC_ARG_ENABLE(sgcdebug,[  --enable-sgcdebug       use Senora GC for debugging (expensive; CGC only)])
AC_ARG_ENABLE(generations,[  --enable-generations    3m: support generational GC (enabled by default)], , enable_generations=yes)
AC_ARG_ENABLE(backtrace,  [  --enable-backtrace      3m: support GC backtrace dumps (expensive debug mode)])

AC_ARG_ENABLE(cify,       [  --enable-cify           compile startup code to C instead of bytecode])

AC_ARG_ENABLE(pthread, [  --enable-pthread        link with pthreads (usually auto-enabled if needed)])
AC_ARG_ENABLE(stackup, [  --enable-stackup        assume "up" if stack direction cannot be determined])
AC_ARG_ENABLE(bigendian, [  --enable-bigendian      assume "big" if endianness cannot be determined])
AC_ARG_ENABLE(ffipoll, [  --enable-ffipoll        FFI calls only when embedding program explicitly polls])

# AC_ARG_ENABLE(oskit,   [  --enable-oskit          compile OSKit-based Racket kernel])
# AC_ARG_ENABLE(smalloskit, [  --enable-smalloskit     compile small OSKit-based Racket kernel])

AC_ARG_ENABLE(gprof,   [  --enable-gprof          compile for profiling with gprof (gcc only)])
AC_ARG_ENABLE(gcov,    [  --enable-gcov           compile to gather gcov statistics (gcc3 only)])

m4_include(../ac/strip_arg.m4)
AC_ARG_ENABLE(noopt,   [  --enable-noopt          drop -O C flags (useful for low-level debugging)])
m4_include(../ac/ubsan_arg.m4)
AC_ARG_ENABLE(jitframe,[  --enable-jitframe       x86_64: use frame pointer for internal calls])

AC_ARG_ENABLE(werror,  [  --enable-werror         compile sources with warnings as errors])  

m4_include(../ac/crossany_arg.m4)

###### Some flags imply other flags #######

if test "${enable_smalloskit}" = "yes" ; then
  enable_oskit=yes
fi

if test "${enable_oskit}" = "yes" ; then
  enable_gracket=no
fi

if test "${enable_dynlib}" = "no" ; then
  enable_shared=no
fi
if test "${enable_dynlib}" = "yes" ; then
  enable_shared=yes
fi
if test "${enable_shared}" != "yes" ; then
  enable_lt=no
fi
if test "${enable_lt}" = "no" ; then
  LIBTOOLPROG=""
fi
if test "${enable_lt}" = "yes" ; then
  echo "ERROR: no program given for libtool!"
  echo " Supply a program for --enable-lt, something like this:"
  echo "   --enable-lt=/usr/bin/libtool"
  exit 1
fi
if test "${enable_lt}" = "default" ; then
  if `which libtool > /dev/null` ; then
    LIBTOOLPROG="libtool"
  fi
fi

if test "${enable_shared}" = "yes" ; then
  case "$host_os" in
  darwin*)
    if test "${enable_xonx}" != "yes" ; then
       echo "ERROR: don't use --enable-shared or --enable-dynlib under Mac OS,"
       echo "       unless you also use --enable-xonx"
       exit 1
    fi
  ;;
  *mingw*)
   echo "ERROR: don't use --enable-shared or --enable-dynlib with mingw"
   exit 1
  ;;
  esac
fi

m4_include(../ac/sdk.m4)

if test "${enable_iconv}" = "" ; then
  enable_iconv=yes
fi

############## Install targets ################

m4_include(../ac/path.m4)

###### Make sure GRacket is really there ######

if test "${enable_gracket}" = "yes" ; then
  if test ! -d $srcdir/gracket ; then
    enable_gracket=no
  fi
fi

###### Tell user what flags we have #######

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

if test "${enable_cgcdefault}" != "" ; then
   if test "${enable_csdefault}" != "" ; then
     echo "ERROR: cannot specify both --enable-cgcdefault and --enable-csdefault"
   fi
fi
show_explicitly_enabled "${enable_cgcdefault}" "CGC as default" "Note that this mode is NOT RECOMMENDED for normal Racket use"
show_explicitly_enabled "${enable_csdefault}" "CS will be default"

show_explicitly_disabled "${enable_docs}" "Documentation build"
show_explicitly_enabled "${enable_usersetup}" "User-specific setup on install"
m4_include(../ac/natipkg_show.m4)

show_explicitly_enabled "${enable_xonx}" "Unix style"
show_explicitly_enabled "${enable_shared}" "Shared libraries"

show_explicitly_disabled "${enable_gracket}" GRacket

if test "$LIBTOOLPROG" != "" ; then
  echo "=== Libtool program: $LIBTOOLPROG"
fi
show_explicitly_enabled "${enable_orig}" "Original install tree"

show_explicitly_disabled "${enable_jit}" JIT

show_explicitly_disabled "${enable_foreign}" Foreign
show_explicitly_enabled "${enable_libffi}" "Installed libffi"
show_explicitly_disabled "${enable_libffi}" "Installed libffi"

show_explicitly_enabled "${enable_places}" Places
show_explicitly_disabled "${enable_places}" Places
show_explicitly_enabled "${enable_futures}" Futures
show_explicitly_disabled "${enable_futures}" Futures

show_explicitly_disabled "${enable_sgc}" SGC
show_explicitly_enabled "${enable_sgcdebug}" "SGC debug mode"
show_explicitly_disabled "${enable_generations}" "3m generational GC"
show_explicitly_enabled "${enable_backtrace}" "3m GC backtraces" "Note that this mode is not intended for normal Racket use"
show_explicitly_enabled "${enable_cify}" "Startup compiled to C"
show_explicitly_disabled "${enable_cify}" "Startup compiled to C"

show_explicitly_disabled "${enable_float}" "Single-precision floats"
show_explicitly_enabled "${enable_floatinstead}" "Single-precision default floats" "Note that this mode is NOT RECOMMENDED"
show_explicitly_enabled "${enable_extflonum}" "Extflonums"
show_explicitly_disabled "${enable_extflonum}" "Extflonums"

show_explicitly_enabled "${enable_pthread}" "pthreads"
show_explicitly_disabled "${enable_pthread}" "pthreads"
show_explicitly_enabled "${enable_ffipoll}" "ffipoll"
show_explicitly_enabled "${enable_oskit}" "OSKit"
show_explicitly_enabled "${enable_smalloskit}" "OSKit small mode"

show_explicitly_enabled "${enable_gprof}" "gprof"
show_explicitly_enabled "${enable_gcov}" "gcov"

show_explicitly_enabled "${enable_jitframe}" "jitframe"

show_explicitly_enabled "${enable_noopt}" "No-optimization" "Note that this mode is intended only for debugging purposes"
m4_include(../ac/strip_show.m4)

m4_include(../ac/instlib.m4)

m4_include(../ac/sdk_show.m4)

if test "${enable_racket}" != "" ; then
  if test "${enable_racket}" = "auto" ; then
    echo "=== Creating and using local Racket executable"
  else
    if test ! -f "${enable_racket}"; then
      echo "cannot find racket executable in ${enable_racket}"
      exit 1
    else
      echo "=== Using Racket executable ${enable_racket}"
    fi	
  fi 
fi

m4_include(../ac/path_pkgscope.m4)

m4_include(../ac/crossany.m4)

###### Some defaults #######

OPTIONS=

# GC Directory
GCDIR=gc

MZBINTARGET=normal-bin
MZINSTALLTARGET=unix-install
MZINSTALLBINDIR='$(bindir)'

MZOPTIONS=
CGCOPTIONS=
GC2OPTIONS=
DYN_CFLAGS=

WXVARIANT="wx_xt"

MROPTIONS=
INCLUDEDEP="#"
WX_MMD_FLAG=

DIRCVTPRE=
DIRCVTPOST=
PWD=pwd
WINDRES=windres
DLLTOOL=dlltool

PREFLAGS="$CPPFLAGS"

OWN_LIBFFI="ON"

ar_libtool_no_undefined=""
LIBRACKET_DEP=""

EXE_SUFFIX=
SO_SUFFIX=.so

POST_LINKER="echo"

MMM=3m
MMM_INSTALLED=
MMM_CAP_INSTALLED=
CGC=cgc
CGC_INSTALLED=cgc
CGC_CAP_INSTALLED=CGC
MAIN_VARIANT=3m

INSTALL_SETUP_FLAGS=
INSTALL_SETUP_RACKET_FLAGS=

use_flag_pthread=yes
use_flag_posix_pthread=no
mzrt_needs_pthread=yes
skip_iconv_check=no
check_page_size=yes
try_no_nullability_completeness=no
check_for_unwind=no

if test "${enable_cify}" = "yes" ; then
  STARTUP_AS_BYTECODE=_bytecode
  STARTUP_AS_C=
  STARTUP_AS_AUTO=_auto
else
  if test "${enable_cify}" = "no" ; then
    STARTUP_AS_BYTECODE=
    STARTUP_AS_C=_c
    STARTUP_AS_AUTO=_auto
  else
    STARTUP_AS_BYTECODE=_bytecode
    STARTUP_AS_C=_c
    STARTUP_AS_AUTO=
  fi
fi

MAKE_LOCAL_RACKET=no-local-racket

###### OSKit stuff #######

if test "${enable_oskit}" = "yes" ; then
  OSKHOME=${OSKHOME:-/usr/local/oskit}

  if test ! -d ${OSKHOME}/bin ; then
    AC_MSG_ERROR(cannot find OSKit support; try defining OSKHOME)
  fi

  CC=`(ls ${OSKHOME}/bin/*-oskit-gcc | head -1) 2> /dev/null`
  if test ! -x "${CC}" ; then
    AC_MSG_ERROR(can't find *-oskit-gcc compiler script in ${OSKHOME}/bin)
  fi

  PREFLAGS="-nostdinc -I${OSKHOME}/include/oskit -I${OSKHOME}/include/oskit/freebsd "
  PREFLAGS="$PREFLAGS -I${OSKHOME}/include/oskit/c -I${OSKHOME}/include -I/usr/include"

  GCDIR=sgc
  OPTIONS="-DOSKIT -DUSE_SENORA_GC -DSGC_AUTO_ROOTS=0"

  if test "${enable_smalloskit}" = "yes" ; then
    EXTRA_OSK_LIBS=
  else
    EXTRA_OSK_LIBS="-loskit_linux_dev -loskit_linux_fs -loskit_diskpart -loskit_freebsd_net"
    OPTIONS="$OPTIONS -DOSK_FILESYSTEMS_AND_ETHERNET"
  fi

  MZBINTARGET=oskit
else
  enable_oskit=no
fi

###### float stuff #######

if test "${enable_floatinstead}" = "yes" ; then
  enable_float=yes
  AC_DEFINE(USE_SINGLE_FLOATS_AS_DEFAULT,1,[Single-precision floats by default])
fi

if test "${enable_float}" = "yes" ; then
  AC_DEFINE(USE_SINGLE_FLOATS,1,[Single-precision floats])
fi

if test "${enable_extflonum}" = "no" ; then
  AC_DEFINE(MZ_NO_EXTFLONUMS,1,[Extflonums disabled])
fi

###### Autoconfigure #######

COMPFLAGS=""

ORIG_CC="${CC}"
ORIG_CPP="${CPP}"
# Include `--enable-portable-binary' by default for libffi
SUB_CONFIGURE_EXTRAS=" --enable-portable-binary"

if test "${enable_sysroot}" != "" ; then
   PREFLAGS="--sysroot=${enable_sysroot} ${PREFLAGS}"
   CPPFLAGS="--sysroot=${enable_sysroot} ${CPPFLAGS}"
   LDFLAGS="--sysroot=${enable_sysroot} ${LDFLAGS}"
   SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} CPPFLAGS="'"'"${PREFLAGS}"'"'
   SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} LDFLAGS="'"'"${LDFLAGS}"'"'
fi

if test "${enable_ios}" != "" ; then
  case "$host_cpu" in
    aarch64)
     IOS_ARCH=arm64
     ;;
    *)
     IOS_ARCH=$host_cpu
     ;;
  esac
  case "${enable_ios}" in
    iPhoneOS|iPhoneSimulator)
     ios_sdk=/Applications/Xcode.app/Contents/Developer/Platforms/${enable_ios}.platform/Developer/SDKs/${enable_ios}.sdk
     ;;
    *)
     ios_sdk="${enable_ios}"
     ;;
  esac
  IOS_PHONE_VERS="6.0"
  PREFLAGS="$PREFLAGS -DTARGET_OS_IPHONE=1"
  CPPFLAGS="$CPPFLAGS -DTARGET_OS_IPHONE=1"
  PREFLAGS="$PREFLAGS -arch ${IOS_ARCH} -isysroot ${ios_sdk} -miphoneos-version-min=${IOS_PHONE_VERS}"
  CPPFLAGS="$CPPFLAGS -arch ${IOS_ARCH} -isysroot ${ios_sdk} -miphoneos-version-min=${IOS_PHONE_VERS}"
  LDFLAGS="$LDFLAGS -arch ${IOS_ARCH} -isysroot ${ios_sdk} -miphoneos-version-min=${IOS_PHONE_VERS} -liconv"
  SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} CFLAGS="'"'"${CFLAGS}"'"'
  SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} CPPFLAGS="'"'"${PREFLAGS}"'"'
  SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} LDFLAGS="'"'"${LDFLAGS}"'"'
fi


if test "${enable_oskit}" = "no" ; then
  # Auto-set CC, CPP, etc.
  
  if test "${CFLAGS}${CC}${CPP}" = "" ; then
    starts_out_default=yes
  else
    starts_out_default=no
  fi
  
  AC_PROG_CC
  AC_PROG_CPP

  if test "$starts_out_default" = "yes" ; then
    if test "$GCC" = "yes" ; then
      # Auto selection of C compiler picked GCC, so we
      # assume it also picked the GNU preprocessor; move
      # auto-picked CFLAGS to PREFLAGS so that compilation
      # and preprocessing are in sync (e.g., for optimization flags)
      PREFLAGS="${CFLAGS} ${PREFLAGS}"
      CPPFLAGS="${CFLAGS} ${CPPFLAGS}"
      CFLAGS=""
    fi
  fi
  if test "$AS" = '' ; then 
    AS="${ac_tool_prefix}as"
    as_was_set=no
  else
    as_was_set=yes
  fi
fi
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
SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} AR_FLAGS="'"'"${ARFLAGS}"'"'

is_gmake=`make -v no-such-target-we-hope 2>&1 | grep "GNU Make"`

# If using gcc, we want all warnings:
changequote(<<, >>)dnl
is_gcc=`$CC -v 2>&1 | tail -n 1 | grep -E '^gcc version [[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+ \([^\)]+\)[[:space:]]*$'`
changequote([, ])dnl

# We also need to test if $CC is gcc itself because on mac,
# where clang impersonates gcc, although is_gcc is false, we want
# to use it as if it was gcc.
# See https://github.com/racket/racket/pull/2897#pullrequestreview-314906673
if test "$is_gcc" != "" || test "`basename $CC`" = "gcc"; then
  COMPFLAGS="$COMPFLAGS -Wall"

  # Use -MMD when we have gcc and gnumake:
  if test "$is_gmake" = "" ; then
    WX_MMD_FLAG=""
  else
    WX_MMD_FLAG="-MMD"
  fi

  # Compile mzdyn.o with -fPIC
  DYN_CFLAGS="-fPIC"
fi

# When GNU Make is present, use version.mak
if test "$is_gmake" != ""; then
   INCLUDEDEP="-include"
fi

if test "$REZ" = '' ; then 
 REZ=/Developer/Tools/Rez
fi

if test "${enable_gracket}" = "yes" ; then
  MAKE_GRACKET=gracket
else
  MAKE_GRACKET=no
fi

AC_CHECK_LIB(m, cos)
AC_CHECK_LIB(dl, dlopen)

PROFFLAGS=""

if test "${enable_gprof}" = "yes" ; then
  MZOPTIONS="$MZOPTIONS -DDONT_ITIMER"
  PROFFLAGS="$PROFFLAGS -pg"
  LIBS="$LIBS -pg"
fi

if test "${enable_gcov}" = "yes" ; then
  PROFFLAGS="$PROFFLAGS -fprofile-arcs -ftest-coverage"
fi

if test "${enable_jitframe}" = "yes" ; then
  MZOPTIONS="$MZOPTIONS -DMZ_PROLOG_CREATE_FULL_STACK_FRAME"
fi

ORIG_CC_FOR_BUILD="${CC_FOR_BUILD}"
if test "$CC_FOR_BUILD" = "" ; then 
  CC_FOR_BUILD="$CC"
fi

if test "${enable_shared}" = "yes" ; then
  LIBRACKET_DEP="${LIBRACKET_DEP} libmzgc.la"
  INSTALL_LIBS_ENABLE=install
fi

if test "${enable_foreign}" = "yes" ; then
  check_for_mprotect=yes
fi
if test "${enable_jit}" = "yes" ; then
  check_for_mprotect=yes
fi

############## platform tests ################

# for flags we don't want to use in config tests:
EXTRALIBS=

# for gmp assembly:
EXTRA_GMP_OBJ=
EXTRA_GMP_DEP=

# For Racket targets:
OSX=".osx"
NOT_OSX=""
MINGW=".mingw"
NOT_MINGW=""
CGC_X86_64=""

case "$host_os" in
  solaris2*)
    STATICLINK="-Wl,-Bstatic" # after -ldl
    LIBS="$LIBS -lsocket -lnsl -lintl"
    need_gcc_static_libgcc="yes"
    check_gcc_dash_e="yes"
    use_flag_pthread="no"
    use_flag_posix_pthread="yes"
    ;;
  aix*)
    enable_cgcdefault="yes"
    EXTRALIBS="-Wl,-brtl,-bE:\$(srcdir)/../racket/include/racket.exp"
    ;;
  *freebsd*)
    LIBS="$LIBS -rdynamic"
    DYN_CFLAGS="-fPIC"
    enable_pthread_by_default=yes
    ;;
  openbsd*)
    LIBS="$LIBS -Wl,--export-dynamic"
    enable_pthread_by_default=yes
    ;;
  bitrig*)
    LIBS="$LIBS -Wl,--export-dynamic"
    enable_pthread_by_default=yes
    ;;
  dragonfly*)
    LIBS="$LIBS -Wl,--export-dynamic"
    enable_pthread_by_default=yes
    ;;
  netbsd*)
    LIBS="$LIBS -rdynamic"
    POST_LINKER="paxctl +m"
    ;;
  irix*)
    enable_cgcdefault="yes"
    STATICLINK="/usr/lib/libC.a /usr/lib/libmalloc.a"
    if test "$X_PRE_LIBS" = " -lSM -lICE" ; then
      # For some reason, works best to drop these
      X_PRE_LIBS=""
    fi
    ;;
  linux*)
    LIBS="$LIBS -ldl -lm -rdynamic"
    DYN_CFLAGS="-fPIC"
    case "$host_cpu" in
      #Required for CentOS 4.6
      x86_64)
       enable_parallel_by_default=yes
       CGC_X86_64="1"
       check_for_unwind=REG_RSP
       ;;
      ppc|powerpc)
       ;;
      alpha)
       EXTRA_GMP_OBJ='gmp_alpha_gcc.$(LTO)'
       EXTRA_GMP_DEP='$(EXTRA_GMP_DEP_FILE)'
       ;;
      i386|i486|i586|i686)
       enable_parallel_by_default=yes
       check_for_unwind=REG_ESP
       ;;
      arm*)
       EXTRA_GMP_OBJ='gmp_arm_gcc.$(LTO)'
       EXTRA_GMP_DEP='$(EXTRA_GMP_DEP_FILE)'
       ;;
      *)
       ;;
    esac
    ;;
  osf1*)
    enable_cgcdefault="yes"
    if test "$CC" = "cc" ; then 
      COMPFLAGS="$COMPFLAGS -ieee_with_inexact -assume noaligned_objects"
    elif test "$CC" = "gcc" ; then 
      EXTRA_GMP_OBJ='gmp_alpha_gcc.$(LTO)'
      EXTRA_GMP_DEP='$(EXTRA_GMP_DEP_FILE)'
    fi
    ;;
  hpux*)
    enable_cgcdefault="yes"
    if test "$CC" = "gcc"; then
      COMPFLAGS="$COMPFLAGS -fPIC"
    else
      CFLAGS="$CFLAGS -Wp,-H,64000"
      PREFLAGS="$PREFLAGS -D_HPUX_SOURCE"
      COMPFLAGS="$COMPFLAGS -Aa +Z"
      CGCOPTIONS="$CGCOPTIONS +ESdbgasm"
      MZOPTIONS="$MZOPTIONS +e"
    fi
    LIBS="$LIBS -Wl,-E"
    ;;
  *mingw*)
    enable_parallel_by_default=yes
    mzrt_needs_pthread=no
    use_flag_pthread=no
    MZOPTIONS="$MZOPTIONS -fno-omit-frame-pointer" # to make JIT backtraces work
    MINGW=""
    NOT_MINGW=".other"
    MZINSTALLTARGET=mingw-install
    MZINSTALLBINDIR="${MZINSTALLBINDIR}/.."
    EXE_SUFFIX=".exe"
    COLLECTS_PATH="collects"
    GUI_COLLECTS_PATH="../collects"
    CONFIG_PATH="etc"
    GUI_CONFIG_PATH="../etc"
    skip_iconv_check=yes
    check_for_mprotect=no
    # ".a" is typically not useful, since we always build a DLL:
    if test "${enable_libs}" = "" ; then
      INSTALL_LIBS_ENABLE=no-install
    fi
    AC_DEFINE(HAVE_STDINT_H,1,[Have stdint.h])
    if `which ${host}-windres > /dev/null` ; then
      WINDRES="${host}-windres"
    fi
    if `which ${host}-dlltool > /dev/null` ; then
      DLLTOOL="${host}-dlltool"
    fi

    case "$build_os" in
      *cygwin*)
        PWD="cygpath -m \\\`pwd\\\`"
        DIRCVTPRE="\`cygpath -m "
        DIRCVTPOST="\`"
        ;;
    esac
    ;;    
  cygwin*)
    MZINSTALLTARGET=unix-cygwin-install
    if test "${enable_shared}" = "yes" ; then
      ar_libtool_no_undefined=" -no-undefined"
      LIBRACKET_DEP="${LIBRACKET_DEP} -liconv"
    fi
    EXE_SUFFIX=".exe"
    ;;
  darwin*)

    m4_include(../ac/sdk_mac.m4)

    case "$host_cpu" in
      i386|x86_64)
       enable_parallel_by_default=yes
       ;;
      *)
       ;;
    esac

    PREFLAGS="$PREFLAGS -DOS_X -D_DARWIN_UNLIMITED_SELECT"

    # -pthread is not needed and triggers a warning
    use_flag_pthread=no

    # Use -Wno-nullability-completeness if supported
    try_no_nullability_completeness=yes

    # ".a" is typically not useful, since we always build a ".dylib":
    if test "${enable_libs}" = "" ; then
      INSTALL_LIBS_ENABLE=no-install
    fi

    SO_SUFFIX=.dylib

    if test "${need_cc_in_extras}" = "yes" ; then
      SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} CC="'"'"${CC}"'"'
    fi
    if test "${need_cpp_in_extras}" = "yes" ; then
      SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} CPP="'"'"${CPP}"'"'
    fi
    if test "${need_ld_in_extras}" = "yes" ; then
      SUB_CONFIGURE_EXTRAS="${SUB_CONFIGURE_EXTRAS} LD="'"'"${LD}"'"'
    fi

    if test "${enable_quartz}" = "yes" ; then
      WXVARIANT="wx_mac"
      INCLUDEDEP="-include"
      OPTIONS="$OPTIONS -fno-common"
      OSX=""
      NOT_OSX=".other"
      MZINSTALLTARGET=osx-install
      DYN_CFLAGS=""
      if test "${enable_libfw}" = "yes" ; then
        FRAMEWORK_INSTALL_DIR=/Library/Frameworks
        FRAMEWORK_REL_INSTALL=no
        FRAMEWORK_PREFIX=''
      elif test "${enable_userfw}" = "yes" ; then
        FRAMEWORK_INSTALL_DIR=~/Library/Frameworks
        FRAMEWORK_REL_INSTALL=no
        FRAMEWORK_PREFIX=''
      else
        FRAMEWORK_INSTALL_DIR='${libpltdir}'
        FRAMEWORK_REL_INSTALL=yes
        if test "${libpltdir_rel}" = "" ; then
          FRAMEWORK_PREFIX='$(FRAMEWORK_ABS_PREFIX)'
        else
          FRAMEWORK_PREFIX='$(FRAMEWORK_REL_PREFIX)'
        fi
      fi
      if test "${enable_embedfw}" = "yes" ; then
        strip_needs_dash_s=yes
      fi
    else
      PREFLAGS="$PREFLAGS -DXONX "
      LIBS="$LIBS -framework CoreFoundation"
      strip_needs_dash_s=yes
    fi
    ;;
  nto-qnx*)
    enable_sgc=yes
    use_flag_pthread=no
    LIBS="$LIBS -lsocket -Wl,--export-dynamic"
    ;;
  haiku*)
	use_flag_pthread=no
	enable_pthread_by_default=yes
    LIBS="$LIBS -lnetwork"
    ;;
  *)
    ;;
esac

case "$host_cpu" in
  alpha | sparc | powerpc)
    if test "$CC" = "gcc" ; then
      if test "$as_was_set" = "no" ; then
       AS="gcc -c -x assembler-with-cpp"
      fi
    fi
    ;; 
  *)
    ;;
esac

############## GC variant ################

if test "${enable_cgcdefault}" ; then
   MMM_INSTALLED=3m
   MMM_CAP_INSTALLED=3m
   CGC_INSTALLED=
   CGC_CAP_INSTALLED=
   MAIN_VARIANT=cgc
fi
MAIN_MAKE_TARGET="${MAIN_VARIANT}"

if test "${enable_racket}" = "" ; then
  CS_BOOTSTRAP_HELP="${MAIN_VARIANT}"
else
  CS_BOOTSTRAP_HELP="no-${MAIN_VARIANT}"
fi

if test "${enable_csdefault}" ; then
   MMM_INSTALLED=3m
   MMM_CAP_INSTALLED=3m
   MAIN_MAKE_TARGET=racketcs
fi

############## SGC ################

if test "${enable_sgcdebug}" = "yes" ; then
  enable_sgc=yes
  OPTIONS="$OPTIONS -DSGC_STD_DEBUGGING=1"
fi

if test "${enable_sgc}" = "yes" ; then
  GCDIR=sgc
  OPTIONS="$OPTIONS -DUSE_SENORA_GC"
fi

if test "${enable_generations}" = "yes" ; then
  AC_DEFINE(USE_GC_GENS, 1,[GC Generations])
else
  AC_DEFINE(USE_GC_GENS, 0,[GC Generations])
fi

############## Strip tool ################

m4_include(../ac/strip.m4)

############## C flags ################

AC_LANG_C

[ msg="for inline keyword" ]
AC_MSG_CHECKING($msg)
AC_COMPILE_IFELSE([AC_LANG_SOURCE([
   static inline int foo() { return 0; }
   int main() {
      return foo();
   }])], 
  inline=yes, inline=no)
if test "$inline" = "no" ; then
  MZOPTIONS="$MZOPTIONS -DNO_INLINE_KEYWORD"
fi
AC_MSG_RESULT($inline) 

[ msg="for noinline attribute" ]
AC_MSG_CHECKING($msg)
AC_COMPILE_IFELSE([AC_LANG_SOURCE([
   static int foo() __attribute__ ((noinline));
   static int foo() { return 0; }
   int main() {
      return foo();
   }])], noinline=yes, noinline=no)
if test "$noinline" = "yes" ; then
  AC_DEFINE(MZ_USE_NOINLINE,1,[Have noinline attribute])
fi
AC_MSG_RESULT($noinline) 

[ msg="for GNU preprocessor" ]
AC_MSG_CHECKING($msg)
AC_COMPILE_IFELSE([AC_LANG_SOURCE([
   int main () {
   #ifdef __GNUC__
    return 0;
   #else
    if; // should fail
   #endif
   }])], using_gnu_cpp=yes, using_gnu_cpp=no)
if test "$using_gnu_cpp" = "yes" ; then
  XFORMFLAGS="$XFORMFLAGS --keep-lines"
  case "$build_os" in
    *cygwin*)
      XFORMFLAGS="$XFORMFLAGS --D-via-include"
     ;;
  esac
fi
AC_MSG_RESULT($using_gnu_cpp) 

# Although rktio takes care of iconv, we need to know whether
# to link to it
m4_include(../ac/iconv.m4)

if test "${check_for_mprotect}" = "yes" ; then
  [ msg="for mmap and mprotect" ]
  AC_MSG_CHECKING($msg)
  AC_LINK_IFELSE([AC_LANG_SOURCE([
     #include <sys/mman.h>
     #include <fcntl.h>
     int main() {
      void *p;
      p = mmap(0, 2 << 16, PROT_READ | PROT_WRITE, MAP_PRIVATE, open("/dev/zero", O_RDWR), 0);
      mprotect(p, 2 << 16, PROT_READ | PROT_WRITE);
      return 0;
     }])], use_mprotect=yes, use_mprotect=no)
  AC_MSG_RESULT($use_mprotect)
  if test "${use_mprotect}" = "yes" ; then
     AC_DEFINE(HAVE_MMAP_MPROTECT,1,[Have mmap and mprotect])
  fi

  if test "${use_mprotect}" = "yes" && test "${enable_sgc}" != "yes" ; then
    [ msg="mprotect with PROT_EXEC" ]
    AC_MSG_CHECKING($msg)
    AC_LINK_IFELSE([AC_LANG_SOURCE([
       #include <sys/mman.h>
       #include <fcntl.h>
       int main() {
        void *p;
        p = mmap(0, 2 << 16, PROT_READ | PROT_WRITE, MAP_PRIVATE, open("/dev/zero", O_RDWR), 0);
        if (mprotect(p, 2 << 16, PROT_READ | PROT_WRITE | PROT_EXEC)) return 1;
        return 0;
       }])], can_mprotect_exec=yes, can_mprotect_exec=no)
    AC_MSG_RESULT($can_mprotect_exec)
    if test "${can_mprotect_exec}" = "no" ; then
      echo "Senora GC is required due to mprotect() failure"
    fi
  fi
fi

if test "${check_for_unwind}" != "no" ; then
  [ msg="for unwind support" ]
  AC_MSG_CHECKING($msg)
  AC_COMPILE_IFELSE([AC_LANG_SOURCE([
     #include <inttypes.h>
     #define __USE_GNU
     #include <ucontext.h>
     int main() {
        return ${check_for_unwind};
     }])], can_unwind=yes, can_unwind=no)
  if test "$can_unwind" = "no" ; then
    AC_DEFINE(MZ_NO_UNWIND_SUPPORT,1,[Missing ucontext support])
  fi
  AC_MSG_RESULT($can_unwind)
fi

if test "${check_page_size}" = "yes" ; then
  [ msg="for large page size" ]
  AC_MSG_CHECKING($msg)
  AC_TRY_RUN(
[     #include <unistd.h>]
     int main() {
      return !(getpagesize() > (1 << 14));
     }, use_large_page_size=yes, use_large_page_size=no, use_large_page_size=no)
  AC_MSG_RESULT($use_large_page_size)
  if test "${use_large_page_size}" = "yes" ; then
     AC_DEFINE(MZ_USE_LARGE_PAGE_SIZE,1,[Use large page size])
  fi
fi

[ msg="for __builtin_popcount" ]
AC_MSG_CHECKING($msg)
AC_LINK_IFELSE([AC_LANG_SOURCE([
    int main(int argc, char **argv) {
      unsigned int i = argc;
      return __builtin_popcount(i);
    }])], has_builtin_popcount=yes, has_builtin_popcount=no)
AC_MSG_RESULT($has_builtin_popcount)
if test "${has_builtin_popcount}" = "yes" ; then
   AC_DEFINE(MZ_HAS_BUILTIN_POPCOUNT,1,[Has __builtin_popcount])
fi

[ msg="for __builtin_clz" ]
AC_MSG_CHECKING($msg)
AC_LINK_IFELSE([AC_LANG_SOURCE([
    int main(int argc, char **argv) {
      unsigned int i = argc;
      return __builtin_clz(i);
    }])], has_builtin_clz=yes, has_builtin_clz=no)
AC_MSG_RESULT($has_builtin_clz)
if test "${has_builtin_clz}" = "yes" ; then
   AC_DEFINE(MZ_HAS_BUILTIN_CLZ,1,[Has __builtin_clz])
fi

if test "${enable_backtrace}" = "yes" ; then
  GC2OPTIONS="$GC2OPTIONS -DMZ_GC_BACKTRACE"
fi

LFS_CFLAGS=`getconf LFS_CFLAGS 2> /dev/null`
if test "${LFS_CFLAGS}" != "" && test "${LFS_CFLAGS}" != "undefined"; then
  echo "Large-file support: ${LFS_CFLAGS}"
  MZOPTIONS="${MZOPTIONS} ${LFS_CFLAGS}"  
fi

if test "${try_no_nullability_completeness}" = "yes" ; then
  [ msg="for -Wno-nullability-completeness" ]
  AC_MSG_CHECKING($msg)
  OLD_CFLAGS="${CFLAGS}"
  CFLAGS="${CFLAGS}  -Wno-nullability-completeness"
  AC_COMPILE_IFELSE([AC_LANG_SOURCE([int main() { return 0; }])], nonullcomp=yes, nonullcomp=no)
  if test "$nonullcomp" = "yes" ; then
    GC2OPTIONS="$GC2OPTIONS -Wno-nullability-completeness"
  fi
  AC_MSG_RESULT($nonullcomp)  
  CFLAGS="${OLD_CFLAGS}"
fi

###### Get data sizes, stack direction, and endianness #######

AC_CHECK_SIZEOF(char)
AC_CHECK_SIZEOF(short)
AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(long)
AC_CHECK_SIZEOF(long long)
AC_CHECK_SIZEOF([void *])
AC_CHECK_SIZEOF(bool, unused, [#include <stdbool.h>])

m4_include(../ac/valid_sizeof.m4)

AC_TYPE_INTPTR_T
AC_TYPE_UINTPTR_T

[ msg="for stack direction" ]
AC_MSG_CHECKING($msg)
AC_TRY_RUN(
   int grows_down_p(int n, void *cmp) {
     if (!cmp)
       return grows_down_p(10, &cmp);
     else if (!n)
       return ((unsigned long)&cmp < (unsigned long)cmp);
     else
       return grows_down_p(n - 1, cmp);
   }
   int main() {
      return grows_down_p(0, 0);
   }, stack_direction=up, stack_direction=down, stack_direction=unknown)
AC_MSG_RESULT($stack_direction) 

if test "${stack_direction}" = "unknown" ; then
  if test "${enable_stackup}" = "yes" ; then
    stack_direction=up
  else
    echo configure: warning: cannot determine stack direction, assuming down
  fi
fi

if test "${stack_direction}" = "up" ; then
  AC_DEFINE(STACK_DIRECTION,1,[Stack direction up])
fi
if test "${stack_direction}" = "down" ; then
  AC_DEFINE(STACK_DIRECTION,-1,[Stack direction down])
fi

AC_C_BIGENDIAN(endianness=big, endianness=little, endianness=unknown)
if test "${endianness}" = "unknown" ; then
  if test "${enable_bigendian}" = "yes" ; then
    endianness=big
  else
    echo configure: warning: cannot determine endianness, assuming little
  fi
fi

if test "${endianness}" = "big" ; then
  AC_DEFINE(SCHEME_BIG_ENDIAN,1,[Big endian])
fi

################### JIT ####################

if test "${enable_jit}" = "no" ; then
   PREFLAGS="${PREFLAGS} -DMZ_DONT_USE_JIT"
   if test "${enable_futures}" = "yes" ; then
     echo configure: cannot enable futures and disable the JIT
     exit 1
   fi
   enable_futures=no
fi

############### places ###################

if test "${enable_parallel_by_default}" = "yes" ; then
  if test "${enable_places}" = "" ; then
    enable_places=yes
  fi
fi

if test "${enable_places}" = "yes" ; then
  AC_DEFINE(MZ_USE_PLACES,1,[Places enabled])
  enable_mzrt=yes
fi

############### futures ###################

if test "${enable_parallel_by_default}" = "yes" ; then
  if test "${enable_futures}" = "" ; then
    enable_futures=yes
  fi
fi

if test "${enable_futures}" = "yes" ; then
  AC_DEFINE(MZ_USE_FUTURES,1,[Futures enabled])
  enable_mzrt=yes
fi

############### ffipoll ###################

if test "${enable_ffipoll}" = "yes" ; then
  AC_DEFINE(MZ_USE_FFIPOLL,1,[FFIPoll enabled])
fi

############## compare-and-swap ################

if test "${enable_mzrt}" = "yes" ; then
  [ msg="for compare-and-swap" ]
  AC_MSG_CHECKING($msg)
  AC_LINK_IFELSE([AC_LANG_SOURCE([
   int check1(long *addr, long old, long new_val) {
     return __sync_bool_compare_and_swap(addr, old, new_val);
   }
   int check2(short *addr, short old, short new_val) {
     return __sync_bool_compare_and_swap(addr, old, new_val);
   }
   int main() {
      long l = 2; short s = 3;
      return !check1(&l, 2, 4) || !check2(&s, 3, 6);
   }])], cas_available=yes, cas_available=no)
  AC_MSG_RESULT($cas_available)
  if test "${cas_available}" = "yes" ; then
    AC_DEFINE(MZ_CAS_AVAILABLE,1,[Compare-and-swap available])
  fi
fi
  

############### OS threads ###################

if test "${enable_mzrt}" = "yes" ; then
  if test "${mzrt_needs_pthread}" = "yes" ; then
    if test "${enable_pthread}" = "no" ; then
      echo configure: cannot disable pthreads with places/futures enabled
      exit 1
    fi
    enable_pthread=yes
  fi
fi

############### pthread ###################

if test "${enable_pthread}" = "" ; then
  if test "${enable_pthread_by_default}" = "yes" ; then
    enable_pthread=yes
  fi
fi

if test "${enable_pthread}" = "yes" ; then
  if test "${use_flag_pthread}" = "yes" ; then
    PREFLAGS="$PREFLAGS -pthread"
    LDFLAGS="$LDFLAGS -pthread"
  fi
  if test "${use_flag_posix_pthread}" = "yes" ; then
    PREFLAGS="$PREFLAGS -D_POSIX_PTHREAD_SEMANTICS -D_REENTRANT"
  fi
  AC_DEFINE(USE_PTHREAD_INSTEAD_OF_ITIMER, 1, [Pthread timer enabled])

[ msg="whether pthread_rwlock is available"   ]
  AC_MSG_CHECKING($msg)
  AC_LINK_IFELSE([AC_LANG_SOURCE([
   #include <pthread.h>
   pthread_rwlock_t l;
   int main() {
     return pthread_rwlock_init(&l, NULL);
   }])], rwlockavail=yes, rwlockavail=no)
  AC_MSG_RESULT($rwlockavail)
  if test "$rwlockavail" = "yes" ; then
    AC_DEFINE(HAVE_PTHREAD_RWLOCK,1,[Have pthread_rwlock])
  fi
fi

############## extflonum ################

if test "${enable_extflonum}" = "default" ; then
  [ msg="for powl for extflonums" ]
  AC_MSG_CHECKING($msg)
  AC_LINK_IFELSE([AC_LANG_SOURCE([
     #include <math.h>
     #include <stdlib.h>
     int main(int argc, char **argv) {
      char *p;
      long double x = 2.0, y = strtod(*(argv+1), &p);
      if (powl(x, y) == 8.0)
        return 0;
      return 1;
     }])], use_extflonums=yes, use_extflonums=no)
  AC_MSG_RESULT($use_extflonums)
  if test "${use_extflonums}" = "no" ; then
    AC_DEFINE(MZ_NO_EXTFLONUMS,1,[Extflonums disabled])
  fi
fi

if test "${enable_extflonum}" = "yes" ; then
  AC_DEFINE(MZ_INSIST_EXTFLONUMS)
fi

############## libffi ################

# Depends on pthread on some platforms

if test "${enable_pthread}" = "" ; then
  enable_pthread=no
fi

if test "${enable_libffi}" = "yes" ; then
   complain_if_libffi_fails=yes
fi

if test "${enable_libffi}" = "default" ; then
  case "$host_os" in
  darwin*)
        enable_libffi=no
  ;;
  *)
        enable_libffi=yes
  ;;
  esac
fi

if test "${enable_libffi}" = "yes" ; then
 if test "${enable_foreign}" = "yes" ; then
  AC_MSG_CHECKING([for libffi])

  # Try to get flags form pkg-config:
  libffi_config_prog="pkg-config libffi"
  libffi_config_preflags=`$libffi_config_prog --cflags-only-I  2> /dev/null`
  if test "$?" = 0 ; then
    libffi_config_cflags=`$libffi_config_prog --cflags-only-other  2> /dev/null`
    if test "$?" = 0 ; then
      libffi_config_libs=`$libffi_config_prog --libs  2> /dev/null`
      if test "$?" != 0 ; then
        libffi_config_preflags=""
        libffi_config_cflags=""
        libffi_config_libs="-lffi"
      fi
    else
      libffi_config_preflags=""
      libffi_config_cflags=""
      libffi_config_libs="-lffi"
    fi
  else
    libffi_config_preflags=""
    libffi_config_cflags=""
    libffi_config_libs="-lffi"
  fi

  OLD_CFLAGS="${CFLAGS}"
  OLD_LIBS="${LIBS}"
  CFLAGS="${CFLAGS} ${libffi_config_preflags} ${libffi_config_cflags}"
  LIBS="${LIBS} ${libffi_config_libs}"
  AC_TRY_LINK([#include <ffi.h>],
              [ffi_cif cif; ]
              [ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 0, &ffi_type_void, NULL);],
             have_libffi=yes,
             have_libffi=no)
  AC_MSG_RESULT($have_libffi)
  if test "${have_libffi}" = "no" ; then
    CFLAGS="${OLD_CFLAGS}"
    LIBS="${OLD_LIBS}"
    echo "Building own libffi"
    if test "${complain_if_libffi_fails}" = "yes" ; then
       echo configure: unable to link to libffi
       exit 1
    fi
  else
    CFLAGS="${OLD_CFLAGS}"
    PREFLAGS="${PREFLAGS} ${libffi_config_preflags}"
    COMPFLAGS="${COMPFLAGS} ${libffi_config_cflags}"
    echo "Using installed libffi"
    OWN_LIBFFI="OFF"
  fi
 fi
fi

############## Solaris grunge ################

if test "$check_gcc_dash_e" = "yes" ; then

  orig_ldflags="$LDFLAGS"
  LDFLAGS="$LDFLAGS -Wl,-E"

  # Can use -Wl,-E for linking because we're using GNU linker?
[ msg="whether linker accepts -Wl,-E"   ]
  AC_MSG_CHECKING($msg)
  AC_LINK_IFELSE([AC_LANG_SOURCE([
   int main() {
      return 0;
   }])], linker_dash_e=yes, linker_dash_e=no)
  if test "$linker_dash_e" = "no" ; then
    LDFLAGS="${orig_ldflags}"
  fi
  AC_MSG_RESULT($linker_dash_e)

fi

############## drop optimization flags ################

if test "${enable_noopt}" = "yes" ; then
  AWKPRG='BEGIN { FS = "(^| )-O(0|1|2|3|4|5|6|7|8|9)?( |$)" } /.*/ { for (i = 1; i < NF; i++) printf "%s ", $i; print $NF }'
  CFLAGS=`echo "$CFLAGS" | awk "$AWKPRG"`
  CPPFLAGS=`echo "$CPPFLAGS" | awk "$AWKPRG"`
  PREFLAGS=`echo "$PREFLAGS" | awk "$AWKPRG"`
fi

############## ubsan ################

m4_include(../ac/ubsan.m4)

############## usersetup ################

if test "${enable_usersetup}" != "yes" ; then  
  INSTALL_SETUP_FLAGS="${INSTALL_SETUP_FLAGS} --no-user"
  INSTALL_SETUP_RACKET_FLAGS="${INSTALL_SETUP_RACKET_FLAGS} --no-user-path"
fi

############## docs ################

if test "${enable_docs}" = "no" ; then  
  INSTALL_SETUP_FLAGS="${INSTALL_SETUP_FLAGS} --no-docs"
fi

############## natipkg ################

if test "${enable_natipkg}" = "yes" ; then
  AC_DEFINE(SPLS_SUFFIX,"-natipkg",[Library subpath suffix])
fi

############## Racket for Racket ################

if test "${enable_racket}" = "auto" ; then
  enable_racket="`pwd`/local/racket/racket3m"
  MAKE_LOCAL_RACKET="local/racket/racket3m"
fi

if test "${enable_racket}" = "" ; then
  RUN_RACKET_CGC='$(RUN_THIS_RACKET_CGC)'
  RUN_RACKET_MMM='$(RUN_THIS_RACKET_MMM)'
  RUN_RACKET_MAIN_VARIANT='$(RUN_THIS_RACKET_MAIN_VARIANT)'
  CGC_IF_NEEDED_FOR_MMM="cgc"
  BOOT_MODE="--boot"
else
  RUN_RACKET_CGC="${enable_racket}"
  RUN_RACKET_MMM="${enable_racket}"
  RUN_RACKET_MAIN_VARIANT="${enable_racket}"
  CGC_IF_NEEDED_FOR_MMM="no-cgc-needed"
  BOOT_MODE="--chain"
fi

############## libtool ################

if test "${enable_shared}" = "yes" ; then
  echo "Configuring libtool"

  if test ! -d "lt" ; then
    mkdir "lt"
  fi
  abssrcdir=`(cd ${srcdir}; pwd)`

  # Try to convert libdir to an absolute path:
  # (Is this necessary anymore?)
  if test -d "${libdir}" ; then
    abslibdir=`(cd ${libdir}; pwd)`
  else
    abslibdir="${libdir}"
  fi
  

  if test "${LIBTOOLPROG}" = "" ; then  
    (cd lt; sh ${abssrcdir}/lt/configure --enable-shared --disable-static)
    LIBTOOLPROG=`pwd`/lt/libtool
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

  if test "$INCLUDEDEP" = "-include" ; then
    plt_lib_version="\$(FWVERSION)"
  else
    VERSION_X=`grep 'define MZSCHEME_VERSION_X ' ${srcdir}/racket/src/schvers.h | cut -d ' ' -f 3`
    VERSION_Y=`grep 'define MZSCHEME_VERSION_Y ' ${srcdir}/racket/src/schvers.h | cut -d ' ' -f 3`
    VERSION_Z=`grep 'define MZSCHEME_VERSION_Z ' ${srcdir}/racket/src/schvers.h | cut -d ' ' -f 3`
    VERSION_W=`grep 'define MZSCHEME_VERSION_W ' ${srcdir}/racket/src/schvers.h | cut -d ' ' -f 3`

    if test "${VERSION_W}" != "0" ; then
      plt_lib_version="${VERSION_X}.${VERSION_Y}.${VERSION_Z}.${VERSION_W}"
    else
      if test "${VERSION_Z}" != "0" ; then
        plt_lib_version="${VERSION_X}.${VERSION_Y}.${VERSION_Z}"
      else
        plt_lib_version="${VERSION_X}.${VERSION_Y}"
      fi
    fi
  fi

  AR="${LIBTOOLPROG} --mode=link --tag=CC $CC${need_gcc_static_libgcc}${ar_libtool_no_undefined} -release ${plt_lib_version} -rpath ${abslibdir} \$(ARLIBFLAGS) -o"
  STATIC_AR="${LIBTOOLPROG} --mode=link --tag=CC $CC -o"
  ARFLAGS=""
  RANLIB=":"
  MZLINKER="${LIBTOOLPROG} --mode=link --tag=CC $CC${need_gcc_static_libgcc} -rpath ${abslibdir}"
  PLAIN_CC="$CC"
  CC="${LIBTOOLPROG} --mode=compile --tag=CC $CC"
  AS="${LIBTOOLPROG} --mode=compile $AS"
  LIBSFX=la
  WXLIBS=WXLIBSDYN
  ICP="${LIBTOOLPROG} --mode=install cp"
  ICP_LIB="${LIBTOOLPROG} --mode=install install -s"
  MRLIBINSTALL="install-lib"
  LIBFINISH="${LIBTOOLPROG} --mode=finish"
  LTO="lo"
  LTA="la"
  FOREIGN_CONVENIENCE="_convenience"
  FOREIGN_OBJSLIB="\$(FOREIGN_LIB)"
  MZOPTIONS="$MZOPTIONS -DMZ_USES_SHARED_LIB"
  STRIP_LIB_DEBUG=":"
else
  LIBSFX=a
  WXLIBS=WXLIBSNORM
  ICP=cp
  ICP_LIB=cp
  MRLIBINSTALL="install-no-lib"
  LIBFINISH=echo
  LTO="o"
  LTA="a"
  MZLINKER='$(CC)'
  STATIC_AR="$AR"
  PLAIN_CC='$(CC)'
  FOREIGN_CONVENIENCE=""
  FOREIGN_OBJSLIB="\$(FOREIGN_OBJS)"
fi

# Last but not least, if Werror was requested, add it now
if test "${enable_werror}" = "yes"; then
  CFLAGS="-Werror ${CFLAGS}"
fi

############## final output ################

LIBS="$LIBS $EXTRALIBS"

AC_SUBST(CC)
AC_SUBST(CFLAGS)
AC_SUBST(PREFLAGS)
AC_SUBST(COMPFLAGS)
AC_SUBST(PROFFLAGS)
AC_SUBST(LDFLAGS)
AC_SUBST(CPP)
AC_SUBST(SED)
AC_SUBST(AS)
AC_SUBST(RANLIB)
AC_SUBST(AR)
AC_SUBST(STATIC_AR)
AC_SUBST(ARFLAGS)
AC_SUBST(STRIP_DEBUG)
AC_SUBST(STRIP_LIB_DEBUG)
AC_SUBST(CC_FOR_BUILD)
AC_SUBST(REZ)
AC_SUBST(MZLINKER)
AC_SUBST(POST_LINKER)
AC_SUBST(PLAIN_CC)
AC_SUBST(DYN_CFLAGS)

AC_SUBST(x_includes)
AC_SUBST(x_libraries)
AC_SUBST(X_CFLAGS)
AC_SUBST(X_LIBS)
AC_SUBST(X_PRE_LIBS)
AC_SUBST(X_EXTRA_LIBS)

AC_SUBST(OPTIONS)
AC_SUBST(MZOPTIONS)
AC_SUBST(CGCOPTIONS)
AC_SUBST(GC2OPTIONS)
AC_SUBST(MROPTIONS)
AC_SUBST(GCDIR)
AC_SUBST(XFORMFLAGS)
AC_SUBST(MZBINTARGET)
AC_SUBST(MZINSTALLTARGET)
AC_SUBST(MZINSTALLBINDIR)
AC_SUBST(EXTRA_GMP_OBJ)
AC_SUBST(EXTRA_GMP_DEP)
AC_SUBST(OSX)
AC_SUBST(NOT_OSX)
AC_SUBST(MINGW)
AC_SUBST(NOT_MINGW)
AC_SUBST(FRAMEWORK_INSTALL_DIR)
AC_SUBST(FRAMEWORK_REL_INSTALL)
AC_SUBST(FRAMEWORK_PREFIX)
AC_SUBST(EXE_SUFFIX)
AC_SUBST(SO_SUFFIX)
AC_SUBST(OWN_LIBFFI)

AC_SUBST(LIBSFX)
AC_SUBST(WXLIBS)
AC_SUBST(WXVARIANT)
AC_SUBST(ICP)
AC_SUBST(ICP_LIB)
AC_SUBST(MRLIBINSTALL)

AC_SUBST(MAKE_FINISH)

AC_SUBST(WXPRECOMP)
AC_SUBST(USE_WXPRECOMP)
AC_SUBST(INCLUDEDEP)
AC_SUBST(WX_MMD_FLAG)

AC_SUBST(PWD)
AC_SUBST(DIRCVTPRE)
AC_SUBST(DIRCVTPOST)
AC_SUBST(WINDRES)
AC_SUBST(DLLTOOL)

AC_SUBST(OSKHOME)
AC_SUBST(EXTRA_OSK_LIBS)

AC_SUBST(FOREIGN_IF_USED)
AC_SUBST(FOREIGN_OBJSLIB)
AC_SUBST(FOREIGN_CONVENIENCE)
AC_SUBST(FOREIGNTARGET)

AC_SUBST(LIBRACKET_DEP)

AC_SUBST(LTO)
AC_SUBST(LTA)

AC_SUBST(INSTALL_SETUP_FLAGS)
AC_SUBST(INSTALL_SETUP_RACKET_FLAGS)

AC_SUBST(INSTALL_LIBS_ENABLE)

AC_SUBST(RUN_RACKET_CGC)
AC_SUBST(RUN_RACKET_MMM)
AC_SUBST(RUN_RACKET_MAIN_VARIANT)
AC_SUBST(CGC_IF_NEEDED_FOR_MMM)
AC_SUBST(BOOT_MODE)

AC_SUBST(STARTUP_AS_BYTECODE)
AC_SUBST(STARTUP_AS_C)
AC_SUBST(STARTUP_AS_AUTO)

AC_SUBST(CROSS_COMPILE_TARGET_KIND)

mk_needed_dir()
{
  if test ! -d "$1" ; then
    mkdir "$1"
  fi
}

makefiles="Makefile
           racket/Makefile
             racket/src/Makefile racket/dynsrc/Makefile
             racket/gc/Makefile racket/sgc/Makefile
             racket/gc2/Makefile"

# Make sure the --enable-shared default is propagated:
if test "${enable_shared}" = "yes" ; then
  SUB_CONFIGURE_EXTRAS="$SUB_CONFIGURE_EXTRAS --enable-shared"
fi

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

FOREIGNTARGET=
FOREIGN_IF_USED="FOREIGN_NOT_USED"
if test -d "${srcdir}/foreign" && test "${enable_foreign}" = "yes" ; then
  if test "${have_libffi}" != "yes" ; then
    AC_CONFIG_AUX_DIR( foreign/libffi )
    AC_CONFIG_SUBDIRS( foreign/libffi )
  fi
  FOREIGNTARGET="foreign-stuff"
  FOREIGN_IF_USED="FOREIGN_USED"
else
  FOREIGNTARGET="foreign-stub"
  MZOPTIONS="$MZOPTIONS -DDONT_USE_FOREIGN"
fi
makefiles="$makefiles foreign/Makefile"

AC_CONFIG_SUBDIRS( rktio )

# Remove any --enable or --disable arguments from `ac_configure_args':
new_configure_args=
fixup_prev=
eval "set x $ac_configure_args"
shift
for fixup_arg
do
  case $fixup_arg in
  # Strip away all feature choices
  -enable* | --enable* | -disable* | --disable*)
    ;;
  *)
    case $fixup_arg in
    *\'*) fixup_arg=`echo "$fixup_arg" | sed "s/'/'\\\\\\\\''/g"` ;;
    esac
    new_configure_args="$new_configure_args '$fixup_arg'" ;;
  esac
done
# Add in `SUB_CONFIGURE_EXTRAS'
ac_configure_args="$new_configure_args$SUB_CONFIGURE_EXTRAS"

if test "${enable_gracket}" = "yes" ; then
  makefiles="$makefiles
             gracket/Makefile
               gracket/gc2/Makefile"
fi

AC_OUTPUT($makefiles)

# From "../ac/path.m4":
show_path_results
