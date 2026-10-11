// Allocates 5 MiB with anonymous mmap (no file), fills it with random ints,
// and prints the first 10.
#include <sys/mman.h>
#include <cstdio>
#include <iostream>
#include <random>

int main() {
    const size_t size = 5 * (1ull << 20);   // 5 MiB
    void* mem = mmap(nullptr, size,
                     PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS,
                     -1, 0);
    if (mem == MAP_FAILED) { perror("mmap"); return 1; }

    int* ints = static_cast<int*>(mem);
    const size_t count = size / sizeof(int);  // 1,310,720 ints

    std::mt19937 gen(42);
    std::uniform_int_distribution<int> dist(0, 1000000);
    for (size_t i = 0; i < count; ++i)
        ints[i] = dist(gen);

    std::cout << "Allocated " << size << " bytes = " << count << " ints" << std::endl;
    for (int i = 0; i < 10; ++i)
        std::cout << ints[i] << std::endl;

    munmap(mem, size);
}
