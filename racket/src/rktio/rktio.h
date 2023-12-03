#ifndef __RKTIO_H__
#define __RKTIO_H__ 1

/*

Allocation conventions:

 - Unless otherwise specified, returned data must be deallocated ---
   using a type-specific deallocation function if provided or
   `rktio_free` otherwise. The `rktio_free` function is the same as
   `free`.

 - There's no reference counting. Unless otherwise specified, if
   object A is created given object B, then a client must keep object
   B alive as long as object A exists.

 - String arguments are copied by `rktio_...` functions if the strings
   must be retained. Unless otherwise specified, creating an object A
   with string S doesn't require that S stay live as long as A exists.
   String results are generally allocated and must be freed by the
   client.

Return type conventions:

 - A return type `rktio_ok_t` (alias for `int`) means that 1 is
   returned for success and 0 for error. Use
   `rktio_get_last_error_kind` and `rktio_get_last_error` for more
   information about a 0 result.

 - A return type `rktio_tri_t` (alias for `int`) means that 0 is
   returned for an expected failure, some `RKTIO_...` (alias for 1)
   is returned for success, and `RKTIO_...ERROR` (alias for -2) is
   returned for some error. The function will be annotated with
   `RKTIO_EXTERN_ERR(...)` to indicate the error value. Use
   `rktio_get_last_error_kind` and `rktio_get_last_error` for more
   information about a `RKTIO_...ERROR` result.

 - A return type `rktio_bool_t` means that the result is a simple 0 or
   1, and no error is possible.

 - For a pointer return type, unless otherwise specified, a NULL
   result means an error. Use `rktio_get_last_error_kind` and
   `rktio_get_last_error` for more information about the error.

 - If a function returns `void`, you can rely on it to not change the
   error reported by `rktio_get_last_error_kind` and
   `rktio_get_last_error`.

 - A function annotated with `RKTIO_EXTERN_NOERR` always succeeds, so
   it never sets the error reported by `rktio_get_last_error_kind` and
   `rktio_get_last_error`. If a function returns `void` or
   `rktio_bool_t`, then `RKTIO_EXTERN` is implicitly
   `RKTIO_EXTERN_NOERR`.

 - A function annotated with `RKTIO_EXTERN_STEP` sets the value
   to be reported by `rktio_get_last_error_step` when it returns a
   value that indicates an error.

Thread and signal conventions:

 - A given `rktio_t` can be used from only one thread at a time.
   Otherwise, as long as the initial call to `rktio_init` returns
   before a second call, different `rktio_t` values can be used freely
   from different threads.

 - Unless otherwise specified, anything created with a particular
   `rktio_t` must be used with that same `rktio_t` thereafter (and in
   only one thread at a time).

 - If a function doesn't take a `rktio_t` argument, then it can be
   called concurrently with anything else. Notably,
   `rktio_signal_received_at` does not take a `rktio_t`.

 - SIGCHLD may be enabled, blocked, and/or handled by the `rktio`
   library.

 - On systems where signal handling is thread-specific, as on Linux,
   then `rktio_init` should be called before any additional threads,
   so that a suitable inheritable signal disposition can be
   configured.

*/
     
#include "rktio_config.h"

#ifndef RKTIO_EXTERN
# define RKTIO_EXTERN extern
#endif

#define RKTIO_EXTERN_ERR(n) RKTIO_EXTERN
#define RKTIO_EXTERN_NOERR  RKTIO_EXTERN
#define RKTIO_EXTERN_STEP   RKTIO_EXTERN

#define RKTIO_NULLABLE      /* empty; pointer type can be NULL */
#define RKTIO_BLOCKING      /* empty; function blocks indefinitely */
#define RKTIO_MSG_QUEUE     /* empty; function can dispatch events on Windows */

/*************************************************/
/* Initialization and general datatypes          */

typedef struct rktio_t rktio_t;
/* A rktio_t value represents an instance of the Racket I/O system.
   Almost every `rktio_...` function takes it as the first argument. */

RKTIO_EXTERN rktio_t *rktio_init(void);
/* Call `rktio_init` before anything else. The first call to
   `rktio_init` must return before any additional calls (in other
   threads), but there's no ordering requirement after that. 
   If the result is NULL, then there's no way to get an error
   code, so assume `RKTIO_ERROR_INIT_FAILED`. */

RKTIO_EXTERN void rktio_destroy(rktio_t *rktio);
/* Call `rktio_destroy` as the last thing. Everything else must be
   explicitly deallocated/closed/forgotten before calling
   `rktio_destroy`. */

RKTIO_EXTERN void rktio_free(void *p);
/* Normally equivalent to `free`, but ensures the same `malloc`/`free`
   that rktio function use. */

typedef int rktio_ok_t;
/* A result of this type is 0 for failure (in which case an error is
   available from `rktio_get_last_error`) and 1 for success. */

typedef int rktio_tri_t;
/* A result of this type is a boolean, but a `...ERROR` value means
   that an error value is available from `rktio_get_last_error`. */

typedef int rktio_bool_t;
/* 0 or 1. */

typedef unsigned short rktio_char16_t;
/* A UTF-16 code unit. A `rktio_char16_t *` is meant to be the same as
   `wchar_t *` on Windows. */

typedef const char *rktio_const_string_t;
/* An argument that is a NUL-terminated string, as opposed to a buffer
   where a length is provided separately and doesn't need to be
   NUL-terminated. */

/*************************************************/
/* DLL paths                                     */

RKTIO_EXTERN void rktio_set_dll_path(rktio_char16_t *p);
/* Sets a path to search for loading DLLs, such as `iconv` on Windows.
   This function departs from all the usual conventions: the given
   path is in wide-character format, it's not copied, and it's not
   specific to a `rktio_t` instance. */

RKTIO_EXTERN rktio_char16_t *rktio_get_dll_path(rktio_char16_t *p);
/* Combines a path previously registered with `rktio_set_dll_path` with
   the given filename. The result is allocated (as should be
   deallocated) as usual. */

/*************************************************/
/* Reading and writing files                     */

typedef struct rktio_fd_t rktio_fd_t;

/* Mode flags shared in part by `rktio_open` and `rktio_system_fd`. */

/* Accepted by both, but `RKTIO_OPEN_READ` and `RKTIO_OPEN_WRITE` are
   merely advisory for `rktio_system_fd` */
#define RKTIO_OPEN_READ        (1<<0)
#define RKTIO_OPEN_WRITE       (1<<1)
#define RKTIO_OPEN_TEXT        (1<<2)

/* Used for `rktio_open` with `RKTIO_OPEN_WRITE`: */
#define RKTIO_OPEN_TRUNCATE    (1<<3)
#define RKTIO_OPEN_APPEND      (1<<4)
#define RKTIO_OPEN_MUST_EXIST  (1<<5)
#define RKTIO_OPEN_CAN_EXIST   (1<<6)
/* `RKTIO_OPEN_APPEND` implies `RKTIO_OPEN_CAN_EXIST` */

/* Used for `rktio_system_fd`: */
#define RKTIO_OPEN_SOCKET      (1<<7)
#define RKTIO_OPEN_UDP         (1<<8)
#define RKTIO_OPEN_REGFILE     (1<<9)
#define RKTIO_OPEN_NOT_REGFILE (1<<10)
/* If neither RKTIO_OPEN_REGFILE nor RKTIO_OPEN_NOT_REGFILE
   are specified, then the value is inferred by `rtkio_system_fd`. */
#define RKTIO_OPEN_DIR         (1<<11)
#define RKTIO_OPEN_NOT_DIR     (1<<12)
/* Inferred when neither is specified and when `RKTIO_OPEN_[NOT_]REGFILE`
   is also inferred. */
#define RKTIO_OPEN_INIT        (1<<13)
/* Make `rtkio_system_fd` set a socket as nonblocking, etc. */
#define RKTIO_OPEN_OWN         (1<<14)
/* Make `rtkio_system_fd` record a socket for reliable clean up on pre-NT Windows. */

/* Used for `rktio_open` with `RKTIO_OPEN_WRITE`: */
#define RKTIO_OPEN_REPLACE_PERMS (1<<15)

RKTIO_EXTERN rktio_fd_t *rktio_system_fd(rktio_t *rktio, intptr_t system_fd, int modes);
/* A socket (as opposed to other file descriptors) registered this way
   should include include `RKTIO_OPEN_SOCKET` and be non-blocking or
   use `RKTIO_OPEN_INIT`. */

RKTIO_EXTERN_NOERR intptr_t rktio_fd_system_fd(rktio_t *rktio, rktio_fd_t *rfd);
/* Extracts a native file descriptor or socket. A file descriptor must
   not be in pending-open mode as reported by `rktio_fd_is_pending_open`. */

RKTIO_EXTERN rktio_bool_t rktio_fd_is_regular_file(rktio_t *rktio, rktio_fd_t *rfd);
RKTIO_EXTERN rktio_bool_t rktio_fd_is_directory(rktio_t *rktio, rktio_fd_t *rfd);
RKTIO_EXTERN rktio_bool_t rktio_fd_is_socket(rktio_t *rktio, rktio_fd_t *rfd);
RKTIO_EXTERN rktio_bool_t rktio_fd_is_udp(rktio_t *rktio, rktio_fd_t *rfd);
RKTIO_EXTERN rktio_bool_t rktio_fd_is_terminal(rktio_t *rktio, rktio_fd_t *rfd);
/* The functions mostly report values of recorded mode flags. */

RKTIO_EXTERN rktio_bool_t rktio_fd_is_text_converted(rktio_t *rktio, rktio_fd_t *rfd);
/* Reports whether `RKTIO_OPEN_TEXT` was used and has an effect. The
   `RKTIO_OPEN_TEXT` flag has an effect only on Windows. */

