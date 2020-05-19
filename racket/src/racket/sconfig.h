/*
   Configuration for compiling Racket

   If you want to set all the flags externally (on the command line
   with -D or some other compiler-dependent way), then define
   FLAGS_ALREADY_SET, and this file will be ignored.

   The best flag settings are already provided for some auto-detected
   architecture/system/compilers. Otherwise, the default settings
   are generic Unix.  Send other architecture/system/compiler-specific
   info to "racket@racket-lang.org".
*/

#ifndef FLAGS_ALREADY_SET

/******** (BEGIN KNOWN ARCHITECTURE/SYSTEM CONFIGURATIONS) ********/

/* First, use configure-generated information */
/*   (on Windows, this is done by a manual file which is in src/worksp) */
#include "mzconfig.h"

  /************** SunOS/Solaris with gcc ****************/

#if defined(sun)

# include "uconfig.h"

# define USE_EXPLICT_FP_FORM_CHECK

# include <errno.h>
# ifdef ECHRNG
/* Solaris */
#  if  defined(__i386__)
#   define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-solaris"
#  elif defined(__x86_64)
#   define SCHEME_PLATFORM_LIBRARY_SUBPATH "x86_64-solaris"
#  else
#   define SCHEME_PLATFORM_LIBRARY_SUBPATH "sparc-solaris"
#  endif
# else
/* SunOS4 */
# define SCHEME_PLATFORM_LIBRARY_SUBPATH "sparc-sunos4"
# define NO_STRERROR_AVAILABLE
# define USE_ON_EXIT_FOR_ATEXIT
# endif

# define PREFER_MMAP_LARGE_BLOCKS

# define FMOD_CAN_RETURN_POS_ZERO

# ifdef __i386__
#  define MZ_USE_JIT_I386
#  define MZ_JIT_USE_MPROTECT
# elif defined(__x86_64)
#  define MZ_USE_JIT_X86_64
#  define MZ_JIT_USE_MPROTECT
# else
#  define FLUSH_SPARC_REGISTER_WINDOWS
# endif

# define FLAGS_ALREADY_SET

#endif

  /************** RS6000/AIX with gcc or xlc ****************/

# if defined(_IBMR2)

# define SCHEME_PLATFORM_LIBRARY_SUBPATH "rs6k-aix"

# include "uconfig.h"

# define UNIX_LIMIT_STACK 33554944

# define FLAGS_ALREADY_SET

#endif

  /************** Linux with gcc ****************/

#if defined(__linux__)

# ifdef __ANDROID__
#  define SPLS_LINUX "android"
# else
#  define SPLS_LINUX "linux"
# endif

# if defined(__i386__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-" SPLS_LINUX
#  define REGISTER_POOR_MACHINE
#  define MZ_TRY_EXTFLONUMS
#  define ASM_DBLPREC_CONTROL_87
# endif
# if defined(__powerpc__) && !defined(__powerpc64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "ppc-" SPLS_LINUX
# endif
# if defined(__powerpc64__)
#  if defined(__LITTLE_ENDIAN__)
#   define SCHEME_PLATFORM_LIBRARY_SUBPATH "ppc64le-" SPLS_LINUX
#  else
#   define SCHEME_PLATFORM_LIBRARY_SUBPATH "ppc64-" SPLS_LINUX
#  endif
# endif
# if defined(__mc68000__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "m68k-" SPLS_LINUX
# endif
# if defined(mips)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "mips-" SPLS_LINUX
# endif
# if defined(__alpha__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "alpha-" SPLS_LINUX
# endif
# if defined(__hppa__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "hppa-" SPLS_LINUX
# endif
# if defined(__sparc__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "sparc-" SPLS_LINUX
#  define FLUSH_SPARC_REGISTER_WINDOWS
# endif
# if defined(__arm__) || defined(__thumb__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "arm-" SPLS_LINUX
#  define FFI_CALLBACK_NEED_INT_CLEAR
# endif
# if defined(__x86_64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "x86_64-" SPLS_LINUX
#  define REGISTER_POOR_MACHINE
#  define ASM_DBLPREC_CONTROL_87
#  define MZ_TRY_EXTFLONUMS
# endif
# ifndef SCHEME_PLATFORM_LIBRARY_SUBPATH
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "unknown-" SPLS_LINUX
# endif

# include "uconfig.h"
# ifndef __ELF__
#  undef UNIX_DYNAMIC_LOAD
# endif

# define USE_IEEE_FP_PREDS
# define USE_EXPLICT_FP_FORM_CHECK

# define LINUX_FIND_STACK_BASE

# define FLAGS_ALREADY_SET

#if defined(__i386__)
# define MZ_USE_JIT_I386
# define MZ_JIT_USE_MPROTECT
# ifndef MZ_NO_UNWIND_SUPPORT
#  define MZ_USE_DWARF_LIBUNWIND
# endif
#endif
#if defined(__x86_64__)
# define MZ_USE_JIT_X86_64
# define MZ_JIT_USE_MPROTECT
# ifndef MZ_NO_UNWIND_SUPPORT
#  define MZ_USE_DWARF_LIBUNWIND
# endif
#endif
#if defined(__powerpc__) && !defined(__powerpc64__)
# define MZ_USE_JIT_PPC
#endif
# if defined(__arm__)
# define MZ_USE_JIT_ARM
#endif

