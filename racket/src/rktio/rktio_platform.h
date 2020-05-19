  /************** SunOS/Solaris ****************/

#if defined(sun)

# define USE_EXPLICT_FP_FORM_CHECK

# include <errno.h>
# ifdef ECHRNG
/* Solaris */
#  define NO_USLEEP
#  define USE_ULIMIT
#  define SOME_FDS_ARE_NOT_SELECTABLE
#  define RKTIO_USE_FCNTL_AND_FORK_FOR_FILE_LOCKS
#  define USE_TIMEZONE_AND_ALTZONE_VAR
#  define USE_TZNAME_VAR
#  define USE_NULL_TO_DISCONNECT_UDP
# else
/* SunOS4 */
#  define USE_TM_GMTOFF_FIELD
#  define USE_TM_ZONE_FIELD
#  define NO_STRERROR_AVAILABLE
#  define USE_FNDELAY_O_NONBLOCK
# endif

# ifdef _POSIX_PTHREAD_SEMANTICS
#  define SUBPROCESS_USE_FORK1
# endif

#endif

  /************** RS6000/AIX ****************/

# if defined(_IBMR2)

# define SELECT_INCLUDE

# define USE_TIMEZONE_VAR_W_DLS
# define USE_TZNAME_VAR

#endif

  /************** Linux ****************/

#if defined(__linux__)

# define USE_TIMEZONE_VAR_W_DLS
# define USE_TZNAME_VAR

# define RKTIO_TCP_LISTEN_IPV6_ONLY_SOCKOPT

# ifdef __ANDROID__
#  define PROTOENT_IS_INT IPPROTO_TCP
# endif

#endif

  /********************* NetBSD ***********************/

#if defined(__NetBSD__)

# define USE_TM_GMTOFF_FIELD
# define USE_TM_ZONE_FIELD

#endif

  /************** OpenBSD ****************/
  /* Thanks to Bengt Kleberg */

#if defined(__OpenBSD__)

# define USE_TM_GMTOFF_FIELD
# define USE_TM_ZONE_FIELD

#endif

  /************** FreeBSD ****************/

#if defined(__FreeBSD__) || defined(__FreeBSD_kernel__)

# define USE_TM_GMTOFF_FIELD
# define USE_TM_ZONE_FIELD
# define MAX_VALID_DATE_SECONDS_BITS 51

#endif

  /************** Haiku ****************/

#if defined(__HAIKU__)

# define DIRENT_NO_NAMLEN
# define RKTIO_USE_FCNTL_AND_FORK_FOR_FILE_LOCKS
# define RKTIO_USE_PTHREADS
//# define MZ_PRECISE_GC

#endif

  /************** SGI/IRIX ****************/

#if  (defined(mips) || defined(__mips)) \
     && !(defined(ultrix) || defined(__ultrix) || defined(__linux__) || defined(__OpenBSD__))

# define BSTRING_INCLUDE

# define NO_USLEEP

# define USE_TIMEZONE_AND_ALTZONE_VAR
# define USE_TZNAME_VAR

#endif

  /************** Ultrix ****************/

#if defined(ultrix) || defined(__ultrix)

# define NO_USLEEP

#endif

  /************** ALPHA/OSF1 ****************/

# if (defined(__alpha) || defined(__alpha__)) \
    && !defined(__linux__) && !defined(__NetBSD__) && !defined(__OpenBSD__)

# define USE_FNDELAY_O_NONBLOCK

#endif

  /************** HP/UX with cc or gcc ****************/

#if defined(__hpux)

# define SOME_FDS_ARE_NOT_SELECTABLE

# define USE_SYSCALL_GETRUSAGE

# define USE_ULIMIT

# define USE_TIMEZONE_VAR_W_DLS
# define USE_TZNAME_VAR

#endif

  /****************** Windows with MSVC or MinGW *****************/

