// Maps integers.b read-write with MAP_SHARED and increments each int by 1.
// The writes go to the page cache; the OS pushes them to the file on disk
// (msync forces it now, otherwise it happens at munmap/close or later).
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <cstdio>
#include <iostream>

int main() {
    int fd = open("integers.b", O_RDWR);      // O_RDWR: we will write
    if (fd < 0) { perror("open"); return 1; }

    void* mappedFile = mmap(nullptr, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (mappedFile == MAP_FAILED) { perror("mmap"); return 1; }

    int* fileInts = static_cast<int*>(mappedFile);
    for (int i = 0; i < 1024; ++i)
        ++fileInts[i];                         // plain memory write, no write() call

    msync(mappedFile, 4096, MS_SYNC);          // optional: flush to disk now
    munmap(mappedFile, 4096);
    close(fd);

    std::cout << "Incremented 1024 ints in integers.b" << std::endl;
}