#endif

  /********************* NetBSD ***********************/

#if defined(__NetBSD__)

#if defined(__i386__)
# define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-netbsd"
#elif defined(__powerpc__)
# define SCHEME_PLATFORM_LIBRARY_SUBPATH "ppc-netbsd"
#elif defined(__x86_64__)
# define SCHEME_PLATFORM_LIBRARY_SUBPATH "x86_64-netbsd"
#else
# define SCHEME_PLATFORM_LIBRARY_SUBPATH "netbsd"
#endif

# include "uconfig.h"

#ifndef __ELF__
# define UNDERSCORE_DYNLOAD_SYMBOL_PREFIX
#endif

# define USE_IEEE_FP_PREDS

#if defined(__alpha__)
# define USE_DIVIDE_MAKE_INFINITY
#endif

#if defined(__i386__)
# define MZ_USE_JIT_I386
# define MZ_JIT_USE_MPROTECT
#endif
#if defined(__powerpc__)
# define MZ_USE_JIT_PPC
#endif
#if defined(__x86_64__)
# define MZ_USE_JIT_X86_64
# define MZ_JIT_USE_MPROTECT
#endif

# define FLAGS_ALREADY_SET

#endif

  /************** OpenBSD with gcc ****************/
              /* Thanks to Bengt Kleberg */

#if defined(__OpenBSD__) && !defined(__Bitrig__)

# if defined(__x86_64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "x86_64-openbsd"
#  define IMPLEMENT_WRITE_XOR_EXECUTE_BY_SIGNAL_HANDLER
# elif defined(__i386__) || defined(i386)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-openbsd"
# elif defined(__mips64__)
#  if defined(__MIPSEL__)
#   define SCHEME_PLATFORM_LIBRARY_SUBPATH "mips64el-openbsd"
#  else
#   define SCHEME_PLATFORM_LIBRARY_SUBPATH "mips64-openbsd"
#  endif
# elif defined(__powerpc__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "ppc-openbsd"
# elif defined(__sparc64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "sparc64-openbsd"
# elif defined(__arm__) || defined(__thumb__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "arm-openbsd"
# elif defined(__aarch64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "aarch64-openbsd"
# elif defined(__hppa__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "hppa-openbsd"
# else
#  error Unported platform.
# endif

# include "uconfig.h"
# undef UNIX_FIND_STACK_BOUNDS
# define PTHREAD_STACKSEG_FIND_STACK_BOUNDS

/* Default UNIX_STACK_MAXIMUM is too big for a non-root user. */
# undef UNIX_STACK_MAXIMUM
# define UNIX_STACK_MAXIMUM 4194304

# define UNDERSCORE_DYNLOAD_SYMBOL_PREFIX

# define USE_DLOPEN_GLOBAL_BY_DEFAULT

# define USE_IEEE_FP_PREDS

# define USE_MAP_ANON

# if defined(__x86_64__)
#  define MZ_USE_JIT_X86_64
#  define MZ_JIT_USE_MPROTECT
#  define MZ_TRY_EXTFLONUMS
# elif defined(__i386__)
#  define MZ_USE_JIT_I386
#  define MZ_JIT_USE_MPROTECT
#  define MZ_TRY_EXTFLONUMS
#  define REGISTER_POOR_MACHINE
# elif defined(__powerpc__)
#  define MZ_USE_JIT_PPC
# elif defined(__sparc64__)
#  define FLUSH_SPARC_REGISTER_WINDOWS
#  define FMOD_CAN_RETURN_POS_ZERO
# elif defined(__arm__)
#  define MZ_USE_JIT_ARM
#  define FFI_CALLBACK_NEED_INT_CLEAR
# endif

# define FLAGS_ALREADY_SET

#endif

  /************** Bitrig with clang ****************/
/*
   Bitrig and OpenBSD are pretty similar in some aspects. If you are modifying
   any of the next values, please test also the same changes on OpenBSD.
*/

#if defined(__Bitrig__)

# if defined(__x86_64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "x86_64-bitrig"
# elif defined(__arm__) || defined(__thumb__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "arm-bitrig"
# else
#  error Unported platform.
# endif

# include "uconfig.h"
# undef UNIX_FIND_STACK_BOUNDS
# define PTHREAD_STACKSEG_FIND_STACK_BOUNDS

/* Default UNIX_STACK_MAXIMUM is too big for a non-root user. */
# undef UNIX_STACK_MAXIMUM
# define UNIX_STACK_MAXIMUM 4194304

# define UNDERSCORE_DYNLOAD_SYMBOL_PREFIX

# define USE_DLOPEN_GLOBAL_BY_DEFAULT

# define USE_IEEE_FP_PREDS

# define USE_MAP_ANON

# if defined(__x86_64__)
#  define MZ_USE_JIT_X86_64
#  define MZ_JIT_USE_MPROTECT
#  define MZ_TRY_EXTFLONUMS
# elif defined(__arm__)
#  define MZ_USE_JIT_ARM
#  define FFI_CALLBACK_NEED_INT_CLEAR
# endif