#if (defined(__BORLANDC__) \
     || ((defined(_MSC_VER) || defined(__MINGW32__)) \
         && (defined(__WIN32__) || defined(WIN32) || defined(_WIN32))))

# if defined(_MSC_VER) || defined(__MINGW32__)
#  define NO_READDIR
#  define USE_FINDFIRST
#  define MKDIR_NO_MODE_FLAG
# endif
# if defined(__BORLANDC__)
#  define MKDIR_NO_MODE_FLAG
# endif

#endif

  /******************** Windows with Cygwin ******************/

#if defined(__CYGWIN32__)

# define RKTIO_BINARY O_BINARY

# define SIGCHILD_DOESNT_INTERRUPT_SELECT

# define CANT_SET_SOCKET_BUFSIZE
# define NO_NEED_FOR_BEGINTHREAD
# define USE_CREATE_PIPE

# define USE_PLAIN_TIME
# define USE_TOD_FOR_TIMEZONE

#endif

  /************** MacOS and Darwin  ****************/

#if defined(__APPLE__) && defined(__MACH__)

# define RKTIO_TCP_LISTEN_IPV6_ONLY_SOCKOPT

# define USE_TM_GMTOFF_FIELD
# define USE_TM_ZONE_FIELD

# define UDP_DISCONNECT_EADRNOTAVAIL_OK

# define RKTIO_GROWABLE_FDSET

# endif

  /************ QNX *************/

#if defined(__QNX__)

# define BROKEN_READLINK_NUL_TERMINATOR

#endif

  /************ Dragonfly *************/

#if defined(__DragonFly__)

# define USE_TM_GMTOFF_FIELD
# define USE_TM_ZONE_FIELD
# define MAX_VALID_DATE_SECONDS_BITS 51

#endif

  /***************************************************/

/***** CONFIGURATION FLAG DESCRPTIONS ******/

  /*********************/
 /* Date and time     */
/*********************/

 /* DONT_USE_GETRUSAGE uses clock() for timing info. */

 /* USE_SYSCALL_GETRUSAGE uses syscall() to implement getrusage() for
    timing info. Used with USE_GETRUSAGE. */

 /* CLOCKS_PER_SEC relates the values returned by clock() to
     real seconds. (The difference between two clock() calls is
     divided by this number.) Usually, this is defined in <time.h>;
     it defaults to 1000000 */

 /* USE_PLAIN_TIME uses time. */

 /* CLOCK_IS_USER_TIME uses the system time for user milliseconds. */

 /* USER_TIME_IS_CLOCK uses the user time for system milliseconds. */

 /* MAX_VALID_DATE_SECONDS_BITS sets a maximum number of bits for
    seconds to pass to localtime() ro gmtime(). */

 /* MIN_VALID_DATE_SECONDS sets a minimum vald time in seconds. */

 /* USE_TIMEZONE_VAR gets timezone offset from a timezone global.
    USE_TOD_FOR_TIMEZONE gets timezone offset via gettimeofday.
    USE_TIMEZONE_VAR_W_DLS is similar, but adds 1 hour when daylight
     savings is in effect.
    USE_TIMEZONE_AND_ALTZONE_VAR is similar, but uses altzone when
     daylight savings is in effect.
    USE_TM_GMTOFF_FIELD gets timezone offset from the tm_gmtoff field
     of the tm struct. */

 /* USE_TZNAME_VAR gets the timezone name from a tzname global.
    USE_TM_ZONE_FIELD gets the timezone name from a tm_zone field
     of the tm struct. */

  /*******************/
 /*   Filesystem    */
/*******************/

 /* NO_STAT_PROC means that there is no stat() function. */

 /* NO_MKDIR means that there is no mkdir() function. */

 /* BROKEN_READLINK_NUL_TERMINATOR means that readlink() may
    report a length that includes trailing NUL terminators,
    which should be stripped away. */

 /* USE_GETDISK uses getdisk() and setdisk() to implement the
     filesystem-root-list primitive under DOS. */

 /* NO_READDIR means that there is no opendir() and readdir() for
     implementing directory-list. */

 /* MKDIR_NO_MODE_FLAG specifies that mkdir() takes only one argument,
     instead of a directory name and mode flags. */

  /***********************/
 /*  File descriptors   */
