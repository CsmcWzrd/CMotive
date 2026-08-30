#include <stdio.h>
static int qa_converter_square(int x) { return x * x; }
static int qa_converter_sum(const int values[], int count)
{
    int i;
    int total = 0;
    for (i = 0; i < count; ++i) total += values[i];
    return total;
}
int main(void)
{
    int values[3] = { 1, 2, 3 };
    if (qa_converter_square(5) != 25) return 1;
    if (qa_converter_sum(values, 3) != 6) return 2;
    puts("PASS TOOL CONVERTER");
    return 0;
}