RKTIO_EXTERN rktio_bool_t rktio_fd_is_pending_open(rktio_t *rktio, rktio_fd_t *rfd);
/* Reports whether `rfd` will block on writing because it corresponds
   to the write end of a fifo that has no open reader. In that case,
   `rktio_fd_system_fd` cannot report a file descriptor and `rktio_ltps_add`
   will error with `RKTIO_ERROR_UNSUPPORTED`. */

RKTIO_EXTERN_NOERR int rktio_fd_modes(rktio_t *rktio, rktio_fd_t *rfd);
/* Returns all of the recorded mode flags, including those provided to
   `rktio_system_fd` and those that are inferred. The
   `RKTIO_OPEN_INIT` flag is not recorded, however. */

RKTIO_EXTERN rktio_fd_t *rktio_open(rktio_t *rktio, rktio_const_string_t src, int modes);
/* Can report `RKTIO_ERROR_DOES_NOT_EXIST` in place of a system error
   in read mode, and can report `RKTIO_ERROR_IS_A_DIRECTORY`,
   `RKTIO_ERROR_EXISTS`, or `RKTIO_ERROR_ACCESS_DENIED` in place of a
   system error in write mode. On Windows, can report
   `RKTIO_ERROR_UNSUPPORTED_TEXT_MODE`. If `modes` has `RKTIO_OPEN_WRITE`
   without `RKTIO_OPEN_READ`, then the result may be a file descriptor
   in pending-open mode until the read end is opened. */

RKTIO_EXTERN rktio_fd_t *rktio_open_with_create_permissions(rktio_t *rktio,
                                                            rktio_const_string_t src,
                                                            int modes, int perm_bits);
/* Like `rktio_open`, but accepts permission bits that are used if the
   file is created (which is only relevant if `modes` includes
   `RKTIO_OPEN_WRITE`). On Unix, perm_bits are adjusted by a umask.
   Otherwise, permission bits are treated in the same way as
   by `rktio_set_file_or_directory_permissions`. */
#define RKTIO_DEFAULT_PERM_BITS 0666

RKTIO_EXTERN rktio_ok_t rktio_close(rktio_t *rktio, rktio_fd_t *fd);
/* Can report `RKTIO_ERROR_EXISTS` in place of system error,
   and can report `RKTIO_ERROR_UNSUPPORTED_TEXT_MODE` on Windows.
   See also `rktio_write` and `rktio_poll_write_flushed`. */

RKTIO_EXTERN void rktio_close_noerr(rktio_t *rktio, rktio_fd_t *fd);
/* The same as `rktio_close`, but without reporting errors. There's
   often nothing good to do if a close fails, especially if the close
   is in the service of handling another failure where you don't want
   the error code replaced. */

RKTIO_EXTERN rktio_fd_t *rktio_dup(rktio_t *rktio, rktio_fd_t *rfd);
/* Copies a file descriptor, where each must be closed or forgotten
   independently. */

RKTIO_EXTERN void rktio_forget(rktio_t *rktio, rktio_fd_t *fd);
/* Deallocates a `rktio_fd_t` without closing the file descriptor,
   but the descriptor is no longer recorded if it was opened with
   `RKTIO_OPEN_OWN`. */

RKTIO_EXTERN rktio_fd_t *rktio_std_fd(rktio_t *rktio, int which);
/* Gets stdin/stdout/stderr. */
/* `which` values: */
#define RKTIO_STDIN  0
#define RKTIO_STDOUT 1
#define RKTIO_STDERR 2

RKTIO_EXTERN void rktio_create_console(void);
/* On Windows, ensures that a console is available for output. If a
   console is created for an application started in GUI mode, The
   console cannot be closed by the user until the process exits, and
   then an atexit callback pauses the exit until the user closes the
   console. */

RKTIO_EXTERN_ERR(RKTIO_READ_ERROR)
intptr_t rktio_read(rktio_t *rktio, rktio_fd_t *fd, char *buffer, intptr_t len);
/* Returns the number of bytes read, possibly 0, in non-blocking mode.
   Alternatively, the result can be `RKTIO_READ_EOF` for end-of-file
   or `RKTIO_READ_ERROR` for an error. Although rktio_read is intended
   to have no buffering, text-mode conversion (on Windows) and certain
   uncooperative OS corners can buffer 1 byte. */

#define RKTIO_READ_EOF   (-1)
#define RKTIO_READ_ERROR (-2)

RKTIO_EXTERN_ERR(RKTIO_WRITE_ERROR)
intptr_t rktio_write(rktio_t *rktio, rktio_fd_t *fd, const char *buffer, intptr_t len);
/* Returns the number of bytes written, possibly 0, in non-blocking
   mode. Alternatively, the result can be `RKTIO_WRITE_ERROR` for an
   error. Although `rktio_write` is intended to write only bytes that
   can be fully delivered to the OS, there may be OS limitations that
   require buffering (e.g., on ancient versions of Windows). Use
   `rktio_poll_write_flushed` to make sure the data is received by the
   destination before closing `fd`. */

#define RKTIO_WRITE_ERROR (-2)

RKTIO_EXTERN_ERR(RKTIO_READ_ERROR)
intptr_t rktio_read_converted(rktio_t *rktio, rktio_fd_t *fd, char *buffer, intptr_t len,
                              char *is_converted);
/* Like `rktio_read`, but also reports whether each character was
   originally two characters that were converted to a single newline for
   text mode. */

RKTIO_EXTERN_ERR(RKTIO_READ_ERROR)
intptr_t rktio_read_in(rktio_t *rktio, rktio_fd_t *fd, char *buffer, intptr_t start, intptr_t end);
RKTIO_EXTERN_ERR(RKTIO_WRITE_ERROR)
intptr_t rktio_write_in(rktio_t *rktio, rktio_fd_t *fd, const char *buffer, intptr_t start, intptr_t end);
RKTIO_EXTERN_ERR(RKTIO_READ_ERROR)
intptr_t rktio_read_converted_in(rktio_t *rktio, rktio_fd_t *fd, char *buffer, intptr_t start, intptr_t len,
                                 char *is_converted, intptr_t converted_start);
/* Like `rktio_read`, `rktio_write`, and `rktio_read_converted` but
   accepting start and end positions within `buffer`. */

RKTIO_EXTERN_NOERR intptr_t rktio_buffered_byte_count(rktio_t *rktio, rktio_fd_t *fd);
/* Reports the number of bytes that are buffered from the file descriptor.
   The result is normally zero, but text-mode conversion and the rare
   uncooperative corner of an OS can make the result 1 byte. */

RKTIO_EXTERN_ERR(RKTIO_POLL_ERROR)
rktio_tri_t rktio_poll_read_ready(rktio_t *rktio, rktio_fd_t *rfd);
RKTIO_EXTERN_ERR(RKTIO_POLL_ERROR)
rktio_tri_t rktio_poll_write_ready(rktio_t *rktio, rktio_fd_t *rfd);
/* Each polling function returns one of the following: */
#define RKTIO_POLL_NOT_READY 0
#define RKTIO_POLL_READY 1
#define RKTIO_POLL_ERROR (-2)

RKTIO_EXTERN_ERR(RKTIO_POLL_ERROR)
rktio_tri_t rktio_poll_write_flushed(rktio_t *rktio, rktio_fd_t *rfd);
/* See `rktio_write` above. Currently, the result is `RKTIO_POLL_NO_READY`
   only on Windows, and only for a pipe or similar non-regular file.
   A pipe counts as "flushed" when the other end has received the data
   (because the sent data doesn't persist beyond closing the pipe). */

RKTIO_EXTERN_ERR(RKTIO_LOCK_ERROR)
rktio_tri_t rktio_file_lock_try(rktio_t *rktio, rktio_fd_t *rfd, rktio_bool_t excl);
RKTIO_EXTERN rktio_ok_t rktio_file_unlock(rktio_t *rktio, rktio_fd_t *rfd);
/* Advisory file locks, where `excl` attempts to claim an exclusive
   lock. Whether these work in various situations depend on many OS
   details, where the differences involve promoting from non-exclusive
   to exclusive, taking a lock that is already held, getting an
   exclusive lock for a file descriptor in read mode, getting a
   non-exclusive lock in write mode, and whether a lock prevents
   opening or using another file descriptor. */

#define RKTIO_LOCK_ERROR        (-2)
#define RKTIO_LOCK_ACQUIRED     1
#define RKTIO_LOCK_NOT_ACQUIRED 0

typedef rktio_int64_t rktio_filesize_t;

RKTIO_EXTERN rktio_ok_t rktio_set_file_position(rktio_t *rktio, rktio_fd_t *rfd, rktio_filesize_t pos, int whence);
/* Can report `RKTIO_ERROR_CANNOT_FILE_POSITION` on Windows. */
/* For `whence`: */
enum {
  RKTIO_POSITION_FROM_START,
  RKTIO_POSITION_FROM_END
};

RKTIO_EXTERN rktio_filesize_t *rktio_get_file_position(rktio_t *rktio, rktio_fd_t *rfd);
/* Returns the file position, not taking into account rare input
   buffering (see `rktio_read`). On Windows, can report
   `RKTIO_ERROR_CANNOT_FILE_POSITION`, which doesn't have a
   corresponding Windows error code. */

RKTIO_EXTERN rktio_ok_t rktio_set_file_size(rktio_t *rktio, rktio_fd_t *rfd, rktio_filesize_t sz);
/* Can report `RKTIO_ERROR_CANNOT_FILE_POSITION` on Windows. */

typedef struct rktio_fd_transfer_t rktio_fd_transfer_t;
/* Represents an rktio_fd_t that is detached from a specific rktio_t */

RKTIO_EXTERN_NOERR rktio_fd_transfer_t *rktio_fd_detach(rktio_t *rktio, rktio_fd_t *rfd);
/* Returns a variant of `rfd` that does not depend on `rktio`. The
   `rfd` must not currently have any file locks, and detaching
   transfers ownership of `rfd` to the result. To use the result, it
   must be reattached to some `rktio_t` using rktio_fd_attach, or it
   can be freed with `rktio_fd_free_transfer`. */

