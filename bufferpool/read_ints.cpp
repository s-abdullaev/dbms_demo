// Reads 1024 binary ints from integers.b via mmap (as in the lecture slide).
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <iostream>

int main() {
    int fd = open("integers.b", O_RDONLY);
    void* mappedFile = mmap(nullptr, 4096, PROT_READ, MAP_SHARED, fd, 0);
    int* fileInts = static_cast<int*>(mappedFile);

    for (int i = 0; i < 1024; ++i)
        std::cout << fileInts[i] << std::endl;
    munmap(mappedFile, 4096);
    close(fd);
}