# define FLAGS_ALREADY_SET

#endif

  /************** FreeBSD with clang/gcc ****************/

#if defined(__FreeBSD__) || defined(__FreeBSD_kernel__)

# if defined(__i386__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-freebsd"
#  define REGISTER_POOR_MACHINE
#  define MZ_USE_JIT_I386
#  define MZ_TRY_EXTFLONUMS
#  if defined(__FreeBSD_kernel__)
#   define ASM_DBLPREC_CONTROL_87
#  else
#   define FREEBSD_CONTROL_387
#  endif
# elif defined(__amd64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "amd64-freebsd"
#  define REGISTER_POOR_MACHINE
#  define MZ_USE_JIT_X86_64
#  define MZ_TRY_EXTFLONUMS
#  if defined(__FreeBSD_kernel__)
#   define ASM_DBLPREC_CONTROL_87
#  endif
# elif defined(__sparc64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "sparc64-freebsd"
#  define FLUSH_SPARC_REGISTER_WINDOWS
# elif defined(__arm__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "arm-freebsd"
# elif defined(__aarch64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "aarch64-freebsd"
# elif defined(__powerpc__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "ppc-freebsd"
#  define MZ_USE_JIT_PPC
# else
#  error Unported platform.
# endif

/* pthreads always enabled via `configure', and
   initial pthread's stack size doesn't use rlimit: */
# define ASSUME_FIXED_STACK_SIZE
# define FIXED_STACK_SIZE 1048576

# include "uconfig.h"

# ifdef FREEBSD_VERSION_2x
#  define UNDERSCORE_DYNLOAD_SYMBOL_PREFIX
# endif

# define USE_UNDERSCORE_SETJMP

# define USE_IEEE_FP_PREDS

# define MZ_JIT_USE_MPROTECT

# define FLAGS_ALREADY_SET

#endif

  /************** HAIKU with clang/gcc ****************/

#if defined(__HAIKU__)

# if defined(__i386__) || defined(__BEPC__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-haiku"
#  define REGISTER_POOR_MACHINE
#  define MZ_USE_JIT_I386
#  define MZ_TRY_EXTFLONUMS
# elif defined(__amd64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "amd64-haiku"
#  define REGISTER_POOR_MACHINE
#  define MZ_USE_JIT_X86_64
#  define MZ_TRY_EXTFLONUMS
# else
#  error Unported platform.
# endif

/* pthreads always enabled via `configure', and
   initial pthread's stack size doesn't use rlimit: */
# define ASSUME_FIXED_STACK_SIZE
# define FIXED_STACK_SIZE 1048576

# include "uconfig.h"

#endif

  /************** SGI/IRIX with SGI cc ****************/

#if  (defined(mips) || defined(__mips)) \
     && !(defined(ultrix) || defined(__ultrix) || defined(__linux__) || defined(__OpenBSD__))

# define SCHEME_PLATFORM_LIBRARY_SUBPATH "mips-irix"

# include "uconfig.h"

# define BSTRING_INCLUDE

# define DEFEAT_FP_COMP_OPTIMIZATION
# define FMOD_CAN_RETURN_NEG_ZERO

# define FLAGS_ALREADY_SET

#endif

  /************** Ultrix with gcc ****************/

#if defined(ultrix) || defined(__ultrix)

# define SCHEME_PLATFORM_LIBRARY_SUBPATH "mips-ultrix"

# include "uconfig.h"
# undef UNIX_DYNAMIC_LOAD

# define FLAGS_ALREADY_SET

#endif

  /************** ALPHA/OSF1 with gcc ****************/

# if (defined(__alpha) || defined(__alpha__)) \
    && !defined(__linux__) && !defined(__NetBSD__) && !defined(__OpenBSD__)

# define SCHEME_PLATFORM_LIBRARY_SUBPATH "alpha-osf1"

# include "uconfig.h"

# define ALPHA_CONTROL_FP
# define USE_OSF_FP_PREDS
# define USE_DIVIDE_MAKE_INFINITY
# define ATAN2_DOESNT_WORK_WITH_INFINITIES

# define FLAGS_ALREADY_SET

#endif

  /************** HP/UX with cc or gcc ****************/

#if defined(__hpux)

# define SCHEME_PLATFORM_LIBRARY_SUBPATH "parisc-hpux"

# include "uconfig.h"

# define USE_DIVIDE_MAKE_INFINITY
# define USE_IEEE_FP_PREDS
# define USE_EXPLICT_FP_FORM_CHECK
# define ZERO_MINUS_ZERO_IS_POS_ZERO
# define LOG_ZERO_ISNT_NEG_INF

# define FLAGS_ALREADY_SET

#endif

  /************** x86/SCO Unix with gcc ****************/
  /* Contributed by Atanas Ivanov <nasko@noac.bg>      */

#if defined(_M_XENIX) && defined(_M_SYSV)

# define SCHEME_PLATFORM_LIBRARY_SUBPATH "sco-i386"

# include "uconfig.h"
#ifndef __ELF__
# undef UNIX_DYNAMIC_LOAD
#endif

# define USE_SCO_IEEE_FP_PREDS
# define USE_EXPLICT_FP_FORM_CHECK

# define REGISTER_POOR_MACHINE