RKTIO_EXTERN_NOERR rktio_fd_t *rktio_fd_attach(rktio_t *rktio, rktio_fd_transfer_t *rfdt);
/* Attaches a file descriptor that was formerly detached with
   `rktio_fd_detach` so it can be used again, consuming the `rfdt`. */

RKTIO_EXTERN void rktio_fd_close_transfer(rktio_fd_transfer_t *rfdt);
/* Closes and frees a detached file descriptor without having to
   attach it to a `rktio_t`. */

/*************************************************/
/* Pipes                                         */

RKTIO_EXTERN rktio_fd_t **rktio_make_pipe(rktio_t *rktio, int flags);
/* Makes a pair of file descriptors for a pipe. The first one
   is the read end, and the second is the write end. The `flags`
   can declare the intended sharing of the file descriptors
   with a child process, and is useful only on Windows. */
/* For `flags`: */
#define RKTIO_NO_INHERIT_INPUT  (1<<0)
#define RKTIO_NO_INHERIT_OUTPUT (1<<1)

/*************************************************/
/* Network                                       */

typedef struct rktio_addrinfo_lookup_t rktio_addrinfo_lookup_t;
typedef struct rktio_addrinfo_t rktio_addrinfo_t;

RKTIO_EXTERN rktio_addrinfo_lookup_t *rktio_start_addrinfo_lookup(rktio_t *rktio,
                                                                  rktio_const_string_t hostname, int portno,
                                                                  int family, rktio_bool_t passive, rktio_bool_t tcp);
/* The `family` argument should be one of the following: */
#define RKTIO_FAMILY_ANY (-1)
RKTIO_EXTERN_NOERR int rktio_get_ipv4_family(rktio_t *rktio);

RKTIO_EXTERN_ERR(RKTIO_POLL_ERROR)
rktio_tri_t rktio_poll_addrinfo_lookup_ready(rktio_t *rktio, rktio_addrinfo_lookup_t *lookup);
/* Check whether an address is available for a lookup request. */

RKTIO_EXTERN rktio_addrinfo_t *rktio_addrinfo_lookup_get(rktio_t *rktio, rktio_addrinfo_lookup_t *lookup);
/* Deallocates `lookup`. */

RKTIO_EXTERN void rktio_addrinfo_lookup_stop(rktio_t *rktio, rktio_addrinfo_lookup_t *lookup);
/* Abandons a lookup whose result (or error) is not yet received. */

RKTIO_EXTERN void rktio_addrinfo_free(rktio_t *rktio, rktio_addrinfo_t *a);
/* Frees the result of a lookup. */

typedef struct rktio_listener_t rktio_listener_t;
typedef struct rktio_connect_t rktio_connect_t;

RKTIO_EXTERN rktio_listener_t *rktio_listen(rktio_t *rktio, rktio_addrinfo_t *local, int backlog, rktio_bool_t reuse);
/* Can fail with `RKTIO_ERROR_TRY_AGAIN_WITH_IPV4`, which suggests
   trying an address using the family reported by
   `rktio_get_ipv4_family` instead of `RKTIO_FAMILY_ANY`. */

RKTIO_EXTERN void rktio_listen_stop(rktio_t *rktio, rktio_listener_t *l);
/* Stops a listener. */

RKTIO_EXTERN_ERR(RKTIO_POLL_ERROR)
rktio_tri_t rktio_poll_accept_ready(rktio_t *rktio, rktio_listener_t *listener);
/* Returns one of `RKTIO_POLL_READY`, etc. */

RKTIO_EXTERN rktio_fd_t *rktio_accept(rktio_t *rktio, rktio_listener_t *listener);
/* Accepts one connection on a listener. */

RKTIO_EXTERN rktio_connect_t *rktio_start_connect(rktio_t *rktio,
                                                  rktio_addrinfo_t *remote,
                                                  RKTIO_NULLABLE rktio_addrinfo_t *local);
/* Starts a connection request. Addresses must not be freed until the
   connection is complete, errored, or stopped. */

RKTIO_EXTERN rktio_fd_t *rktio_connect_finish(rktio_t *rktio, rktio_connect_t *conn);
/* A `RKTIO_ERROR_CONNECT_TRYING_NEXT` error effectively means "try
   again", and the connection object is still valid. On any other
   error, or if the connection completes successfully, `conn` is
   deallocated */

RKTIO_EXTERN void rktio_connect_stop(rktio_t *rktio, rktio_connect_t *conn);
/* Stops a connection whose result or error has not been received. */

RKTIO_EXTERN_ERR(RKTIO_POLL_ERROR)
rktio_tri_t rktio_poll_connect_ready(rktio_t *rktio, rktio_connect_t *conn);
/* Returns one of `RKTIO_POLL_READY`, etc. */

RKTIO_EXTERN rktio_fd_t *rktio_connect_trying(rktio_t *rktio, rktio_connect_t *conn);
/* Returns a file descriptor that `conn` is currently trying, or
   returns NULL without setting any error. The result file descriptor
   should not be closed, and may be closed by a `rktio_connect_finish`
   or `rktio_connect_stop` call (so if you register it in an long-term
   poll set, unregister it before trying to finish or stop the
   connection). */

RKTIO_EXTERN rktio_ok_t rktio_socket_shutdown(rktio_t *rktio, rktio_fd_t *rfd, int mode);
/* Useful for TCP to report an EOF to the other end. Does not close the socket,
   but may make it ineligible for further use.
   `mode` values: */
#define RKTIO_SHUTDOWN_READ   0
#define RKTIO_SHUTDOWN_WRITE  1

RKTIO_EXTERN rktio_ok_t rktio_tcp_nodelay(rktio_t *rktio, rktio_fd_t *rfd, rktio_bool_t enable);
/* Changes a connection to enable or disable "TCP_NODELAY" mode,
   which diabled Nagle's algorithm for avoiding small packets. */

RKTIO_EXTERN rktio_fd_t *rktio_udp_open(rktio_t *rktio, RKTIO_NULLABLE rktio_addrinfo_t *addr, int family);
/* The `addr` argument can be NULL to create a socket without
   specifying an interface, and `family` is used only if `addr` is not
   specified. */

RKTIO_EXTERN rktio_ok_t rktio_udp_disconnect(rktio_t *rktio, rktio_fd_t *rfd);
RKTIO_EXTERN rktio_ok_t rktio_udp_bind(rktio_t *rktio, rktio_fd_t *rfd, rktio_addrinfo_t *addr,
                                       rktio_bool_t reuse);
RKTIO_EXTERN rktio_ok_t rktio_udp_connect(rktio_t *rktio, rktio_fd_t *rfd, rktio_addrinfo_t *addr);

RKTIO_EXTERN_ERR(RKTIO_WRITE_ERROR)
intptr_t rktio_udp_sendto(rktio_t *rktio, rktio_fd_t *rfd, RKTIO_NULLABLE rktio_addrinfo_t *addr,
                          const char *buffer, intptr_t len);
/* Extends `rktio_write` to accept a destination `addr`, and binds `rfd` if it 
   is not bound already. The `addr` can be NULL if the socket is connected. */

RKTIO_EXTERN_ERR(RKTIO_WRITE_ERROR)
intptr_t rktio_udp_sendto_in(rktio_t *rktio, rktio_fd_t *rfd, RKTIO_NULLABLE rktio_addrinfo_t *addr,
                             const char *buffer, intptr_t start, intptr_t end);
/* Like `rktio_udp_sendto`, but with starting and ending offsets within `buffer`. */

typedef struct rktio_length_and_addrinfo_t {
  intptr_t len;
  char **address; /* like the result of `rktio_socket_address` */
} rktio_length_and_addrinfo_t;

RKTIO_EXTERN rktio_length_and_addrinfo_t *rktio_udp_recvfrom(rktio_t *rktio, rktio_fd_t *rfd,
                                                             char *buffer, intptr_t len);
/* Extend `rktio_read` to report the sender. If the reported error can
   be `RKTIO_ERROR_TRY_AGAIN` or `RKTIO_ERROR_INFO_TRY_AGAIN`, where
   the latter can happen if the sock claims to be ready to read. */

RKTIO_EXTERN rktio_length_and_addrinfo_t *rktio_udp_recvfrom_in(rktio_t *rktio, rktio_fd_t *rfd,
                                                                char *buffer, intptr_t start, intptr_t end);
/* Like `rktio_udp_recvfrom`, but with starting and ending offsets. */

RKTIO_EXTERN rktio_ok_t rktio_udp_set_receive_buffer_size(rktio_t *rktio, rktio_fd_t *rfd, int size);

RKTIO_EXTERN rktio_ok_t rktio_udp_set_ttl(rktio_t *rktio, rktio_fd_t *rfd, int ttl_val);
RKTIO_EXTERN_ERR(RKTIO_PROP_ERROR) rktio_tri_t rktio_udp_get_ttl(rktio_t *rktio, rktio_fd_t *rfd);


RKTIO_EXTERN_ERR(RKTIO_PROP_ERROR) rktio_tri_t rktio_udp_get_multicast_loopback(rktio_t *rktio, rktio_fd_t *rfd);
RKTIO_EXTERN rktio_ok_t rktio_udp_set_multicast_loopback(rktio_t *rktio, rktio_fd_t *rfd, rktio_bool_t on);
RKTIO_EXTERN_ERR(RKTIO_PROP_ERROR) rktio_tri_t rktio_udp_get_multicast_ttl(rktio_t *rktio, rktio_fd_t *rfd);

RKTIO_EXTERN rktio_ok_t rktio_udp_set_multicast_ttl(rktio_t *rktio, rktio_fd_t *rfd, int ttl_val);

#define RKTIO_PROP_ERROR (-2)

