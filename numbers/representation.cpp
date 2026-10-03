// Shows how integers (two's complement) and floats (IEEE 754) look in memory,
// and why floating point arithmetic gives truncation (rounding) errors.
//
// Build: clang++ -std=c++17 -O0 -o representation representation.cpp
#include <bitset>
#include <climits>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

// Reinterpret the raw bytes of a float as a 32-bit unsigned integer.
uint32_t float_bits(float f) {
    uint32_t u;
    std::memcpy(&u, &f, sizeof(u));
    return u;
}

void show_int8(int8_t x) {
    std::printf("%6d  bin %s  hex 0x%02X\n", x,
                std::bitset<8>((uint8_t)x).to_string().c_str(), (uint8_t)x);
}

void show_int32(int32_t x) {
    std::printf("%12d  bin %s  hex 0x%08X\n", x,
                std::bitset<32>((uint32_t)x).to_string().c_str(), (uint32_t)x);
}

// Split a float into sign | exponent | mantissa and decode it.
void show_float(const char* label, float f) {
    uint32_t u = float_bits(f);
    uint32_t sign = u >> 31;
    uint32_t exp = (u >> 23) & 0xFF;
    uint32_t mant = u & 0x7FFFFF;
    std::string b = std::bitset<32>(u).to_string();

    std::printf("%-10s %s %s %s  hex 0x%08X  ", label,
                b.substr(0, 1).c_str(), b.substr(1, 8).c_str(), b.substr(9).c_str(), u);
    if (exp == 0xFF)
        std::printf("%s\n", mant ? "NaN" : (sign ? "-inf" : "+inf"));
    else if (exp == 0)
        std::printf("(-1)^%u * 0.mant * 2^-126  (zero/denormal)  = %.10g\n", sign, f);
    else
        std::printf("(-1)^%u * 1.mant * 2^%d  = %.10g\n", sign, (int)exp - 127, f);
}

int main() {
    std::puts("=== Two's complement, 8-bit ===");
    for (int8_t x : {0, 1, 2, 5, 127, -1, -2, -5, -127, -128})
        show_int8(x);

    std::puts("\nNegation = invert bits + 1:  5 -> ~5 -> ~5 + 1");
    show_int8(5);
    show_int8(~5);
    show_int8(~5 + 1);

    std::puts("\n=== Two's complement, 32-bit ===");
    for (int32_t x : {0, 1, -1, 1000, -1000, INT_MAX, INT_MIN})
        show_int32(x);

    std::puts("\nOverflow wraps around: 127 + 1 in 8 bits");
    int8_t big = 127;
    show_int8((int8_t)(big + 1));

    std::puts("\n=== IEEE 754 float: sign | exponent (8) | mantissa (23) ===");
    show_float("0.0", 0.0f);
    show_float("-0.0", -0.0f);
    show_float("1.0", 1.0f);
    show_float("2.0", 2.0f);
    show_float("-2.5", -2.5f);
    show_float("0.5", 0.5f);
    show_float("0.1", 0.1f);
    show_float("0.2", 0.2f);
    show_float("0.3", 0.3f);
    show_float("1/3", 1.0f / 3.0f);
    show_float("smallest", 1.4e-45f);
    show_float("inf", 1e38f * 10.0f);

    std::puts("\n=== Truncation errors ===");
    // 0 itself is exact (all bits zero), but 0.1 has an infinite binary
    // expansion (0.000110011001100...), so it is cut off after 23 bits.
    std::printf("0.1f is really        %.20f\n", 0.1f);
    std::printf("0.1  (double) really  %.20f\n", 0.1);

    // Something that should be 0 is not 0.
    double da = 0.1, db = 0.2, dc = 0.3;
    std::printf("0.1 + 0.2 - 0.3     = %.10e  (expected 0)\n", da + db - dc);
    std::printf("0.1 + 0.2 == 0.3    ? %s\n", (da + db == dc) ? "true" : "false");

    float sum = 0.0f;
    for (int i = 0; i < 10; ++i) sum += 0.1f;
    std::printf("sum of ten 0.1f     = %.10f, minus 1.0 = %.10e\n", sum, (double)(sum - 1.0f));

    // Big + small: the small value is lost entirely.
    float f1 = 16777216.0f;  // 2^24
    std::printf("2^24 + 1 as float   = %.1f  (the +1 is lost)\n", f1 + 1.0f);
    std::printf("1.0f + 1e-8f == 1.0f ? %s\n", (1.0f + 1e-8f == 1.0f) ? "true" : "false");

    // Underflow: a tiny non-zero result rounds to exactly 0.
    float tiny = 1e-30f;
    std::printf("1e-30f * 1e-30f     = %g  (true answer 1e-60, too small -> 0)\n", tiny * tiny);
}