# define FLAGS_ALREADY_SET

#endif

  /****************** Windows with MS Visual C ***************/
  /* See the "worksp" directory for more MSVC details.       */

#if (defined(__BORLANDC__) \
     || ((defined(_MSC_VER) || defined(__MINGW32__)) \
         && (defined(__WIN32__) || defined(WIN32) || defined(_WIN32))))

# ifdef _WIN64
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "win32\\x86_64"
# else
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "win32\\i386"
# endif

# define SYSTEM_TYPE_NAME "windows"
# define DOS_FILE_SYSTEM

# define USE_WINDOWS_EVENT_LOG
# define INIT_SYSLOG_LEVEL SCHEME_LOG_ERROR

# define DO_STACK_CHECK
# define WINDOWS_FIND_STACK_BOUNDS

# define USE_MZ_SETJMP

# define WINDOWS_DYNAMIC_LOAD

#ifdef _MSC_VER
# define USE_MSVC_FP_PREDS
# if _MSC_VER < 1300
#  define NAN_EQUALS_ANYTHING
# endif
# define INT64_AS_LONG_LONG
# define ATAN2_DOESNT_WORK_WITH_INFINITIES
         /* With VC 7, ATAN2_DOESNT... wasn't needed, and
            POW_HANDLES_INF_CORRECTLY worked, too. */
# define SIN_COS_NEED_DEOPTIMIZE
# define AVOID_INT_TO_FLOAT_TRUNCATION
#endif
#ifdef __BORLANDC__
# define NAN_EQUALS_ANYTHING
# define ATAN2_DOESNT_WORK_WITH_INFINITIES
# define ATAN2_DOESNT_WORK_WITH_NAN
# define SQRT_NAN_IS_WRONG
# define LOG_ZERO_ISNT_NEG_INF
# define TRIG_ZERO_NEEDS_SIGN_CHECK
# define NEED_TO_DEFINE_MATHERR
#endif
#ifdef __MINGW32__
# define USE_IEEE_FP_PREDS
# define ATAN2_DOESNT_WORK_WITH_INFINITIES
#endif

# define IO_INCLUDE
# define DONT_IGNORE_PIPE_SIGNAL

# define WINDOWS_PROCESSES
# define WINDOWS_FILE_HANDLES
# ifndef MZ_USE_DETERMINSTIC_FUEL
#  define USE_WIN32_THREAD_TIMER
# endif

# define NO_SIGHUP_HANDLER

#define PRINTF_INTPTR_SIZE_PREFIX "I"

/* MS Visual C++ likes underscore prefixes */
#if defined(_MSC_VER)
# define MSC_IZE(x) _ ## x
# define M_MSC_IZE(x) MSC_IZE(x)
# define DIRECT_INCLUDE
# else
# define M_MSC_IZE(x) x
#endif

#if defined(__MINGW32__)
# define MSC_IZE(x) _ ## x
#endif

#ifdef __BORLANDC__
# define MSCBOR_IZE(x) _ ## x
# define DIR_INCLUDE
# define IGNORE_BY_BORLAND_CONTROL_87
#endif

#if defined(__MINGW32__) && defined(USE_DIRECT_LONG_DOUBLE)
/* Beware: different from the MSVC build when SSE-based floating-point
   math is enabled in the C compiler. Sets the floating-point mode to
   extended precision to support extflonums, and changing precision
   may affect other libraries. */
# define MZ_TRY_EXTFLONUMS
# define ASM_DBLPREC_CONTROL_87
#else
# define MZ_LONG_DOUBLE
# define IGNORE_BY_MS_CONTROL_87
# define MZ_NEED_SET_EXTFL_MODE
# define MZ_LONG_DOUBLE_API_IS_EXTERNAL
#endif

# define REGISTER_POOR_MACHINE

# define WINDOWS_UNICODE_SUPPORT
# define USE_ICONV_DLL
# define NO_MBTOWC_FUNCTIONS

# ifdef _WIN64
#  define MZ_USE_JIT_X86_64
# else
#  define MZ_USE_JIT_I386
# endif

# define MZ_JIT_USE_WINDOWS_VIRTUAL_ALLOC

# define FLAGS_ALREADY_SET

#endif

  /******************** Windows with Cygwin ******************/
  /* See the "worksp" directory for more MSVC details.       */

#if defined(__CYGWIN32__)

# define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-cygwin"

# include "uconfig.h"

# undef USE_ITIMER

# define USE_MZ_CYGWIN_SETJMP
# define USE_MZ_SETJMP

# define USE_CYGWIN_SO_SUFFIX

# define USE_DIVIDE_MAKE_INFINITY

# define DO_STACK_CHECK
# define WINDOWS_FIND_STACK_BOUNDS

# define REGISTER_POOR_MACHINE

# define MZ_USE_JIT_I386

# define FLAGS_ALREADY_SET

#endif

  /************** Mac OS X  ****************/

# if defined(OS_X) || defined(XONX)

# if defined(XONX)
#  define SPLS_MAC "darwin"
# elif TARGET_OS_IPHONE
#  define SPLS_MAC "ios"
# else
#  define SPLS_MAC "macosx"
# endif