RKTIO_EXTERN char *rktio_udp_multicast_interface(rktio_t *rktio, rktio_fd_t *rfd);
RKTIO_EXTERN rktio_ok_t rktio_udp_set_multicast_interface(rktio_t *rktio, rktio_fd_t *rfd,
                                                          RKTIO_NULLABLE rktio_addrinfo_t *addr);
/* The `addr` argument can be NULL to auto-select the interface. */

RKTIO_EXTERN rktio_ok_t rktio_udp_change_multicast_group(rktio_t *rktio, rktio_fd_t *rfd,
                                                         rktio_addrinfo_t *group_addr,
                                                         RKTIO_NULLABLE rktio_addrinfo_t *intf_addr,
                                                         int action);
/* `action` values: */
enum {
  RKTIO_ADD_MEMBERSHIP,
  RKTIO_DROP_MEMBERSHIP
};

RKTIO_EXTERN char **rktio_socket_address(rktio_t *rktio, rktio_fd_t *rfd);
RKTIO_EXTERN char **rktio_socket_peer_address(rktio_t *rktio, rktio_fd_t *rfd);
RKTIO_EXTERN char **rktio_listener_address(rktio_t *rktio, rktio_listener_t *lnr);
/* These return two strings in an array (where the array itself should
   be deallocated): address and service. */

/*************************************************/
/* Environment variables                         */

RKTIO_EXTERN rktio_bool_t rktio_is_ok_envvar_name(rktio_t *rktio, rktio_const_string_t name);
/* Checks whether a string is valid as a new (e.g., no "="). */

RKTIO_EXTERN rktio_bool_t rktio_are_envvar_names_case_insensitive(rktio_t *rktio);
/* Checks whether environment variables are case-folded by the OS.
   That doesn't mean that clients need to case-fold names, but clients
   may want to imitate the OS. */

RKTIO_EXTERN char *rktio_getenv(rktio_t *rktio, rktio_const_string_t name);
/* Gets an environment variable value, or reports
   `RKTIO_ERROR_NO_SUCH_ENVVAR` when returning NULL; the result must
   be freed. */

RKTIO_EXTERN rktio_ok_t rktio_setenv(rktio_t *rktio, rktio_const_string_t name, rktio_const_string_t val);
/* Set an environment variable's value, where a NULL value for `val`
   unsets it. */

typedef struct rktio_envvars_t rktio_envvars_t;

RKTIO_EXTERN rktio_envvars_t *rktio_envvars(rktio_t *rktio);
/* Extracts all environment variables into a record */

RKTIO_EXTERN rktio_envvars_t *rktio_empty_envvars(rktio_t *rktio);
/* Create an empty environment-variables record. */

RKTIO_EXTERN rktio_envvars_t *rktio_envvars_copy(rktio_t *rktio, rktio_envvars_t *envvars);
/* Clones an environment-variable record. */

RKTIO_EXTERN void rktio_envvars_free(rktio_t *rktio, rktio_envvars_t *envvars);
/* Deallocates an environment-variables record: */

RKTIO_EXTERN char *rktio_envvars_get(rktio_t *rktio, rktio_envvars_t *envvars, rktio_const_string_t name);
RKTIO_EXTERN void rktio_envvars_set(rktio_t *rktio, rktio_envvars_t *envvars, rktio_const_string_t name, rktio_const_string_t value);
/* Access/update environment-variables record by name. */

RKTIO_EXTERN_NOERR intptr_t rktio_envvars_count(rktio_t *rktio, rktio_envvars_t *envvars);
RKTIO_EXTERN char *rktio_envvars_name_ref(rktio_t *rktio, rktio_envvars_t *envvars, intptr_t i);
RKTIO_EXTERN char *rktio_envvars_value_ref(rktio_t *rktio, rktio_envvars_t *envvars, intptr_t i);
/* Access/update environment-variables record by index. */

/*************************************************/
/* Processes                                     */

typedef struct rktio_process_t rktio_process_t;

typedef struct rktio_process_result_t {
  rktio_process_t *process;
  rktio_fd_t *stdin_fd;
  rktio_fd_t *stdout_fd;
  rktio_fd_t *stderr_fd;
} rktio_process_result_t;

RKTIO_EXTERN rktio_process_result_t *rktio_process(rktio_t *rktio,
                                                   rktio_const_string_t command, int argc, rktio_const_string_t *argv,
                                                   RKTIO_NULLABLE rktio_fd_t *stdout_fd,
                                                   RKTIO_NULLABLE rktio_fd_t *stdin_fd,
                                                   RKTIO_NULLABLE rktio_fd_t *stderr_fd,
                                                   RKTIO_NULLABLE rktio_process_t *group_proc,
                                                   rktio_const_string_t current_directory,
                                                   rktio_envvars_t *envvars,
                                                   int flags);
/* The output file descriptors `stdin_fd` must not be a pending-open
   descriptor. The `flags` are: */
#define RKTIO_PROCESS_NEW_GROUP                 (1<<0)
#define RKTIO_PROCESS_STDOUT_AS_STDERR          (1<<1)
#define RKTIO_PROCESS_WINDOWS_EXACT_CMDLINE     (1<<2)
#define RKTIO_PROCESS_WINDOWS_CHAIN_TERMINATION (1<<3)
#define RKTIO_PROCESS_NO_CLOSE_FDS              (1<<4)
#define RKTIO_PROCESS_NO_INHERIT_FDS            (1<<5)

RKTIO_EXTERN_NOERR int rktio_process_allowed_flags(rktio_t *rktio);
/* Reports the flags that are accepted by `rktio_process` on the
   current OS. */

RKTIO_EXTERN_NOERR int rktio_process_pid(rktio_t *rktio, rktio_process_t *sp);
/* Always succeeds, whether or not the process is still running, so
   the result is generally not meaningful if the process is not
   running. */

RKTIO_EXTERN rktio_ok_t rktio_process_kill(rktio_t *rktio, rktio_process_t *sp);
RKTIO_EXTERN rktio_ok_t rktio_process_interrupt(rktio_t *rktio, rktio_process_t *sp);
/* Interrupts or kills a process; does not deallocate the process record. */

RKTIO_EXTERN void rktio_process_forget(rktio_t *rktio, rktio_process_t *sp);
/* Deallocates a process record, whether or not the process has
   stopped. */

RKTIO_EXTERN_ERR(RKTIO_PROCESS_ERROR)
rktio_tri_t rktio_poll_process_done(rktio_t *rktio, rktio_process_t *sp);
/* Check whether a process has completed: */
#define RKTIO_PROCESS_ERROR    (-2)
#define RKTIO_PROCESS_DONE     1
#define RKTIO_PROCESS_RUNNING  0

typedef struct rktio_status_t {
  rktio_bool_t running;
  int result;
} rktio_status_t;

RKTIO_EXTERN rktio_status_t *rktio_process_status(rktio_t *rktio, rktio_process_t *sp);
/* The `result` value is only value if `running` is 0. */

RKTIO_EXTERN void rktio_reap_processes(rktio_t *rktio);
/* If you start processes, calling this periodically may ensure that
   resources are released sooner rather than later. */

/*************************************************/
/* Filesystem-change events                      */

RKTIO_EXTERN_NOERR int rktio_fs_change_properties(rktio_t *rktio);
/* Reports properties of the filesystem-change event implementation: */
#define RKTIO_FS_CHANGE_SUPPORTED   (1 << 0)
#define RKTIO_FS_CHANGE_SCALABLE    (1 << 1)
#define RKTIO_FS_CHANGE_LOW_LATENCY (1 << 2)
#define RKTIO_FS_CHANGE_FILE_LEVEL  (1 << 3)
#define RKTIO_FS_CHANGE_NEED_LTPS   (1 << 4)

typedef struct rktio_fs_change_t rktio_fs_change_t;
struct rktio_ltps_t; /* forward reference */

RKTIO_EXTERN rktio_fs_change_t *rktio_fs_change(rktio_t *rktio, rktio_const_string_t path,
                                                struct rktio_ltps_t *ltps);
/* Creates a filesystem-change tracker that reports changes in `path`
   after creation of the tracker. The properties reported by
   `rktio_fs_change_properties` report various aspects of how the
   tracker behaves. In particular, the `ltps` argument can be NULL
   unless the `RKTIO_FS_CHANGE_NEED_LTPS` property is reported; if
   `lt` is provided, then the tracker must be canceled or discovered
   ready before `ltps` is closed. */

RKTIO_EXTERN void rktio_fs_change_forget(rktio_t *rktio, rktio_fs_change_t *fc);

RKTIO_EXTERN_ERR(RKTIO_POLL_ERROR)
rktio_tri_t rktio_poll_fs_change_ready(rktio_t *rktio, rktio_fs_change_t *fc);
/* Returns one of `RKTIO_POLL_READY`, etc. */

/*************************************************/
/* File-descriptor sets for polling              */

/* A poll set works for a single use via `rktio_sleep`, as opposed to
   "long-term" poll sets that can be used multiple times. The
   `rktio_sleep` function accepts one of each and combines them. */

typedef struct rktio_poll_set_t rktio_poll_set_t;

RKTIO_EXTERN rktio_poll_set_t *rktio_make_poll_set(rktio_t *rktio);
RKTIO_EXTERN void rktio_poll_set_forget(rktio_t *rktio, rktio_poll_set_t *fds);
/* Don't reuse a poll set after calling `rktio_sleep`, but do
   explicitly forget it afterward. */

RKTIO_EXTERN void rktio_poll_add(rktio_t *rktio, rktio_fd_t *rfd, rktio_poll_set_t *fds, int modes);
/* Registers a wait on a file descriptor in read and/or write mode or
   flush mode. The flush mode corresponds to
   `rktio_poll_write_flushed`.
   `modes` values: */
