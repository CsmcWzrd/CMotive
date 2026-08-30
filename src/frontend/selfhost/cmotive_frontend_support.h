#ifndef CMOTIVE_FRONTEND_SUPPORT_H
#define CMOTIVE_FRONTEND_SUPPORT_H

/*
 * Native ABI boundary for the self-hosted CMotive frontend.
 *
 * The compiler, preprocessor, code generator and command-line logic live in
 * CMotiveFrontend.CMOT.  This header is intentionally limited to C ABI type
 * declarations, varargs formatting, and small operating-system adapters that
 * CMotive cannot express portably yet.
 */

#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS 1
#endif
#if !defined(_WIN32) && !defined(_DEFAULT_SOURCE)
#define _DEFAULT_SOURCE 1
#endif
#if !defined(_WIN32) && !defined(_XOPEN_SOURCE)
#define _XOPEN_SOURCE 700
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>
#include <errno.h>
#include <time.h>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN 1
#endif
#ifndef NOMINMAX
#define NOMINMAX 1
#endif
#include <direct.h>
#include <process.h>
#include <windows.h>
#define strtok_r strtok_s
#define PATH_SEP '\\'
#else
#include <unistd.h>
#include <sys/wait.h>
#include <sys/stat.h>
#define PATH_SEP '/'
#endif

#define CMOTIVE_VERSION "0.3.0-selfhost"

/* Frontend data model.  Algorithms operating on these types are CMotive. */
typedef struct Str { char *s; size_t n, cap; } Str;
typedef struct StrVec { char **v; int n, cap; } StrVec;
typedef struct Macro { char *name, *value; } Macro;
typedef struct PPContext {
    StrVec include_dirs;
    StrVec seen;
    Macro *macros;
    int macro_n, macro_cap;
    char *root;
} PPContext;

typedef enum TokKind {
    TK_ID, TK_NUM, TK_STR, TK_CHAR, TK_OP, TK_EOL, TK_EOF
} TokKind;
typedef struct Tok { TokKind kind; char *v; int line, col; } Tok;
typedef struct TokVec { Tok *v; int n, cap; } TokVec;

typedef struct Param { char *name, *type; } Param;
typedef struct Field { char *name, *type, *init; int block; } Field;
typedef struct Func {
    char *name, *ret, *package, *method_of;
    Param *params;
    int param_n, param_cap;
    Tok *body;
    int body_n;
    int ctor, dtor, pure, fptr;
    char *op;
    char *hit_sender, *hit_id;
} Func;
typedef struct Class {
    char *name, *base, *package;
    Field *fields;
    int field_n, field_cap;
    Func *methods;
    int method_n, method_cap;
} Class;
typedef struct Global { char *name, *type, *init, *package; } Global;
typedef struct TemplateUse { char *base, *arg1, *arg2; } TemplateUse;
typedef struct Program {
    Class *classes;
    int class_n, class_cap;
    Func *funcs;
    int func_n, func_cap;
    Global *globals;
    int global_n, global_cap;
    Field *dyn_fields;
    int dyn_n, dyn_cap;
    char *dyn_name;
    TemplateUse *tuses;
    int tuse_n, tuse_cap;
    StrVec native_includes;
} Program;
typedef struct Parser { Tok *t; int n, i; Program *prog; char *package; } Parser;
typedef struct Var { char *name, *type; int pointer; } Var;
typedef struct VarTab { Var *v; int n, cap; } VarTab;
typedef struct BodyCtx {
    Program *prog;
    Class *curcls;
    Func *func;
    VarTab vars;
    Str *out;
    int indent;
} BodyCtx;
typedef struct Args {
    int compile_only, emit_c, keep_c;
    int print_linker, print_toolchain, print_arch, version;
    int debug;
    char *opt, *out, *target_arch;
    StrVec includes, libdirs, libs, inputs, objs, defs;
} Args;

/* CMotive currently has no varargs declaration syntax. */
static void sb_printf(Str *b, const char *fmt, ...)
{
    char stackbuf[4096];
    va_list ap;
    int n;
    size_t need;
    va_start(ap, fmt);
    n = vsnprintf(stackbuf, sizeof(stackbuf), fmt, ap);
    va_end(ap);
    if (n < 0) return;
    need = (size_t)n;
    if (b->n + need + 1u > b->cap) {
        size_t cap = b->cap ? b->cap : 1024u;
        while (b->n + need + 1u > cap) cap *= 2u;
        b->s = (char *)realloc(b->s, cap);
        if (!b->s) {
            fputs("cmotive: out of memory\n", stderr);
            exit(99);
        }
        b->cap = cap;
    }
    if (need < sizeof(stackbuf)) {
        memcpy(b->s + b->n, stackbuf, need);
    } else {
        char *tmp = (char *)malloc(need + 1u);
        if (!tmp) {
            fputs("cmotive: out of memory\n", stderr);
            exit(99);
        }
        va_start(ap, fmt);
        vsnprintf(tmp, need + 1u, fmt, ap);
        va_end(ap);
        memcpy(b->s + b->n, tmp, need);
        free(tmp);
    }
    b->n += need;
    b->s[b->n] = 0;
}

static int cmotive_native_mkdir(const char *path)
{
#if defined(_WIN32)
    return _mkdir(path);
#else
    return mkdir(path, 0777);
#endif
}

static void cmotive_native_getcwd(char *buf, size_t size)
{
#if defined(_WIN32)
    if (!_getcwd(buf, (int)size) && size) buf[0] = 0;
#else
    if (!getcwd(buf, size) && size) buf[0] = 0;
#endif
}

static int cmotive_native_os_matches(const char *upper_condition)
{
#if defined(_WIN32)
    return strstr(upper_condition, "WIN32") != NULL ||
           strstr(upper_condition, "WIN64") != NULL;
#elif defined(__APPLE__)
    return strstr(upper_condition, "MACOS") != NULL ||
           strstr(upper_condition, "UNIX") != NULL;
#elif defined(__linux__)
    return strstr(upper_condition, "LINUX") != NULL ||
           strstr(upper_condition, "UNIX") != NULL;
#else
    return strstr(upper_condition, "UNIX") != NULL;
#endif
}

static int cmotive_native_processor_matches(const char *upper_condition)
{
#if defined(__x86_64__) || defined(_M_X64)
    return strstr(upper_condition, "X64") != NULL ||
           strstr(upper_condition, "X86_64") != NULL;
#elif defined(__aarch64__) || defined(_M_ARM64)
    return strstr(upper_condition, "ARM64") != NULL ||
           strstr(upper_condition, "AARCH64") != NULL ||
           strstr(upper_condition, "ARM") != NULL;
#else
    (void)upper_condition;
    return 0;
#endif
}

static int cmotive_native_run_status(const char *cmd)
{
    int rc = system(cmd);
    if (rc == -1) return 127;
#if !defined(_WIN32)
    if (WIFEXITED(rc)) return WEXITSTATUS(rc);
#endif
    return rc;
}

static const char *cmotive_native_temp_dir(void)
{
#if defined(_WIN32)
    const char *d = getenv("TEMP");
    if (!d || !*d) d = getenv("TMP");
    return (d && *d) ? d : ".";
#else
    return "/tmp";
#endif
}

static int cmotive_native_pid(void)
{
#if defined(_WIN32)
    return _getpid();
#else
    return (int)getpid();
#endif
}

#endif /* CMOTIVE_FRONTEND_SUPPORT_H */