# if defined(__POWERPC__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "ppc-" SPLS_MAC
# elif defined(__arm__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "arm-" SPLS_MAC
# elif defined(__arm64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "arm64-" SPLS_MAC
# elif defined(__x86_64__)
#   define SCHEME_PLATFORM_LIBRARY_SUBPATH "x86_64-" SPLS_MAC
# else
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-" SPLS_MAC
# endif

# include "uconfig.h"

# define INIT_SYSLOG_LEVEL SCHEME_LOG_ERROR

#ifndef XONX
# undef SYSTEM_TYPE_NAME
# define SYSTEM_TYPE_NAME "macosx"
#endif

# ifndef MZ_USE_DETERMINSTIC_FUEL
#  undef USE_ITIMER
#  define USE_PTHREAD_THREAD_TIMER
# endif

# define USE_MAP_ANON

# define USE_IEEE_FP_PREDS
# define TRIG_ZERO_NEEDS_SIGN_CHECK

# define USE_UNDERSCORE_SETJMP

#ifndef XONX
# define MACOS_UNICODE_SUPPORT
#endif

#ifndef OS_X
#  define OS_X 1
#endif

#if defined(__arm__)
# define MZ_USE_JIT_ARM
#elif defined(__arm64__)
#elif defined(__POWERPC__)
# define MZ_USE_JIT_PPC
#else
# if defined(__x86_64__)
#  define MZ_USE_JIT_X86_64
# else
#  define MZ_USE_JIT_I386
# endif
# define ASM_DBLPREC_CONTROL_87
# define MZ_TRY_EXTFLONUMS
#endif

# define POW_HANDLES_CASES_CORRECTLY

# define MZ_JIT_USE_MPROTECT

# define FLAGS_ALREADY_SET

#endif

  /************** Darwin x86  ****************/

# if defined(__APPLE__) && defined(__MACH__) && defined(__i386__) && !defined(OS_X)

# define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-darwin"

# include "uconfig.h"

# define USE_MAP_ANON

# define USE_UNDERSCORE_SETJMP

# define MZ_USE_JIT_I386

# define FLAGS_ALREADY_SET

# endif

  /************ QNX *************/

#if defined(__QNX__)

#if defined(__i386__)
# define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-qnx"
#endif
# define ASSUME_FIXED_STACK_SIZE

# include "uconfig.h"

# define FIXED_STACK_SIZE 524288

# define FLAGS_ALREADY_SET

#if defined(__i386__)
# define MZ_USE_JIT_I386
# define MZ_JIT_USE_MPROTECT
#endif
#if defined(__x86_64__)
# define MZ_USE_JIT_X86_64
# define MZ_JIT_USE_MPROTECT
# define MZ_USE_DWARF_LIBUNWIND
#endif

#endif

  /************ Dragonfly *************/

#if defined(__DragonFly__)

# if defined(__i386__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "i386-dragonfly"
#  define REGISTER_POOR_MACHINE
#  define MZ_USE_JIT_I386
#  define ASM_DBLPREC_CONTROL_87
#  define MZ_TRY_EXTFLONUMS
# elif defined(__amd64__)
#  define SCHEME_PLATFORM_LIBRARY_SUBPATH "amd64-dragonfly"
#  define REGISTER_POOR_MACHINE
#  define MZ_USE_JIT_X86_64
#  define ASM_DBLPREC_CONTROL_87
#  define MZ_TRY_EXTFLONUMS
# else
#  error Unported platform.
# endif

/* pthreads always enabled via `configure', and
   initial pthread's stack size doesn't use rlimit: */
# define ASSUME_FIXED_STACK_SIZE
# define FIXED_STACK_SIZE 1048576

# include "uconfig.h"

# define USE_UNDERSCORE_SETJMP

# define USE_IEEE_FP_PREDS
# ifndef ASM_DBLPREC_CONTROL_87
#  define POW_HANDLES_INF_CORRECTLY
# endif

# define MZ_JIT_USE_MPROTECT

# define FLAGS_ALREADY_SET

#endif

/************** (END KNOWN ARCHITECTURE/SYSTEMS) ****************/


/***** (BEGIN CONFIGURATION FLAG DESCRPTIONS AND DEFAULTS) ******/

#ifndef FLAGS_ALREADY_SET

/* assume generic Unix: */
#include "uconfig.h"

  /*********************/
 /* Operating System  */
/*********************/

  /* SYSTEM_TYPE_NAME must be a string; this will be converted into
     a symbol for the result of (system-type) */

  /* SCHEME_PLATFORM_LIBRARY_SUBPATH must be a string; if it is
     undefined, it is automatically generated into a file named
     "schsys.h" into the same directory as .o files and #included
     by string.c. This string is returned by (system-library-subpath) */

  /*******************/
 /*   Filesystem    */