#define RKTIO_POLL_READ   RKTIO_OPEN_READ
#define RKTIO_POLL_WRITE  RKTIO_OPEN_WRITE
#define RKTIO_POLL_FLUSH  (RKTIO_OPEN_WRITE << 2)

RKTIO_EXTERN void rktio_poll_add_accept(rktio_t *rktio, rktio_listener_t *listener, rktio_poll_set_t *fds);
RKTIO_EXTERN void rktio_poll_add_connect(rktio_t *rktio, rktio_connect_t *conn, rktio_poll_set_t *fds);
RKTIO_EXTERN void rktio_poll_add_addrinfo_lookup(rktio_t *rktio, rktio_addrinfo_lookup_t *lookup, rktio_poll_set_t *fds);
RKTIO_EXTERN void rktio_poll_add_process(rktio_t *rktio, rktio_process_t *sp, rktio_poll_set_t *fds);
RKTIO_EXTERN void rktio_poll_add_fs_change(rktio_t *rktio, rktio_fs_change_t *fc, rktio_poll_set_t *fds);
/* Registers various other waits. */

RKTIO_EXTERN void rktio_poll_set_add_nosleep(rktio_t *rktio, rktio_poll_set_t *fds);
/* Causes a sleep given `fds` to return immediately. */

RKTIO_EXTERN void rktio_poll_set_add_handle(rktio_t *rktio, intptr_t h, rktio_poll_set_t *fds, int repost);
RKTIO_EXTERN void rktio_poll_set_add_eventmask(rktio_t *rktio, rktio_poll_set_t *fds, int mask);
/* When sleeping on Windows, extra handles or eventmasks can be added
   to trigger a wake up. The functions do nothing  on other platforms. */

RKTIO_EXTERN void rkio_reset_sleep_backoff(rktio_t *rktio);
/* Call this function when using `rktio_poll_set_add_eventmask` and
   when matching events are not always consumed from the queue between
   sleeps. To accommodate messages that are not consumed, the poll set
   will actually only sleep a short while at first, and then back off
   exponentially. Call this function when your program does useful
   work (instead of spinning on sleep) to reset the backoff
   counter. */

/*************************************************/
/* Long-term poll sets                           */

/* "Long-term" means that the poll set will be used frequently with
   incremental updates, which means that it's worthwhile to use an OS
   facility (epoll, kqueue, etc.) to speed up polling. */

typedef struct rktio_ltps_t rktio_ltps_t;
typedef struct rktio_ltps_handle_t rktio_ltps_handle_t;

RKTIO_EXTERN rktio_ltps_t *rktio_ltps_open(rktio_t *rktio);

RKTIO_EXTERN void rktio_ltps_close(rktio_t *rktio, rktio_ltps_t *lt);
/* Closing will signal all remaining handles and free all signaled
   handles, but use `rktio_ltps_remove_all` and
   `rktio_ltps_get_signaled_handle` is you need to clean up any
   per-handle data: */

RKTIO_EXTERN rktio_ltps_handle_t *rktio_ltps_add(rktio_t *rktio, rktio_ltps_t *lt, rktio_fd_t *rfd, int mode);
/* Don't free the returned handle; use it with `rktio_ltps_handle_set_data`
   and `rktio_ltps_handle_get_data`, and free it only when the same handle
   is returned by `rktio_ltps_get_signaled_handle`. Using the `RKTIO_LTPS_REMOVE`
   mode causes a previous created handle to be signaled. A successful remove
   reports `RKTIO_ERROR_LTPS_REMOVED` while returning NULL. A `...CHECK...`
   or `...REMOVE...` mode that doesn't find the handle reports
   `RKTIO_ERROR_LTPS_NOT_FOUND`.
   `mode` values: */
enum {
  RKTIO_LTPS_CREATE_READ = 1,
  RKTIO_LTPS_CREATE_WRITE,
  RKTIO_LTPS_CHECK_READ,
  RKTIO_LTPS_CHECK_WRITE,
  RKTIO_LTPS_REMOVE,
  /* Internal, for filesystem-change events with kqueue: */
  RKTIO_LTPS_CREATE_VNODE,
  RKTIO_LTPS_CHECK_VNODE,
  RKTIO_LTPS_REMOVE_VNODE
};

RKTIO_EXTERN void rktio_ltps_handle_set_data(rktio_t *rktio, rktio_ltps_handle_t *h, void *data);
RKTIO_EXTERN_NOERR void *rktio_ltps_handle_get_data(rktio_t *rktio, rktio_ltps_handle_t *h);

RKTIO_EXTERN void rktio_ltps_remove_all(rktio_t *rktio, rktio_ltps_t *lt);
/* Removes all additions, signaling all handles. */

RKTIO_EXTERN rktio_ok_t rktio_ltps_poll(rktio_t *rktio, rktio_ltps_t *lt);
/* Enqueues signaled handles for retrieval via `rktio_ltps_get_signaled_handle`.  */

RKTIO_EXTERN rktio_ltps_handle_t *rktio_ltps_get_signaled_handle(rktio_t *rktio, rktio_ltps_t *lt);
/* Free the returned handle when you're done with it. */

RKTIO_EXTERN void rktio_ltps_handle_set_auto(rktio_t *rktio, rktio_ltps_handle_t *lth, int auto_mode);
/* An alternative to receiving the handle via `rktio_ltps_get_signaled_handle`;
   have signaling automatically either zero the handle content (so the
   client can detect signaling) or free the handle (because the client
   is no longer watching it). If `auto_mode` is `RKTIO_LTPS_HANDLE_NONE`,
   automatic handling is disabled for the handle. */
/* `auto_mode` values: */
enum {
  RKTIO_LTPS_HANDLE_NONE,
  RKTIO_LTPS_HANDLE_ZERO,
  RKTIO_LTPS_HANDLE_FREE
};

RKTIO_EXTERN RKTIO_BLOCKING void rktio_sleep(rktio_t *rktio, float nsecs, rktio_poll_set_t *fds, rktio_ltps_t *lt);
/* Waits up to `nsecs` seconds (or forever if `nsecs` is 0), until
   something registered with `fds` or `lt` is ready, or until there's
   some other activity that sometimes causes an early wakeup. */

/*************************************************/
/* Sleeping in a background thread               */

RKTIO_EXTERN rktio_ok_t rktio_start_sleep(rktio_t *rktio, float nsecs, rktio_poll_set_t *fds, rktio_ltps_t *lt,
                                          int woke_fd);
/* Like `rktio_sleep`, but starts a sleep in a background thread. When the
   background thread is done sleeping, it writes a byte to `woke_fd`, but the
   background thread can be woken up with `rktio_end_sleep`. */

RKTIO_EXTERN void rktio_end_sleep(rktio_t *rktio);
/* Ends a background sleep started with `rktio_sleep`. Call this
   function exactly once for each successful `rktio_start_sleep`,
   whether or not the background thread write to `woke_fd` already. */

/*************************************************/
/* Files, directories, and links                 */

RKTIO_EXTERN rktio_bool_t rktio_file_exists(rktio_t *rktio, rktio_const_string_t filename);
RKTIO_EXTERN rktio_bool_t rktio_directory_exists(rktio_t *rktio, rktio_const_string_t dirname);
RKTIO_EXTERN rktio_bool_t rktio_link_exists(rktio_t *rktio, rktio_const_string_t filename);
RKTIO_EXTERN rktio_bool_t rktio_is_regular_file(rktio_t *rktio, rktio_const_string_t filename);
/* On Windows, check for special filenames (like "aux") before calling
   the `rktio_file_exists` or `rktio_is_regular_file`. */

#define RKTIO_FILE_TYPE_FILE           1
#define RKTIO_FILE_TYPE_DIRECTORY      2
#define RKTIO_FILE_TYPE_LINK           3
#define RKTIO_FILE_TYPE_DIRECTORY_LINK 4

#define RKTIO_FILE_TYPE_ERROR  (-1)

RKTIO_EXTERN_ERR(RKTIO_FILE_TYPE_ERROR)
int rktio_file_type(rktio_t *rktio, rktio_const_string_t filename);
/* Result is `RKTIO_FILE_TYPE_ERROR` for error, otherwise one of
   the `RKTIO_FILE_TYPE_...` values. On Windows, check for special
   filenames (like "aux") before calling this function. */

RKTIO_EXTERN rktio_ok_t rktio_delete_file(rktio_t *rktio, rktio_const_string_t fn, rktio_bool_t enable_write_on_fail);

RKTIO_EXTERN rktio_ok_t rktio_rename_file(rktio_t *rktio, rktio_const_string_t dest, rktio_const_string_t src, rktio_bool_t exists_ok);
/* Can report `RKTIO_ERROR_EXISTS`. */

RKTIO_EXTERN char *rktio_get_current_directory(rktio_t *rktio);
RKTIO_EXTERN rktio_ok_t rktio_set_current_directory(rktio_t *rktio, rktio_const_string_t path);

RKTIO_EXTERN rktio_ok_t rktio_make_directory(rktio_t *rktio, rktio_const_string_t filename);
/* Can report `RKTIO_ERROR_EXISTS`. */

RKTIO_EXTERN rktio_ok_t rktio_make_directory_with_permissions(rktio_t *rktio, rktio_const_string_t filename, int perm_bits);
/* Can report `RKTIO_ERROR_EXISTS`. */
#define RKTIO_DEFAULT_DIRECTORY_PERM_BITS 0777

RKTIO_EXTERN rktio_ok_t rktio_delete_directory(rktio_t *rktio, rktio_const_string_t filename, rktio_const_string_t current_directory,
                                               rktio_bool_t enable_write_on_fail);
/* The `current_directory` argument is used on Windows to avoid being
   in `filename` (instead) as a directory while trying to delete it.
   The `enable_write_on_fail` argument also applied to Windows. */

RKTIO_EXTERN char *rktio_readlink(rktio_t *rktio, rktio_const_string_t fullfilename);
/* Argument should not have a trailing separator. Can report
   `RKTIO_ERROR_NOT_A_LINK`. */

