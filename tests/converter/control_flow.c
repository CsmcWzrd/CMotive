#include <stdio.h>

static int calculate(int limit)
{
    int index = 0;
    int total = 0;
    for (index = 0; index < limit; ++index)
        if ((index % 2) == 0)
            total += index;
        else if (index == 3)
            total += 10;
        else
            total += 1;
    while (total < 20)
        ++total;
    do
        --total;
    while (total > 19);
    switch (limit) {
        case 5: total += 2; break;
        default: total = -1; break;
    }
    return total;
}

int main(void)
{
    int value = calculate(5);
    printf("flow=%d\n", value);
    return value == 21 ? 0 : 4;
}