/*******************/

 /* UNIX_FILE_SYSTEM indicates that filenames are as in Unix, with
    forward slash separators, ".." as the parent directory, "/"
    as the root directory, and case-sensitivity */

 /* DOS_FILE_SYSTEM indicates that filenames are as in DOS, with
    slash or backward slash separators, ".." as the parent directory,
    "X:\", "X:/", "\", or "/" as a root directory (for some letter X),
    and case insensitivity */

 /* USE_C_SYSLOG uses the C syslog library for logging. */

 /* USE_WINDOWS_EVENT_LOG uses the Windows event log API for logging. */

 /* INIT_SYSLOG_LEVEL sets the initial level for filtering messages
    sent to syslog. It default to 0 (i.e., no events). */

 /* USE_TRANSITIONAL_64_FILE_OPS uses lseek64, stat64, etc. for file
    operations involving sizes (that can require 64-bit
    arithmetic). */

  /***********************/
 /*       Ports         */
/***********************/

/* These are flags about the implementation of char-ready? for FILE*s
   None of these flags are required, but char-ready? may return
   spurious #ts if they are set up incorrectly. */

 /* WINDOWS_FILE_HANDLES implements file access through the Windows
    API (CreateFile(), ReadFile(), etc.) */

  /***********************/
 /* Threads & Signals  */
/***********************/

/* These are flags about the implementation of system, process, etc. */

 /* WINDOWS_PROCESSES uses Windows threads for various tasks. */

 /* USE_ITIMER uses setitimer() to implement thread pre-emption (for
    Racket-implemented threads). Define MZ_THREAD_QUANTUM_USEC to
    set the base time in usec allocated to each thread. */

 /* USE_WIN32_THREAD_TIMER uses a background Windows thread to implement
    tread pre-emption. */

 /* USE_PTHREAD_THREAD_TIMER uses a background pthread to implement
    tread pre-emption. */

 /* DONT_IGNORE_FPE_SIGNAL stops Racket from ignoring floating-point
    exception signals. */

 /* DONT_IGNORE_PIPE_SIGNAL stops Racket from ignoring SIGPIPE
    signals. */

 /* USE_UNDERSCORE_SETJMP uses _setjmp() instead of setjmp() to avoid
    sigmal-mask work. */

 /* FLUSH_SPARC_REGISTER_WINDOWS uses an assembly instruction for
    flushing the Sparc register windows before copying the stack. */

  /**********************/
 /* Inexact Arithmetic */
