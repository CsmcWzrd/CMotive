#include <stdio.h>
#include <stdarg.h>

typedef struct Pair {
    int left;
    int right;
} Pair;

static int bias = 1;

static void native_log(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    vprintf(format, args);
    va_end(args);
}

static int add_pair(const Pair *pair)
{
    return pair->left + pair->right + bias;
}

int main(void)
{
    Pair pair = {2, 3};
    native_log("converted=%d\n", add_pair(&pair));
    return add_pair(&pair) == 6 ? 0 : 3;
}