/***********************/

 /* RKTIO_USE_FCNTL_AND_FORK_FOR_FILE_LOCKS means that fnctl() and fork()
    should be used to implement file locking instead of flock(). */

 /* SUBPROCESS_USE_FORK1 uses fork1() instead of fork(). */

 /* USE_FNDELAY_O_NONBLOCK uses FNDELAY instead of O_NONBLOCK for
    fcntl on Unix TCP sockets. */

 /* SOME_FDS_ARE_NOT_SELECTABLE indicates that select() doesn't work
    for reading on all kinds of file descriptors. Such FDs must never
    be able to go from no-char-ready to char-ready while Racket is
    sleeping. */

 /* USE_TRANSITIONAL_64_FILE_OPS uses lseek64, stat64, etc. for file
    operations involving sizes (that can require 64-bit
    arithmetic). */

 /* USE_ULIMIT uses ulimit instead of getdtablesize. */

 /* CANT_SET_SOCKET_BUFSIZE turns off setting the buffer size for
    Unix TCP sockets. */

 /* USE_NULL_TO_DISCONNECT_UDP calls connect() with NULL instead of
    an AF_UNSPEC address to disconnect a UDP socket. */

 /* UDP_DISCONNECT_EADRNOTAVAIL_OK means that a disconnecting call
    to connect() might return EADDRNOTAVAIL instead of
    EAFNOSUPPORT. */

 /* MZ_BINARY is combined with other flags in all calls to open();
    it can be defined to O_BINARY in Cygwin, for example. */

 /* MZ_TCP_LISTEN_IPV6_ONLY_SOCKOPT uses IPV6_V6ONLY for IPv6
    listeners when the same listener has an IPv4 address, which means
    that the IpV6 listener accepts only IPv6 connections. This is used
    with Linux, for example, because a port cannot have both an IPv4
    and IPv6 listener if the IPv6 one doesn't use IPV6_V6ONLY. (The
    two listeners might be for different interfaces, in which case
    IPV6_V6ONLY is not necessary, but we must err on the side of being
    too restrictive. If IPV6_V6ONLY is not #defined or if setting the
    option doesn't work, then the IPv6 addresses are silently ignored
    when creating the listener (but only where there is at least once
    IPv4 address). */

 /* RKTIO_GROWABLE_FDSET enables fd-set array sizing dynamically based
    on the file descriptor values that occur at runtime (as opposed to
    querying the OS for the size, possibly because the size can change). */

  /***********************/
 /* Signals             */
/***********************/

 /* USE_CREATE_PIPE uses CreatePipe() instead of _pipe() for Windows. */

 /* SIGCHILD_DOESNT_INTERRUPT_SELECT indicates that the SIGCHILD
    signal, sent when a child OS process dies, does not interrupt
    select(). This flag is needed for Cygwin B20. */

  /***********************/
 /*    Miscellaneous    */
/***********************/

 /* DIR_INCLUDE if there's a <dir.h> file (mainly for Windows). */

 /* DIRECT_INCLUDE if there's a <direct.h> file (mainly for Windows). */

 /* IO_INCLUDE if there's a <io.h> file (mainly for Windows). */

 /* SELECT_INCLUDE if there's a <sys/select.h> file (mainly for Unix). */

 /* BSTRING_INCLUDE if there's a <bstring.h> file (mainly for Unix). */

 /* NO_SLEEP means that there is no sleep() function. Used only in
    standalone Racket. */

 /* NO_USLEEP means that there is no usleep() function. Used only in
    standalone Racket. Used only if NO_SLEEP is undefined. */

 /* NO_STRERROR_AVAILABLE means that strerror() is not available. */
