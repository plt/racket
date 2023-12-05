iconv_lib_flag=""
if test "${skip_iconv_check}" = "no" ; then
 if test "${enable_iconv}" = "yes" ; then
  AC_CHECK_HEADER(iconv.h, enable_iconv=yes, enable_iconv=no)
  if test "${enable_iconv}" = "yes" ; then
    # Does it all work, now?
    AC_TRY_LINK(
    [#include <iconv.h>]
    [#include <langinfo.h>],
[     iconv_open("UTF-8", "UTF-8");]
      return 0;
    , enable_iconv=yes, enable_iconv=no)
    if test "${enable_iconv}" = "no" ; then
      # Try adding -liconv ?
      #  We did not use AC_CHECK_LIB because iconv is sometimes macro-renamed
      ORIG_LIBS="$LIBS"
      LIBS="$LIBS -liconv"
      AC_TRY_LINK(
      [#include <iconv.h>]
      [#include <langinfo.h>],
[     iconv_open("UTF-8", "UTF-8");]
      return 0;
      , enable_iconv=yes, enable_iconv=no)
      if test "${enable_iconv}" = "no" ; then
        LIBS="$ORIG_LIBS"
      else
        iconv_lib_flag=" -liconv"
      fi
    fi
  fi
 fi
 [ msg="iconv is usable" ]
 AC_MSG_CHECKING($msg)
 iconv_usage_result="$enable_iconv$iconv_lib_flag"
 AC_MSG_RESULT($iconv_usage_result)
fi
case "$host_os" in
  *mingw*|cygwin*)
    icu_platform_windows=yes
    ;;
  *)
    icu_platform_windows=no
    ;;
esac
if test "${enable_icu}" = "" ; then
  if test "${icu_platform_windows}" = "yes" ; then
    AC_CHECK_HEADER([icu.h], [enable_icu=yes], [enable_icu=no])
  elif test "${enable_icu_dll}" = "yes" ; then
    enable_icu=yes
  else
    enable_icu=no
  fi
fi
icu_lib_flags=""
if test "${enable_icu}" = "yes"; then
  if test "${enable_icu_dll}" = "" ; then
    if test "${icu_platform_windows}" = "yes" ; then
      enable_icu_dll=yes
    else
      enable_icu_dll=no
    fi
  fi
  if test "${enable_icu_dll}" = "no" ; then
    if test "${icu_platform_windows}" = "yes" ; then
      icu_lib_flags="-licu"
    else
      icu_lib_flags=`pkg-config icu-uc --libs 2> /dev/null`
      if test "$?" != 0 ; then
        AC_MSG_WARN([unable to infer LIBS for ICU via pkg-config])
      fi
    fi
    LIBS="${LIBS} ${icu_lib_flags}"
  fi
fi