/**********************/

 /* FLOATING_POINT_IS_NOT_IEEE disables inexact->exact conversion via
    parsing of IEEE-format bits. */

 /* AVOID_INT_TO_FLOAT_TRUNCATION indicates that conversion from an
    integer to a floating point type does not round-to-nearest when
    precision is lost, even when the FP rounding mode is
    round-to-nearest */

 /* USE_SINGLE_FLOATS turns on support for single-precision
    floating point numbers. Otherwise, floating point numbers
    are always represented in double-precision. */

 /* USE_SINGLE_FLOATS_AS_DEFAULT, when used with
    USE_SINGLE_FLOATS, causes exact->inexact coercions to
    use single-precision numbers as the result rather
    than double-precision numbers. */

 /* USE_INFINITY_FUNC uses infinity() to get the infinity
     floating-point constant instead of using HUGE_VAL. */

 /* USE_DIVIDE_MAKE_INFINITY creates +inf.0 by dvividing by zero
    instead of using HUGE_VAL. */

 /* USE_IEEE_FP_PREDS uses isinf() and isnan() to implement tests for
    infinity and not-a-number. */

 /* USE_OSF_FP_PREDS uses fp-class() and isnan() to implement tests for
    infinity and not-a-number. */

 /* USE_SCO_IEEE_FP_PREDS uses fpclass() and isnan() to implement tests for
    infinity and not-a-number. */

 /* USE_CARBON_FP_PREDS uses __isnand() and __isfinited() to implement tests
    for infinity and not-a-number. */

 /* USE_MSVC_FP_PREDS uses _fpclass() and _isnan() to implement tests
    for infinity and not-a-number. */

 /* DEFEAT_FP_COMP_OPTIMIZATION avoids a compiler optimization that
    converts (a == a) to TRUE, even if `a' is floating-point. Used
    only when USE_[SCO_]IEEE_FP_PREDS is not defined. */

 /* C_COMPILER_USES_SSE indicates that the C compiler generates SSE2
    instructions for `double' arithmetic. This flag is turned on
    automatically if __SSE2_MATH__ is defined (usually by gcc). */

 /* MZ_LONG_DOUBLE enables extflonum support. */

 /* MZ_TRY_EXTFLONUMS turns on MZ_LONG_DOUBLE if C_COMPILER_USES_SSE. */

 /* ASM_DBLPREC_CONTROL_87 uses inline assembly to set Intel '387
    floating-point operations to double-precision instead of
    extended-precision arithmetic. This definition is turned off if
    C_COMPILER_USES_SSE, and ASM_EXTPREC_CONTROL_87 is turned on
    instead if C_COMPILER_USES_SSE and MZ_LONG_DOUBLE. */

 /* ASM_EXTPREC_CONTROL_87 uses inline assembly to set Intel '387
    floating-point operations to double-precision instead of
    extended-precision arithmetic. */

 /* MZ_NEED_SET_EXTFL_MODE causes JIT-generated extflonum instructions
    to set the x87 control word to extended precision just before an
    extflonum operation, and then set if back to double precision just
    after. This is needed or Windows (where the default mode is double
    precision, something about the x64 environment switches the mode
    back if you try to change it permanently, and "longdouble.dll"
    does the same switch for non-JITted operations). */

 /* IGNORE_BY_BORLAND_CONTROL_87 turns off floating-point error for
    Intel '387 with Borlad-style _control87. DONT_IGNORE_PIPE_SIGNAL
    can be on or off. */

 /* IGNORE_BY_MS_CONTROL_87 turns off floating-point error for Intel
    '387 with Microsoft-style _control87. DONT_IGNORE_PIPE_SIGNAL can
    be on or off. */

 /* LINUX_CONTROL_387 controls the floating-point processor under i386
    Linux using __setfpucw(). libc 6.1 doesn't export __setfpucw() and
    it doesn't matter; for Linux 2.0 and up, the default FP behavior
    is the one we want. This flag might be needed for older versions
    of Linux. */

 /* FREEBSD_CONTROL_387 controls the floating-point processor under i386
    FreeBSD. As for Linux, this does not appear necessary anymore. */

 /* APLHA_CONTROL_FP controls the floating-point processor for Alpha
    OSF1 */

 /* NAN_EQUALS_ANYTHING indicates that the compiler is broken and
    equality comparisons with +nan.0 always return #t. Currently
    used for MSVC++ */

 /* ZERO_MINUS_ZERO_IS_POS_ZERO indicates that something (compiler?
    machine? fp flags?) is broken so that 0.0 - 0.0 = 0.0 instead of
    -0.0. This flag doesn't fix Racket completely, since (- 0.0) is
    still 0.0, but at least it lets Racket read and print 0.0 and
    -0.0 accurately. Currently used for HP/UX. */

 /* NAN_LT_COMPARISON_WRONG indicates that +nan.0 is not handled correctly
    by < or <=. Probably the compiler implements < as !>. */

 /* USE_EXPLICT_FP_FORM_CHECK circumvents bugs in strtod() under Linux,
    SunOS/Solaris, and HP/UX by explicit pre-checking the form of the
    number and looking for values that are obviously +inf.0 or -inf.0 */

 /* POW_HANDLES_CASES_CORRECTLY indicates that the pow() library procedure
    handles all +/-inf.0, +/-0.0, or +nan.0 cases according to C99. This
    might save time on redundant checking before Racket calls pow(). */

 /* ATAN2_DOESNT_WORK_WITH_INFINITIES indicates that atan2(+/-inf, +/-inf)
    is not the same as atan2(1, 1). */

 /* ATAN2_DOESNT_WORK_WITH_NAN indicates that atan2(+nan.0, _) and
    atan2(_, +nan.0) don't produce +nan.0. */

 /* SQRT_NAN_IS_WRONG indicates that (sqrt +nan.0) must be forced to +nan.0
    (i.e., the C library function is bad). */

 /* COMPUTE_NEG_INEXACT_TO_EXACT_AS_POS computes inexact->exact of some
    negative inexact number x by computing the result for -x and negating
    it. Use this if (inexact->exact -0.1) is wrong. */

 /* TRIG_ZERO_NEEDS_SIGN_CHECK defines versions of tan, sin, atan, and
    asin that preserve the sign of a zero argument. */

 /* FMOD_CAN_RETURN_NEG_ZERO is fmod() on positive numbers can produce
    a negative zero. */

 /* FMOD_CAN_RETURN_POS_ZERO is fmod() on -0.0 can produce 0.0. */

 /* LOG_ZERO_ISNT_NEG_INF defines a version of log that checks for an
    inexact zero argument and return negative infinity. */

 /* NEED_TO_DEFINE_MATHERR defines _matherr to quiet warnings from the
    math library. */

 /* SIN_COS_NEED_DEOPTIMIZE disables optimization for calls to sin()
    and cos() (for MSVC) */

  /****************************/
 /* Byte Order and long long */
/****************************/

 /* INT64_AS_LONG_LONG indicates that long long is not supported, but
    _int64 is */

 /* NO_LONG_LONG_TYPE indicates that long long is not supported */

  /***********************/
 /* Stack Manipulations */
/***********************/

 /* DO_STACK_CHECK checks for stack overflow during execution.
     Requires either UNIX_FIND_STACK_BOUNDS, USE_STACKAVAIL,
     MACOS_FIND_STACK_BOUNDS, or ASSUME_FIXED_STACK_SIZE. */

 /* UNIX_FIND_STACK_BOUNDS figures out the maximum stack position
     on Unix systems, using getrlimit() and the GC_find_stack_base()
     defined in the conservative garbage collector. But no more
     than UNIX_STACK_MAXIMUM bytes, if defined, will be used.
    USE_STACKAVIL uses stackavail() function for checking stack
     overflow; works with Borland C++, maybe other compilers.
    WINDOWS_FIND_STACK_BOUNDS figures out the maximum stack position
     under Windows (uses GC_find_stack_base())
    MACOS_FIND_STACK_BOUNDS figures out the stack limit on the Mac.
    LINUX_FIND_STACK_BASE figures out the stack base under Linux
     by reading from /proc/self/maps and looking for "[stack]"
     line.
    ASSUME_FIXED_STACK_SIZE assumes that the main stack size is
     always FIXED_STACK_SIZE.
    PTHREAD_STACKSEG_FIND_STACK_BOUNDS finds stack bounds using
     pthread_stackseg_np().
    Use only one of these if DO_STACK_CHECK is used, or none otherwise. */

 /* FIXED_STACK_SIZE <X> sets the stack size to <X> when the
     ASSUME_FIXED_STACK_SIZE stack-checking mode is on. */

 /* STACK_SAFETY_MARGIN <X> sets the number of bytes that should be
     available on the stack for "safety" to <X>. Used only if
     DO_STACK_CHECK is used. STACK_SAFETY_MARGIN defaults to 50000
     for a 32-bit platform, twice as much for a 64-bit platform. */

 /* UNIX_LIMIT_STACK <X> limits stack usage to <X> bytes. This may
     be necessary to avoid GC-setup traversal over too much memory
     (with GC flag HEURISTIC2?). */

  /***********************/
 /*   Dynamic Loading   */
