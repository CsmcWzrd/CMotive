#include <stdio.h>

static int sum_values(const int values[], int count)
{
    int index;
    int total = 0;
    for (index = 0; index < count; ++index) total += values[index];
    return total;
}

int main(void)
{
    const char *text = "const if return must stay inside this string";
    int values[4] = {1, 2, 3, 4};
    /* const, if and return must also stay inside this comment. */
    printf("%s=%d\n", text, sum_values(values, 4));
    return sum_values(values, 4) == 10 ? 0 : 5;
}
