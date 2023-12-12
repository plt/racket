
#################################################################
# This is the source for the `configure` script, to be compiled #
# by autoconf (use `make-configure` in "../racket").            #
#################################################################

AC_INIT([Racket],[rktio],[https://github.com/racket/racket],[racket],[https://racket-lang.org])
AC_CONFIG_SRCDIR([rktio.h])
AC_CONFIG_HEADERS([rktio_config.h])

AC_CONFIG_AUX_DIR(../lt)
AC_CANONICAL_SYSTEM

AC_ARG_ENABLE(shared,     [  --enable-shared         create shared libraries (ok, but not recommended)])
AC_ARG_ENABLE(standalone, [  --enable-standalone     create a standalone shared library])
AC_ARG_ENABLE(pthread,    [  --enable-pthread        link with pthreads (usually auto-enabled if needed)])
m4_include(../ac/iconv_arg.m4)
AC_ARG_ENABLE(bigendian,  [  --enable-bigendian      assume "big" if endianness cannot be determined])

if test "${enable_iconv}" = "" ; then
  enable_iconv=yes
fi

skip_iconv_check=no
use_flag_pthread=yes
use_flag_posix_pthread=no

# For standalone builds:
rktio_version=1.0
AS_STANDALONE=f

###### Autoconfigure #######

AC_PROG_CC

# If using gcc, we want all warnings:
if test "$CC" = "gcc" ; then 
  CFLAGS="$CFLAGS -Wall"
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

AC_CHECK_LIB(m, fmod)
AC_CHECK_LIB(dl, dlopen)

############## platform tests ################

case "$host_os" in
  solaris2*)
    # Need these libs so that `getaddrinfo` is found:
    LIBS="$LIBS -lsocket -lnsl -lintl"
    try_poll_syscall="no" # poll() has performance problems on Solaris?
    use_flag_pthread="no"
    use_flag_posix_pthread="yes"
    ;;
  aix*)
    ;;
  *freebsd*)
    enable_pthread_by_default=yes
    try_kqueue_syscall=yes
    ;;
  openbsd*)
    enable_pthread_by_default=yes
    try_kqueue_syscall=yes
    ;;
  bitrig*)
    enable_pthread_by_default=yes
    try_kqueue_syscall=yes
    ;;
  dragonfly*)
    enable_pthread_by_default=yes
    try_kqueue_syscall=yes
    ;;
  netbsd*)
    try_kqueue_syscall=yes
    ;;
  irix*)
    ;;
  linux*)
    enable_pthread_by_default=yes
    try_poll_syscall=yes
    try_epoll_syscall=yes
    try_inotify_syscall=yes
    ;;
  osf1*)
    ;;
  hpux*)
    ;;
  *mingw*)
    skip_iconv_check=yes
    PREFLAGS="$PREFLAGS -DWIN32"
    # force pthread off for Windows:
    enable_pthread=no
    ;;
  cygwin*)
    ;;
  darwin*)
    PREFLAGS="$PREFLAGS -DOS_X -D_DARWIN_UNLIMITED_SELECT"
    enable_pthread_by_default=yes
    try_kqueue_syscall=yes

    # select() generally works as well as poll() on OS X,
    # and it works better for fifos
    try_poll_syscall=no

    # -pthread is not needed and triggers a warning
    use_flag_pthread=no

    # Use custom non-libtool build for a shared object
    if test "${enable_standalone}" = "yes" ; then
       if test "${enable_shared}" = "" ; then
         enable_shared=no
         make_darwin_dylib=yes
       fi
    fi
    ;;
  nto-qnx*)
    use_flag_pthread=no
    ;;
  *)
    ;;
esac

############## C flags ################

AC_LANG_C

AC_TYPE_INTPTR_T
AC_TYPE_UINTPTR_T

AC_C_BIGENDIAN(endianness=big, endianness=little, endianness=unknown)
if test "${endianness}" = "unknown" ; then
  if test "${enable_bigendian}" = "yes" ; then
    endianness=big
  else
    echo configure: warning: cannot determine endianness, assuming little
  fi
fi

if test "${endianness}" = "big" ; then
  AC_DEFINE(RKTIO_BIG_ENDIAN,1,[Big endian])
fi