RKTIO_EXTERN rktio_ok_t rktio_make_link(rktio_t *rktio, rktio_const_string_t src, rktio_const_string_t dest,
                                        rktio_bool_t dest_is_directory);
/* The `dest_is_directory` argument is used only
   on Windows. Can report `RKTIO_ERROR_EXISTS`. */

/*************************************************/
/* File attributes                               */

typedef intptr_t rktio_timestamp_t;

RKTIO_EXTERN rktio_filesize_t *rktio_file_size(rktio_t *rktio, rktio_const_string_t filename);

RKTIO_EXTERN rktio_timestamp_t *rktio_get_file_modify_seconds(rktio_t *rktio, rktio_const_string_t file);
RKTIO_EXTERN rktio_ok_t rktio_set_file_modify_seconds(rktio_t *rktio, rktio_const_string_t file, rktio_timestamp_t secs);

typedef struct rktio_stat_t {
  /* Eventually, this should use `int64_t`, available in C99 and up */
  uintptr_t device_id, inode, mode, hardlink_count, user_id, group_id,
            device_id_for_special_file, size, block_size, block_count,
            access_time_seconds, access_time_nanoseconds,
            modify_time_seconds, modify_time_nanoseconds,
            ctime_seconds, ctime_nanoseconds;
  /* The `st_ctime` field is status change time for Posix and creation time
     for Windows. */
  rktio_bool_t ctime_is_change_time;
} rktio_stat_t;

RKTIO_EXTERN rktio_stat_t *rktio_file_or_directory_stat(rktio_t *rktio, rktio_const_string_t path, rktio_bool_t follow_links);

typedef struct rktio_identity_t {
  uintptr_t a, b, c;
  int a_bits, b_bits, c_bits; /* size of each in bits */
} rktio_identity_t;

RKTIO_EXTERN rktio_identity_t *rktio_fd_identity(rktio_t *rktio, rktio_fd_t *fd);
RKTIO_EXTERN rktio_identity_t *rktio_path_identity(rktio_t *rktio, rktio_const_string_t path, rktio_bool_t follow_links);

/*************************************************/
/* Permissions                                   */

/* Should match OS bits: */
#define RKTIO_PERMISSION_READ  0x4
#define RKTIO_PERMISSION_WRITE 0x2
#define RKTIO_PERMISSION_EXEC  0x1

#define RKTIO_PERMISSION_ERROR (-1)

RKTIO_EXTERN_ERR(RKTIO_PERMISSION_ERROR)
int rktio_get_file_or_directory_permissions(rktio_t *rktio, rktio_const_string_t filename, rktio_bool_t all_bits);
/* Result is `RKTIO_PERMISSION_ERROR` for error, otherwise a combination of
   bits. If not `all_bits`, then use constants above. */

RKTIO_EXTERN rktio_ok_t rktio_set_file_or_directory_permissions(rktio_t *rktio, rktio_const_string_t filename, int new_bits);
/* The `new_bits` format corresponds to `all_bits` for getting permissions.
   Can report `RKTIO_ERROR_BAD_PERMISSION` for bits that make no sense. */

/*************************************************/
/* Directory listing                             */

typedef struct rktio_directory_list_t rktio_directory_list_t;

RKTIO_EXTERN rktio_directory_list_t *rktio_directory_list_start(rktio_t *rktio, rktio_const_string_t dirname);
/* On Windows, the given `dirname` must be normalized and not have
   `.` or `..`: */

RKTIO_EXTERN char *rktio_directory_list_step(rktio_t *rktio, rktio_directory_list_t *dl);
/* Returns an unallocated "" and deallocates `dl` when the iteration
   is complete. A NULL result would mean an error without deallocating
   `dl`, but that doesn't currently happen. */

RKTIO_EXTERN void rktio_directory_list_stop(rktio_t *rktio, rktio_directory_list_t *dl);
/* Interrupt a directory list in progress, not needed after
   `rktio_directory_list_step` returns "": */

RKTIO_EXTERN char **rktio_filesystem_roots(rktio_t *rktio);
/* Returns a NULL-terminated array. Free each string. Currently never
   errors. */

/*************************************************/
/* File copying                                  */

typedef struct rktio_file_copy_t rktio_file_copy_t;

RKTIO_EXTERN_STEP rktio_file_copy_t *rktio_copy_file_start(rktio_t *rktio, rktio_const_string_t dest, rktio_const_string_t src,
                                                           rktio_bool_t exists_ok);
/* Starts a file copy. Depending on the OS, this step may perform the
   whole copy, or it may just get started. Can report
   `RKTIO_ERROR_EXISTS`, and sets an error step as listed further below. */

RKTIO_EXTERN_STEP rktio_file_copy_t *rktio_copy_file_start_permissions(rktio_t *rktio, rktio_const_string_t dest, rktio_const_string_t src,
                                                                       rktio_bool_t exists_ok,
                                                                       rktio_bool_t use_perm_bits, int perm_bits,
                                                                       rktio_bool_t override_create_perms);
/* Like `rktio_copy_file_start`, but accepts optional permissions to
   apply to the copy, which are used only if `use_perm_bits` is set
   (otherwise the source file's permissions are kept) and whether on
   Unix to for the destination file's permissions as possibly modified
   by `umask` on file create (whether supplied or taken from the `src`
   file) or because the file already exists. */

RKTIO_EXTERN rktio_bool_t rktio_copy_file_is_done(rktio_t *rktio, rktio_file_copy_t *fc);
RKTIO_EXTERN_STEP rktio_ok_t rktio_copy_file_step(rktio_t *rktio, rktio_file_copy_t *fc);
/* As long as the copy isn't done, call `rktio_copy_file_step` to make
   a little progress. Use `rktio_copy_file_finish_permissions`
   (optionally) and then `rktio_copy_file_stop` when done. An error
   sets an error step as listed further below. */

RKTIO_EXTERN_STEP rktio_ok_t rktio_copy_file_finish_permissions(rktio_t *rktio, rktio_file_copy_t *fc);
/* Depending on the OS, copies permissions from the source to the
   destination. This step can be performed at any time between the
   start and stop. Reports success if this step isn't needed (e.g.,
   where a copy fully completes when it is started). On error, the
   step is set to `RKTIO_COPY_STEP_WRITE_DEST_METADATA`. */

RKTIO_EXTERN void rktio_copy_file_stop(rktio_t *rktio, rktio_file_copy_t *fc);
/* Deallocates the copy process, interrupting it if the copy is not
   complete. */

/* Step values for errors from `rktio_copy_file_start` and
   `rktio_copy_file_step`: */
enum {
  RKTIO_COPY_STEP_UNKNOWN,
  RKTIO_COPY_STEP_OPEN_SRC,
  RKTIO_COPY_STEP_OPEN_DEST,
  RKTIO_COPY_STEP_READ_SRC_DATA,
  RKTIO_COPY_STEP_WRITE_DEST_DATA,
  RKTIO_COPY_STEP_READ_SRC_METADATA,
  RKTIO_COPY_STEP_WRITE_DEST_METADATA
};

/*************************************************/
/* System paths                                  */

RKTIO_EXTERN char *rktio_system_path(rktio_t *rktio, int which);
/* `which` values: */
enum {
  RKTIO_PATH_SYS_DIR,
  RKTIO_PATH_TEMP_DIR,
  RKTIO_PATH_PREF_DIR,
  RKTIO_PATH_PREF_FILE,
  RKTIO_PATH_ADDON_DIR,
  RKTIO_PATH_HOME_DIR,
  RKTIO_PATH_DESK_DIR,
  RKTIO_PATH_DOC_DIR,
  RKTIO_PATH_INIT_DIR,
  RKTIO_PATH_INIT_FILE,
  RKTIO_PATH_CACHE_DIR
};

RKTIO_EXTERN char *rktio_expand_user_tilde(rktio_t *rktio, rktio_const_string_t filename);
/* Path must start with tilde, otherwise `RKTIO_ERROR_NO_TILDE`.
   Other possible errors are `RKTIO_ERROR_ILL_FORMED_USER` and
   `RKTIO_ERROR_UNKNOWN_USER`. */

RKTIO_EXTERN_NOERR char *rktio_uname(rktio_t *rktio);
/* Returns a string describing the current machine and installation,
   similar to the return of `uname -a` on Unix. If machine information
   cannot be obtained for some reason, the result is a copy of
   "<unknown machine>". */

/*************************************************/
/* Sleep and signals                             */

typedef struct rktio_signal_handle_t rktio_signal_handle_t;
/* A `rktio_signal_handle_t` is a value specific to a `rktio_t` that
   causes any `rktio_sleep` for that `rktio_t` to return (or causes
   the next `rktio_sleep` to return if one is not in progress. */

RKTIO_EXTERN_NOERR rktio_signal_handle_t *rktio_get_signal_handle(rktio_t *rktio);
/* Gets the handle for the given `rktio_t`. */

RKTIO_EXTERN void rktio_signal_received_at(rktio_signal_handle_t *h);
/* Signals the given handle. This function can be called from any
   thread or from signal handlers. */

RKTIO_EXTERN void rktio_signal_received(rktio_t *rktio);
/* A shorthand for `rktio_signal_received_at` composed with
   `rktio_get_signal_handle`. */

RKTIO_EXTERN void rktio_wait_until_signal_received(rktio_t *rktio);
/* The same as `rktio_sleep` with no timeout, no poll set, and no
   long-term poll set. */

RKTIO_EXTERN void rktio_flush_signals_received(rktio_t *rktio);
/* Clears any pending signal so that it doesn't interrupt the next
   `rktio_sleep`. */