/***********************/

 /* UNIX_DYNAMIC_LOAD implements dynamic extensions under Unix
     using dlopen(); you may have to add the -ldl flag in the LIBS
     Makefile variable. The library doesn't exist under Linux without
     ELF, so it won't work. If you get linker errors about dlopen(), etc.,
     this flag and the -ldl linker flag are the things to adjust.
    SHL_DYNAMIC_LOAD implement HP/UX dynamic loading.
    WINDOWS_DYNAMIC_LOAD implements dynamic extensions under Windows
     (Thanks to Patrick Barta).
    CODEFRAGMENT_DYNAMIC_LOAD implements dynamic extensions with
     MacOS's Code Fragment Custodian (thanks to William Ng).
    Use only one or none of these. */

 /* UNDERSCORE_DYNLOAD_SYMBOL_PREFIX with UNIX_DYNAMIC_LOAD means that
    an extra underscore ("_") must be placed in front of the name passed
    to dlopen(). */

 /* USE_DLOPEN_GLOBAL_BY_DEFAULT opens shared libraries in "global"
    mode by default, instead of "local" mode. */

 /* LINK_EXTENSIONS_BY_TABLE specifies that the Racket functions
    used by an extension must be manually linked via a table of
    function pointers. Windows dynamic linking uses this method. */

 /* MZSCHEME_IS_CODEFRAGMENT exploits improved CFM linking when
    Racket is itself a shared library instead of embedded in
    an application */

  /***********************/
 /*         JIT         */
/***********************/

 /* MZ_USE_JIT_I386 enables the JIT for x86 */

 /* MZ_USE_JIT_X86_64 enables the JIT for x86_64 */

 /* MZ_USE_JIT_PPC enables the JIT for PowerPC */

 /* MZ_JIT_USE_MPROTECT uses mprotect on x86 platforms to make code
    pages executable */

 /* MZ_JIT_USE_WINDOWS_VIRTUAL_ALLOC uses VirtualAlloc to make
    code pages executable. */

  /*****************************/
 /*   MacOS                   */
/*****************************/

 /* OS_X enables specific support for Mac OS, e.g. the location of the
    prefs directory */

  /***********************/
 /*    Miscellaneous    */
/***********************/

 /* USE_MAP_ANON indicates that mmap() should use BSD's MAP_ANON flag
    rather than trying to open /dev/zero */

 /* PREFER_MMAP_LARGE_BLOCKS indicates that mmap() should be called with
    large block sizes as much as possible, because the actual allocated
    size for small requests (on the order of the page size) is much
    larger than the request. */

 /* REGISTER_POOR_MACHINE guides a hand optimization that seems to
    be work best one way for Sparc machines, and better the other
    way for x86 machines. */

 /* USE_LONG_LONG_FOR_BIGDIG indicates that `long long' is available
    and 64 bits wide. (Don't use when `long' is 64 bits wide). */

 /* MACOS_UNICODE_SUPPORT and WINDOWS_UNICODE_SUPPORT indicate that
    platform-native functions should be used for string comparisons
    in the default locale. */

 /* USE_ICONV_DLL loads iconv.dll lazily for string conversion; no
    headers necessary. */

 /* NO_MBTOWC_FUNCTIONS indicates that locale-to-wchar conversion
    functions are not available. */

 /* NO_INLINE_KEYWORD indicates that the C compiler doesn't recognize
    C's `inline' keyword. */

 /* NO_USER_BREAK_HANDLER turns off handling of SIGINT, SIGTERM, and
    SIGHUP in main.c */

 /* NO_SIGTERM_HANDLER turns off handling of SIGTERM in main.c */

 /* NO_SIGHUP_HANDLER turns off handling of SIGHUP in main.c */

 /* NO_STRERROR_AVAILABLE means that strerror() is not available. */

 /* USE_ON_EXIT_FOR_ATEXIT means that a SunOS4-style on_exit()
    is available instead of atexit(). */

 /* FFI_CALLBACK_NEED_INT_CLEAR indiates thet libffi callback results
    that are smaller than an `int' should clear `int'-sized space
    in the result area. */

#endif  /* FLAGS_ALREADY_SET */

/****** (END CONFIGURATION FLAG DESCRPTIONS AND DEFAULTS) *******/

#endif  /* FLAGS_ALREADY_SET */
