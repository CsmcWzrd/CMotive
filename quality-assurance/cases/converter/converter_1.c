#include <stdio.h>

/* QA-TEST: CONVERT-0001 */
static int qa_c_1_0(int x) { return x * 3 + 2; }
/* QA-TEST: CONVERT-0002 */
static int qa_c_1_1(int x) { return x * 4 + 3; }
/* QA-TEST: CONVERT-0003 */
static int qa_c_1_2(int x) { return x * 5 + 4; }
/* QA-TEST: CONVERT-0004 */
static int qa_c_1_3(int x) { return x * 6 + 5; }
/* QA-TEST: CONVERT-0005 */
static int qa_c_1_4(int x) { return x * 7 + 6; }
/* QA-TEST: CONVERT-0006 */
static int qa_c_1_5(int x) { return x * 8 + 7; }
/* QA-TEST: CONVERT-0007 */
static int qa_c_1_6(int x) { return x * 9 + 8; }
/* QA-TEST: CONVERT-0008 */
static int qa_c_1_7(int x) { return x * 3 + 9; }
/* QA-TEST: CONVERT-0009 */
static int qa_c_1_8(int x) { return x * 4 + 10; }
/* QA-TEST: CONVERT-0010 */
static int qa_c_1_9(int x) { return x * 5 + 11; }
/* QA-TEST: CONVERT-0011 */
static int qa_c_1_10(int x) { return x * 6 + 12; }
/* QA-TEST: CONVERT-0012 */
static int qa_c_1_11(int x) { return x * 7 + 13; }
/* QA-TEST: CONVERT-0013 */
static int qa_c_1_12(int x) { return x * 8 + 14; }
/* QA-TEST: CONVERT-0014 */
static int qa_c_1_13(int x) { return x * 9 + 15; }
/* QA-TEST: CONVERT-0015 */
static int qa_c_1_14(int x) { return x * 3 + 16; }
/* QA-TEST: CONVERT-0016 */
static int qa_c_1_15(int x) { return x * 4 + 17; }
/* QA-TEST: CONVERT-0017 */
static int qa_c_1_16(int x) { return x * 5 + 18; }
/* QA-TEST: CONVERT-0018 */
static int qa_c_1_17(int x) { return x * 6 + 19; }
/* QA-TEST: CONVERT-0019 */
static int qa_c_1_18(int x) { return x * 7 + 20; }
/* QA-TEST: CONVERT-0020 */
static int qa_c_1_19(int x) { return x * 8 + 21; }
/* QA-TEST: CONVERT-0021 */
static int qa_c_1_20(int x) { return x * 9 + 22; }
/* QA-TEST: CONVERT-0022 */
static int qa_c_1_21(int x) { return x * 3 + 23; }
/* QA-TEST: CONVERT-0023 */
static int qa_c_1_22(int x) { return x * 4 + 24; }
/* QA-TEST: CONVERT-0024 */
static int qa_c_1_23(int x) { return x * 5 + 25; }
/* QA-TEST: CONVERT-0025 */
static int qa_c_1_24(int x) { return x * 6 + 26; }
/* QA-TEST: CONVERT-0026 */
static int qa_c_1_25(int x) { return x * 7 + 27; }
/* QA-TEST: CONVERT-0027 */
static int qa_c_1_26(int x) { return x * 8 + 28; }
/* QA-TEST: CONVERT-0028 */
static int qa_c_1_27(int x) { return x * 9 + 29; }
/* QA-TEST: CONVERT-0029 */
static int qa_c_1_28(int x) { return x * 3 + 30; }
/* QA-TEST: CONVERT-0030 */
static int qa_c_1_29(int x) { return x * 4 + 31; }
/* QA-TEST: CONVERT-0031 */
static int qa_c_1_30(int x) { return x * 5 + 32; }
/* QA-TEST: CONVERT-0032 */
static int qa_c_1_31(int x) { return x * 6 + 33; }

int main(void)
{
    if (qa_c_1_0(1) != 5) return 1;
    if (qa_c_1_1(2) != 11) return 2;
    if (qa_c_1_2(3) != 19) return 3;
    if (qa_c_1_3(4) != 29) return 4;
    if (qa_c_1_4(5) != 41) return 5;
    if (qa_c_1_5(6) != 55) return 6;
    if (qa_c_1_6(7) != 71) return 7;
    if (qa_c_1_7(8) != 33) return 8;
    if (qa_c_1_8(9) != 46) return 9;
    if (qa_c_1_9(1) != 16) return 10;
    if (qa_c_1_10(2) != 24) return 11;
    if (qa_c_1_11(3) != 34) return 12;
    if (qa_c_1_12(4) != 46) return 13;
    if (qa_c_1_13(5) != 60) return 14;
    if (qa_c_1_14(6) != 34) return 15;
    if (qa_c_1_15(7) != 45) return 16;
    if (qa_c_1_16(8) != 58) return 17;
    if (qa_c_1_17(9) != 73) return 18;
    if (qa_c_1_18(1) != 27) return 19;
    if (qa_c_1_19(2) != 37) return 20;
    if (qa_c_1_20(3) != 49) return 21;
    if (qa_c_1_21(4) != 35) return 22;
    if (qa_c_1_22(5) != 44) return 23;
    if (qa_c_1_23(6) != 55) return 24;
    if (qa_c_1_24(7) != 68) return 25;
    if (qa_c_1_25(8) != 83) return 26;
    if (qa_c_1_26(9) != 100) return 27;
    if (qa_c_1_27(1) != 38) return 28;
    if (qa_c_1_28(2) != 36) return 29;
    if (qa_c_1_29(3) != 43) return 30;
    if (qa_c_1_30(4) != 52) return 31;
    if (qa_c_1_31(5) != 63) return 32;
    puts("PASS CONVERTER-01 32");
    return 0;
}