RKTIO_EXTERN void rktio_install_os_signal_handler(rktio_t *rktio);
/* Installs OS-level handlers for SIGINT, SIGTERM, and SIGHUP (or
   Ctl-C on Windows) to signal the handle of `rktio` and also records
   the signal for reporting via `rktio_poll_os_signal`. Only one
   `rktio` can be registered this way at a time. This function must
   not be called in two threads at the same time; more generally, it
   can only be called when `rktio_will_modify_os_signal_handler`
   can be called for SIGINT, etc. */

RKTIO_EXTERN_NOERR int rktio_poll_os_signal(rktio_t *rktio);
/* Returns one of the following, not counting the last one: */
#define RKTIO_OS_SIGNAL_NONE (-1)
enum {
  RKTIO_OS_SIGNAL_INT,
  RKTIO_OS_SIGNAL_TERM,
  RKTIO_OS_SIGNAL_HUP,
  RKTIO_NUM_OS_SIGNALS
};

RKTIO_EXTERN void rktio_will_modify_os_signal_handler(int sig_id);
/* Registers with rktio that an operating-system signal handler is
   about to be modified within the process but outside of rktio, where
   `sig_id` is a signal identifier --- such as SIGINT or SIGTERM. This
   notification allows rktio to record the current signal disposition
   so that it can be restored after forking a new Unix process. Signal
   registrations should happen only before multiple threads use rktio,
   and registration of the signal can happen before any `rktio_init`
   call. After a signal is registered, trying to re-register it after
   threads start is harmless. */

/*************************************************/
/* Time and date                                 */

typedef struct rktio_date_t {
  int nanosecond, second, minute, hour, day, month;
  intptr_t year;
  int day_of_week;
  int day_of_year;
  int is_dst;
  int zone_offset;
  char *zone_name; /* can be NULL; otherwise, free it */
} rktio_date_t;

RKTIO_EXTERN_NOERR uintptr_t rktio_get_milliseconds(void);
/* Wll-clock time. Overflow may cause the result to wrap around to 0,
   at least on a 32-bit platform. */

RKTIO_EXTERN_NOERR double rktio_get_inexact_milliseconds(void);
/* Wall-clock time. No overflow, but won't strictly increase if the
   system clock is reset. */

RKTIO_EXTERN_NOERR double rktio_get_inexact_monotonic_milliseconds(rktio_t *rktio);
/* Real time like wall-clock time, but will strictly increase,
   assuming that the host system provides a monotonic clock. */

RKTIO_EXTERN_NOERR uintptr_t rktio_get_process_milliseconds(rktio_t *rktio);
RKTIO_EXTERN_NOERR uintptr_t rktio_get_process_children_milliseconds(rktio_t *rktio);
/* CPU time across all threads withing the process. Overflow may cause
   the result to wrap around to 0, at least on a 32-bit platform. */

RKTIO_EXTERN_NOERR rktio_timestamp_t rktio_get_seconds(rktio_t *rktio);
RKTIO_EXTERN rktio_date_t *rktio_seconds_to_date(rktio_t *rktio, rktio_timestamp_t seconds, int nanoseconds, int get_gmt);
/* A timestamp can be negative to represent a date before 1970. */

/*************************************************/
/* Windows ShellExecute                          */

enum {
  RKTIO_SW_HIDE,
  RKTIO_SW_MAXIMIZE,
  RKTIO_SW_MINIMIZE,
  RKTIO_SW_RESTORE,
  RKTIO_SW_SHOW,
  RKTIO_SW_SHOWDEFAULT,
  RKTIO_SW_SHOWMAXIMIZED,
  RKTIO_SW_SHOWMINIMIZED,
  RKTIO_SW_SHOWMINNOACTIVE,
  RKTIO_SW_SHOWNA,
  RKTIO_SW_SHOWNOACTIVATE,
  RKTIO_SW_SHOWNORMAL
};

RKTIO_EXTERN RKTIO_MSG_QUEUE rktio_ok_t rktio_shell_execute(rktio_t *rktio,
                                                            rktio_const_string_t verb,
                                                            rktio_const_string_t target,
                                                            rktio_const_string_t arg,
                                                            rktio_const_string_t dir,
                                                            int show_mode);
/* Supported only on Windows to run `ShellExecute`. The `dir` argument
   needs to have normalized path separators. */

/*************************************************/
/* Path conversion                               */

RKTIO_EXTERN rktio_char16_t *rktio_path_to_wide_path(rktio_t *rktio, rktio_const_string_t p);
RKTIO_EXTERN_NOERR char *rktio_wide_path_to_path(rktio_t *rktio, const rktio_char16_t *wp);
/* Convert to/from the OS's native path representation. These
   functions are useful only on Windows. The `rktio_path_to_wide_path`
   function can fail and report `RKTIO_ERROR_INVALID_PATH`. */

/*************************************************/
/* Processor count                               */

RKTIO_EXTERN_NOERR int rktio_processor_count(rktio_t *rktio);
/* Returns the number of processing units, either as CPUs, cores, or
   hyperthreads. */

/*************************************************/
/* Logging                                       */

RKTIO_EXTERN rktio_ok_t rktio_syslog(rktio_t *rktio, int level, rktio_const_string_t name, rktio_const_string_t msg,
                                     rktio_const_string_t exec_name);
/* Adds a message to the system log. The `name` argument can be NULL,
   and it is added to the front of the message with a separating ": "
   if non_NULL. The `exec_name` is the current executable name; it's
   currently, used only on Windows, and the value may matter only the
   first time that `rktio_syslog` is called. */
/* `level` values: */
enum {
  RKTIO_LOG_FATAL = 1,
  RKTIO_LOG_ERROR,
  RKTIO_LOG_WARNING,
  RKTIO_LOG_INFO,
  RKTIO_LOG_DEBUG
};

/*************************************************/
/* Encoding conversion                           */

RKTIO_EXTERN_NOERR int rktio_convert_properties(rktio_t *rktio);
/* Returns a combination of the following flags. */

#define RKTIO_CONVERTER_SUPPORTED   (1 << 0)
#define RKTIO_CONVERT_STRCOLL_UTF16 (1 << 1)
#define RKTIO_CONVERT_RECASE_UTF16  (1 << 2)

typedef struct rktio_converter_t rktio_converter_t;

RKTIO_EXTERN rktio_converter_t *rktio_converter_open(rktio_t *rktio, rktio_const_string_t to_enc, rktio_const_string_t from_enc);
/* Creates an encoding converter. */

RKTIO_EXTERN void rktio_converter_close(rktio_t *rktio, rktio_converter_t *cvt);
/* Destroys an encoding converter. */

RKTIO_EXTERN_ERR(RKTIO_CONVERT_ERROR)
intptr_t rktio_convert(rktio_t *rktio,
                       rktio_converter_t *cvt,
                       char **in, intptr_t *in_left,
                       char **out, intptr_t *out_left);
/* Converts some bytes, following the iconv protocol: each consumed by
   increments `*in` and decrements `*in_left`, and each produced by
   increments `*out` and decrements `*out_left`. In case of an error,
   the result is `RKTIO_CONVERT_ERROR` and the last error is set to
   one of `RKTIO_ERROR_CONVERT_NOT_ENOUGH_SPACE`,
   `RKTIO_ERROR_CONVERT_BAD_SEQUENCE`, `RKTIO_ERROR_CONVERT_PREMATURE_END`,
   or `RKTIO_ERROR_CONVERT_OTHER` --- but an error indicates something within
   `in` or `out`, and some bytes may have been successfully converted even if
   an error is reported. */

#define RKTIO_CONVERT_ERROR (-1)

typedef struct rktio_convert_result_t {
  intptr_t in_consumed;  /* input bytes converted */
  intptr_t out_produced; /* output bytes produced */
  intptr_t converted;    /* characters converted, can be `RKTIO_CONVERT_ERROR` */
} rktio_convert_result_t;

RKTIO_EXTERN rktio_convert_result_t *rktio_convert_in(rktio_t *rktio,
                                                      rktio_converter_t *cvt,
                                                      char *in, intptr_t in_start, intptr_t in_end,
                                                      char *out, intptr_t out_start, intptr_t out_end);
/* The same as rktio_convert`, but accepting start and end positions
   and returning results as an allocated struct. A conversion error
   doesn't return a NULL result; instead, `converted` in the result
   reports the error. */

RKTIO_EXTERN void rktio_convert_reset(rktio_t *rktio, rktio_converter_t *cvt);
/* Resets a converter to its initial state. */

RKTIO_EXTERN_NOERR char *rktio_locale_recase(rktio_t *rktio,
                                             rktio_bool_t to_up,
                                             rktio_const_string_t in);
/* Upcases (of `to_up`) or downcases (if `!to_up`) the content of `in`
   using the current locale's encoding and case conversion. */

RKTIO_EXTERN_NOERR rktio_char16_t *rktio_recase_utf16(rktio_t *rktio,
                                                      rktio_bool_t to_up, rktio_char16_t *s1,
                                                      intptr_t len, intptr_t *olen);
/* Converts the case of a string encoded in UTF-16 for the system's
   default locale if the OS provided direct support for it. The
   `RKTIO_CONVERT_RECASE_UTF16 property from
   `rktio_convert_properties` reports whether this function will work.
   Takes and optionally returns a length (`olen` can be NULL), but the
   UTF-16 sequence is expected to have no nuls. */

RKTIO_EXTERN_NOERR int rktio_locale_strcoll(rktio_t *rktio, rktio_const_string_t s1, rktio_const_string_t s2);
/* Returns -1 if `s1` is less than `s2` by the current locale's
   comparison, positive is `s1` is greater, and 0 if the strings
   are equal. */

RKTIO_EXTERN_NOERR int rktio_strcoll_utf16(rktio_t *rktio,
                                           rktio_char16_t *s1, intptr_t l1,
                                           rktio_char16_t *s2, intptr_t l2,
                                           rktio_bool_t cvt_case);
