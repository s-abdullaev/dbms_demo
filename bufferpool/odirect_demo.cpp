// Buffered I/O vs O_DIRECT (lecture slide "OS Page Cache").
// Reads the same file twice per mode and times each pass.
//   buffered: pass 1 fills the OS page cache, pass 2 is served from RAM (fast).
//   O_DIRECT: page cache bypassed, both passes hit the disk (same speed).
// Linux only. O_DIRECT needs: aligned buffer, aligned size, aligned file offset.
//
//   g++ -O2 -o odirect_demo odirect_demo.cpp
//   ./odirect_demo                 # creates data.bin (256 MiB) if missing
#ifndef _GNU_SOURCE
#define _GNU_SOURCE            // O_DIRECT
#endif
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <cerrno>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>

constexpr size_t kAlign = 4096;                 // page / logical block size
constexpr size_t kChunk = 1 << 20;              // read 1 MiB at a time
constexpr size_t kFileSize = 256ull << 20;      // 256 MiB
const char* kPath = "data.bin";

void make_file() {
    struct stat st;
    if (stat(kPath, &st) == 0 && (size_t)st.st_size == kFileSize) return;
    void* buf = aligned_alloc(kAlign, kChunk);
    memset(buf, 0xAB, kChunk);
    int fd = open(kPath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    for (size_t off = 0; off < kFileSize; off += kChunk)
        if (write(fd, buf, kChunk) != (ssize_t)kChunk) { perror("write"); exit(1); }
    fsync(fd);                                   // flush dirty pages to disk
    close(fd);
    free(buf);
    std::cout << "created " << kPath << " (" << (kFileSize >> 20) << " MiB)\n";
}

// Drop this file's pages from the page cache so the first buffered pass is cold
// (no root needed, unlike writing to /proc/sys/vm/drop_caches).
void evict_cache() {
    int fd = open(kPath, O_RDONLY);
    posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED);
    close(fd);
}

double read_pass(int flags) {
    int fd = open(kPath, O_RDONLY | flags);
    if (fd < 0) { perror("open"); exit(1); }
    void* buf = aligned_alloc(kAlign, kChunk);   // aligned buffer: required by O_DIRECT
    auto t0 = std::chrono::steady_clock::now();
    ssize_t n;
    while ((n = read(fd, buf, kChunk)) > 0) {}
    if (n < 0) { perror("read"); exit(1); }
    double ms = std::chrono::duration<double, std::milli>(
                    std::chrono::steady_clock::now() - t0).count();
    free(buf);
    close(fd);
    return ms;
}

int main() {
    make_file();
    evict_cache();

    for (int direct = 0; direct <= 1; ++direct) {
        int flags = direct ? O_DIRECT : 0;
        std::cout << (direct ? "O_DIRECT" : "buffered") << ":\n";
        for (int pass = 1; pass <= 2; ++pass)
            std::printf("  pass %d: %8.1f ms\n", pass, read_pass(flags));
    }

    // O_DIRECT with an unaligned buffer -> EINVAL
    int fd = open(kPath, O_RDONLY | O_DIRECT);
    char* raw = static_cast<char*>(aligned_alloc(kAlign, 2 * kAlign));
    ssize_t n = read(fd, raw + 1, kAlign);       // misaligned by 1 byte
    std::cout << "unaligned O_DIRECT read: "
              << (n < 0 ? strerror(errno) : "ok") << "\n";
    close(fd);
    free(raw);
}