# Struct dirent
AC_CHECK_MEMBER([struct dirent.d_namelen],
                [AC_DEFINE(HAVE_DIRENT_NAMELEN, 1, [struct dirent has field namelen])],,
		[#include <dirent.h>])
AC_CHECK_MEMBER([struct dirent.d_namlen],
                [AC_DEFINE(HAVE_DIRENT_NAMLEN, 1, [struct dirent has field namlen])],,
		[#include <dirent.h>])

[ msg="for xlocale.h" ]
AC_MSG_CHECKING($msg)
AC_COMPILE_IFELSE([AC_LANG_SOURCE([
   # include <xlocale.h>
   int main() {
      return 0;
   }])],
   AC_DEFINE(RKTIO_USE_XLOCALE_HEADER,1,[Use xlocale.h])
  xlocalehon=yes, xlocalehon=no)
AC_MSG_RESULT($xlocalehon)

SAVE_CFLAGS="$CFLAGS"
if test "${xlocalehon}" = "yes" ; then
  CFLAGS="$CFLAGS -DRKTIO_USE_XLOCALE_HEADER"
fi
[ msg="for xlocale functions" ]
AC_MSG_CHECKING($msg)
AC_LINK_IFELSE([AC_LANG_SOURCE([
   #ifdef RKTIO_USE_XLOCALE_HEADER
   # include <xlocale.h>
   #endif
   #include <locale.h>
   int main() {
      locale_t l = newlocale(LC_COLLATE_MASK | LC_CTYPE_MASK, "C", NULL);
      locale_t old_l = uselocale(l);
      uselocale(old_l);
      freelocale(l);
      return 0;
   }])],
   AC_DEFINE(RKTIO_USE_XLOCALE,1,[Use xlocale])
  xlocaleon=yes, xlocaleon=no)
AC_MSG_RESULT($xlocaleon)
CFLAGS="$SAVE_CFLAGS"

AC_MSG_CHECKING([for getaddrinfo])
AC_TRY_LINK([#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>],
	[getaddrinfo(0, 0, 0, 0);],
   AC_DEFINE(HAVE_GETADDRINFO,1,[Have getaddrinfo])
   have_getaddrinfo=yes,
   have_getaddrinfo=no)
AC_MSG_RESULT($have_getaddrinfo)

m4_include(../ac/iconv.m4)

if test "${enable_iconv}" = "no" ; then
  AC_DEFINE(RKTIO_NO_ICONV,1,[Do not use iconv])
fi

if test "${enable_iconv}" = "yes" ; then
  AC_MSG_CHECKING([for nl_langinfo (CODESET)])
  AC_TRY_LINK([#include <langinfo.h>],
              [char *codeset = nl_langinfo (CODESET);],
              AC_DEFINE(RKTIO_HAVE_CODESET,1,[Have nl_langinfo (CODESET)])
               have_codeset=yes,
              have_codeset=no)
  AC_MSG_RESULT($have_codeset)
fi

if test "${enable_icu}" = "yes" ; then
  AC_DEFINE(RKTIO_HAVE_ICU,1,[Build support for iconv-via-ICU])
fi
if test "${enable_icu_dll}" = "yes" ; then
  AC_DEFINE(RKTIO_ICU_DLL,1,[Dynamically load ICU])
elif test "${icu_platform_windows}" = "no" ; then
  icu_cflags=`pkg-config icu-uc --cflags 2> /dev/null`
  if test "$?" != 0 ; then
    AC_MSG_WARN([unable to infer CFLAGS for ICU via pkg-config])
  fi
  CFLAGS="${CFLAGS} ${icu_cflags}"
fi

[ msg="for mbsrtowcs" ]
AC_MSG_CHECKING($msg)
AC_LINK_IFELSE([AC_LANG_SOURCE([
   #include <wchar.h>
   #include <strings.h>
   int main() {
     mbstate_t state;
     const char *src = "X";
     bzero(&state, sizeof(mbstate_t));
     mbsrtowcs(0, &src, 0, &state);
     return 0;
   }])], mbsrtowcs=yes, mbsrtowcs=no)
if test "$mbsrtowcs" = "no" ; then
  CFLAGS="$CFLAGS -DNO_MBTOWC_FUNCTIONS"
fi
AC_MSG_RESULT($mbsrtowcs)

if test "${try_poll_syscall}" = "yes" ; then
  [ msg="for poll" ]
  AC_MSG_CHECKING($msg)
  AC_LINK_IFELSE([AC_LANG_SOURCE([
     #include <poll.h>
     int main() {
      struct pollfd pfd;
      int r;
      pfd.fd = 0;
      pfd.events = POLLIN;
      r = poll(&pfd, 1, 0);
      return 0;
     }])], use_poll=yes, use_poll=no)
  AC_MSG_RESULT($use_poll)
  if test "${use_poll}" = "yes" ; then
     AC_DEFINE(HAVE_POLL_SYSCALL,1,[Have poll])
  fi
fi

if test "${try_epoll_syscall}" = "yes" ; then
  [ msg="for epoll" ]
  AC_MSG_CHECKING($msg)
  AC_LINK_IFELSE([AC_LANG_SOURCE([
    #include <sys/epoll.h>
    int main() {
      int fd;
      struct epoll_event ev;
      fd = epoll_create(5);
      ev.events = EPOLLIN | EPOLLONESHOT;
      epoll_ctl(fd, EPOLL_CTL_ADD, 0, &ev);
      return 0;
    }])], use_epoll=yes, use_epoll=no)
  AC_MSG_RESULT($use_epoll)
  if test "${use_epoll}" = "yes" ; then
     AC_DEFINE(HAVE_EPOLL_SYSCALL,1,[Have epoll])
  fi
fi

if test "${try_inotify_syscall}" = "yes" ; then
  [ msg="for inotify" ]
  AC_MSG_CHECKING($msg)
  AC_LINK_IFELSE([AC_LANG_SOURCE([
    #include <sys/inotify.h> 
    int main() {
      int fd;
      int wd;
      fd = inotify_init();
      wd = inotify_add_watch(fd, "/tmp", 
                             (IN_CREATE | IN_DELETE | IN_DELETE_SELF
                              | IN_MODIFY | IN_MOVE_SELF | IN_MOVED_TO));
      return 0;
    }])], use_inotify=yes, use_inotify=no)
  AC_MSG_RESULT($use_inotify)
  if test "${use_inotify}" = "yes" ; then
     AC_DEFINE(HAVE_INOTIFY_SYSCALL,1,[Have inotify])
  fi
fi

if test "${try_kqueue_syscall}" = "yes" ; then
  [ msg="for kqueue" ]
  AC_MSG_CHECKING($msg)
  AC_LINK_IFELSE([AC_LANG_SOURCE([
     #include <sys/types.h>
     #include <sys/event.h>
     #include <sys/time.h>
     int main() {
        int kq;
        struct kevent kev;
        struct timespec timeout = {0, 0};
        kq = kqueue();
        EV_SET(&kev, 0, EVFILT_READ, EV_ADD, 0, 0, NULL);
        kevent(kq, &kev, 1, NULL, 0, &timeout);
        return 0;
     }])], use_kqueue=yes, use_kqueue=no)
  AC_MSG_RESULT($use_kqueue)
  if test "${use_kqueue}" = "yes" ; then
     AC_DEFINE(HAVE_KQUEUE_SYSCALL,1,[Have kqueue])
  fi
fi

LFS_CFLAGS=`getconf LFS_CFLAGS 2> /dev/null`
if test "${LFS_CFLAGS}" != "" && test "${LFS_CFLAGS}" != "undefined"; then
  echo "Large-file support: ${LFS_CFLAGS}"
  CFLAGS="${CFLAGS} ${LFS_CFLAGS}"  
fi

AC_CHECK_DECL([O_CLOEXEC],AC_DEFINE([RKTIO_HAS_CLOEXEC],1, [Have O_CLOEXEC]), [], [#include <fcntl.h>])

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
  AC_DEFINE(RKTIO_USE_PTHREADS, 1, [Pthread enabled])
fi

############## libtool ################

if test "${enable_standalone}" = "yes" ; then
   AS_STANDALONE=t
   if test "${enable_shared}" = "" ; then
     enable_shared=yes
   fi
fi

if test "${enable_shared}" = "yes" ; then
  echo "Configuring libtool"

  # Assuming an absolute "${libdir}":
  abslibdir="${libdir}"

  if test ! -d "../lt" ; then
    mkdir "../lt"
  fi
  abssrcdir=`(cd ${srcdir}; pwd)`

  if test "${LIBTOOLPROG}" = "" ; then  
    (cd ../lt; sh ${abssrcdir}/../lt/configure --enable-shared --disable-static)
    LIBTOOLPROG=`pwd`/../lt/libtool
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
  AR="${LIBTOOLPROG} --mode=link --tag=CC $CC${need_gcc_static_libgcc}${ar_libtool_no_undefined} -release ${rktio_version} -rpath ${abslibdir} -o"
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
  ICP_LIB="${LIBTOOLPROG} --mode=install install -s"
else
  ICP=cp
  LTO="o"
  LTA="a"
  RKTLINKER="$CC"
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

CPPFLAGS="$CPPFLAGS $PREFLAGS"

AC_SUBST(CC)
AC_SUBST(CPPFLAGS)
AC_SUBST(CFLAGS)
AC_SUBST(LDFLAGS)
AC_SUBST(LIBS)
AC_SUBST(RKTLINKER)
AC_SUBST(AR)
AC_SUBST(ARFLAGS)
AC_SUBST(RANLIB)
AC_SUBST(STATIC_AR)
AC_SUBST(ICP_LIB)

AC_SUBST(LIBSFX)
AC_SUBST(LTO)
AC_SUBST(LTA)

AC_SUBST(AS_STANDALONE)

AC_SUBST(RKTIO_NO_ICONV)

AC_SUBST(HAVE_DIRENT_NAMLEN)
AC_SUBST(HAVE_DIRENT_NAMELEN)

makefiles="Makefile"

cp ${srcdir}/buildmain.zuo main.zuo

AC_OUTPUT($makefiles)