/* Compares two strings encoded in UTF-16 for the system's default
   locale if the OS provided direct support for it. The
   `RKTIO_CONVERT_STRCOLL_UTF16 property from
   `rktio_convert_properties` reports whether this function will work.
   Takes lengths, but the UTF-16 sequences are expected to have
   no include nuls. */

RKTIO_EXTERN char *rktio_locale_encoding(rktio_t *rktio);
/* Returns the name of the current locale's encoding. */

RKTIO_EXTERN void rktio_set_locale(rktio_t *rktio, rktio_const_string_t name);
/* Sets the current locale, which affects rktio string comparisons and
   conversions. It can also affect the C library's character-property
   predicates and number printing/parsing by setting a thread-local or
   process-wide locale, but that effect is not guaranteed. The empty
   string corresponds to the OS's native locale, and a NULL string
   pointer corresponds to the C locale. */

RKTIO_EXTERN void rktio_set_default_locale(rktio_const_string_t name);
/* Similar to rktio_set_locale(), but sets the locale process-wide. */

RKTIO_EXTERN_NOERR void *rktio_push_c_numeric_locale(rktio_t *rktio);
RKTIO_EXTERN void rktio_pop_c_numeric_locale(rktio_t *rktio, void *prev);
/* Use this pair of functions to temporarily switch the locale to the
   C locale for number parsing and printing. Unlike
   rktio_set_locale(), these functions set and restore the
   thread-local or even process-wide locale. The result of the first
   function is deallocated when passed to second function. */

RKTIO_EXTERN char *rktio_system_language_country(rktio_t *rktio);
/* Returns the current system's language in country in a 5-character
   format such as "en_US". */


/*************************************************/
/* SHA-1, SHA-224, SHA-256                       */

/* From Steve Reid's implementation at https://www.ghostscript.com/ */

typedef struct rktio_sha1_ctx_t {
  unsigned int state[5];
  unsigned int count[2];
  unsigned char buffer[64];
} rktio_sha1_ctx_t;

#define RKTIO_SHA1_DIGEST_SIZE 20

RKTIO_EXTERN void rktio_sha1_init(rktio_sha1_ctx_t *context);
/* Initialize a context, which is memory of length `rktio_sha1_ctx_size()`
   containing no pointers. */

RKTIO_EXTERN void rktio_sha1_update(rktio_sha1_ctx_t *context,
                                    const unsigned char *data, intptr_t start, intptr_t end);
/* Add some bytes to the hash. */

RKTIO_EXTERN void rktio_sha1_final(rktio_sha1_ctx_t *context, unsigned char *digest /* RKTIO_SHA1_DIGEST_SIZE */);
/* Get the final hash value after all bytes have been added. */

typedef struct rktio_sha2_ctx_t {
    unsigned total[2];
    unsigned state[8];
    unsigned char buffer[64];
    int is224;
} rktio_sha2_ctx_t;

#define RKTIO_SHA224_DIGEST_SIZE 28
#define RKTIO_SHA256_DIGEST_SIZE 32

RKTIO_EXTERN void rktio_sha2_init(rktio_sha2_ctx_t *ctx, rktio_bool_t is224);
RKTIO_EXTERN void rktio_sha2_update(rktio_sha2_ctx_t *ctx,
                                    const unsigned char *data, intptr_t start, intptr_t end);
RKTIO_EXTERN void rktio_sha2_final(rktio_sha2_ctx_t *ctx, unsigned char *digest /* RKTIO_SHA2{24,56}_DIGEST_SIZE */);

/*************************************************/
/* Dynamically loaded libraries                  */

typedef struct rktio_dll_t rktio_dll_t;

RKTIO_EXTERN rktio_dll_t *rktio_dll_open(rktio_t *rktio, rktio_const_string_t name, rktio_bool_t as_global);
/* Loads a DLL using system-provided functions and search rules, such
   as dlopen() and its rules. If `as_global` is true, then the library
   is loaded in "global" mode, which has implications for other
   libraries trying to find bindings and for searching within the
   specific library for a binding. The `name` argument can be NULL
   to mean "the current executable".

   Some system error-reporting protocols do not fit nicely into the
   normal rktio error model. If the `RKTIO_ERROR_DLL` error is
   reported, then rktio_dll_get_error() must be used before any other
   `rktio_dll_...` call to get an error string.

   If a DLL has been loaded with `name` already, the previous result
   is returned again, but with an internal reference count returned.
   The `as_global` argument matters only for the first load of a DLL
   through a given `name`.

   Unless the DLL is explicitly unloaded with `rktio_dll_close`, even
   when the given `rktio` is closed with `rktio_destroy`, loaded
   libraries remain in the process. */

RKTIO_EXTERN void *rktio_dll_find_object(rktio_t *rktio, rktio_dll_t *dll, rktio_const_string_t name);
/* Find an address within `dll` for the `name` export.

   An error result can be `RKTIO_ERROR_DLL` as for `rktio_dll_open`. */

RKTIO_EXTERN rktio_ok_t rktio_dll_close(rktio_t *rktio, rktio_dll_t *dll);
/* Decrements the reference count on `dll`, and if it goes to zero,
   unloads the DLL using system-provided functions and destroys the
   `dll` argument.

   An error result can be `RKTIO_ERROR_DLL` as for `rktio_dll_open`. */

RKTIO_EXTERN char *rktio_dll_get_error(rktio_t *rktio);
/* Returns an error for a previous `rktio_dll_...` call, or NULL
   if no error string is available or has already been returned.
   See `rktio_dll_open` for more information. */

typedef void *(*dll_open_proc)(rktio_const_string_t name, rktio_bool_t as_global);
typedef void *(*dll_find_object_proc)(void *h, rktio_const_string_t name);
typedef void (*dll_close_proc)(void *h);
RKTIO_EXTERN void rktio_set_dll_procs(dll_open_proc dll_open,
                                      dll_find_object_proc dll_find_object,
                                      dll_close_proc dll_close);
/* Installs procedures that are tried before native mechanisms,
   currently only supported for Windows. */

/*************************************************/
/* Errors                                        */

RKTIO_EXTERN_NOERR int rktio_get_last_error_kind(rktio_t *rktio);

/* Kinds of error values: */
enum {
  RKTIO_ERROR_KIND_POSIX,
  RKTIO_ERROR_KIND_WINDOWS,
  RKTIO_ERROR_KIND_GAI,
  RKTIO_ERROR_KIND_RACKET
};

RKTIO_EXTERN_NOERR int rktio_get_last_error(rktio_t *rktio);

/* Error IDs of kind RKTIO_ERROR_KIND_RACKET */
enum {
  RKTIO_ERROR_UNSUPPORTED = 1,
  RKTIO_ERROR_INVALID_PATH, /* Windows path-decoding failure */
  RKTIO_ERROR_DOES_NOT_EXIST,
  RKTIO_ERROR_EXISTS,
  RKTIO_ERROR_ACCESS_DENIED,
  RKTIO_ERROR_LINK_FAILED,
  RKTIO_ERROR_NOT_A_LINK,
  RKTIO_ERROR_BAD_PERMISSION,
  RKTIO_ERROR_IS_A_DIRECTORY,
  RKTIO_ERROR_NOT_A_DIRECTORY,
  RKTIO_ERROR_UNSUPPORTED_TEXT_MODE,
  RKTIO_ERROR_CANNOT_FILE_POSITION,
  RKTIO_ERROR_NO_TILDE,
  RKTIO_ERROR_ILL_FORMED_USER,
  RKTIO_ERROR_UNKNOWN_USER,
  RKTIO_ERROR_INIT_FAILED,
  RKTIO_ERROR_LTPS_NOT_FOUND,
  RKTIO_ERROR_LTPS_REMOVED, /* indicates success, instead of failure */
  RKTIO_ERROR_CONNECT_TRYING_NEXT, /* indicates that failure is not (yet) permanent */
  RKTIO_ERROR_ACCEPT_NOT_READY,
  RKTIO_ERROR_HOST_AND_PORT_BOTH_UNSPECIFIED,
  RKTIO_ERROR_INFO_TRY_AGAIN, /* for UDP */
  RKTIO_ERROR_TRY_AGAIN, /* for UDP */
  RKTIO_ERROR_TRY_AGAIN_WITH_IPV4, /* for TCP listen */
  RKTIO_ERROR_TIME_OUT_OF_RANGE,
  RKTIO_ERROR_NO_SUCH_ENVVAR,
  RKTIO_ERROR_SHELL_EXECUTE_FAILED,
  RKTIO_ERROR_CONVERT_NOT_ENOUGH_SPACE,
  RKTIO_ERROR_CONVERT_BAD_SEQUENCE,
  RKTIO_ERROR_CONVERT_PREMATURE_END,
  RKTIO_ERROR_CONVERT_OTHER,
  RKTIO_ERROR_DLL, /* use `rktio_dll_get_error` atomically to get error */
};

RKTIO_EXTERN_NOERR int rktio_get_last_error_step(rktio_t *rktio);
/* Some operations report further information about the step that
   failed. The meaning of a step number is operation-specific. */

RKTIO_EXTERN void rktio_set_last_error(rktio_t *rktio, int kind, int errid);
RKTIO_EXTERN void rktio_set_last_error_step(rktio_t *rktio, int step);
/* In case you need to save and restore error information. */

RKTIO_EXTERN void rktio_remap_last_error(rktio_t *rktio);
/* In a few cases, rktio substitutes a `RKTIO_ERROR_KIND_RACKET` error
   for an OS-supplied error. This function can sometimes undo the
   substitition, modifying the current error and kind. */

RKTIO_EXTERN_NOERR const char *rktio_get_last_error_string(rktio_t *rktio);
RKTIO_EXTERN_NOERR const char *rktio_get_error_string(rktio_t *rktio, int kind, int errid);
/* The returned string for `rktio_...error_string` should not be
   deallocated, but it only lasts reliably until the next call to
   either of the functions. */

/*************************************************/

#endif
