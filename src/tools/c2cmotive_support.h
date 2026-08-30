#ifndef C2CMOTIVE_SUPPORT_H
#define C2CMOTIVE_SUPPORT_H

#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS 1
#endif
#if !defined(_WIN32) && !defined(_DEFAULT_SOURCE)
#define _DEFAULT_SOURCE 1
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>

#if defined(_WIN32)
#include <direct.h>
#define C2M_PATH_SEP '\\'
#else
#include <sys/stat.h>
#include <unistd.h>
#define C2M_PATH_SEP '/'
#endif

typedef struct C2MBuffer {
    char *data;
    size_t length;
    size_t capacity;
} C2MBuffer;

typedef struct C2MOptions {
    char *input;
    char *output;
    char *support;
    char *include_name;
    int keyword_case;
    int verbose;
} C2MOptions;

static int c2m_native_mkdir(const char *path)
{
#if defined(_WIN32)
    return _mkdir(path);
#else
    return mkdir(path, 0777);
#endif
}

#endif
