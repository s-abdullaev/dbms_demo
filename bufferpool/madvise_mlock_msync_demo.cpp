// Why Not Use The OS? (lecture slide) - taming mmap with madvise / mlock / msync.
//   madvise: tell the OS how pages will be read (readahead behaviour).
//   mlock:   pin memory ranges so they cannot be paged out.
//   msync:   flush dirty memory ranges to disk.
// Each part prints evidence via mincore() (is page resident?) or /proc (is page dirty?).
// Linux only.
//
//   g++ -O2 -o madvise_mlock_msync_demo madvise_mlock_msync_demo.cpp
//   ./madvise_mlock_msync_demo        # creates mmap_data.bin (256 MiB) if missing
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <unistd.h>
#include <cerrno>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

constexpr size_t kPage = 4096;
constexpr size_t kFileSize = 256ull << 20;      // 256 MiB
const char* kPath = "mmap_data.bin";

void die(const char* what) { perror(what); exit(1); }

void make_file() {
    struct stat st;
    if (stat(kPath, &st) == 0 && (size_t)st.st_size == kFileSize) return;
    std::vector<char> buf(1 << 20, 0x5A);
    int fd = open(kPath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) die("open");
    for (size_t off = 0; off < kFileSize; off += buf.size())
        if (write(fd, buf.data(), buf.size()) != (ssize_t)buf.size()) die("write");
    fsync(fd);
    close(fd);
    std::cout << "created " << kPath << " (" << (kFileSize >> 20) << " MiB)\n";
}

// Drop the file's clean pages from the page cache -> next access is a cold read.
// Pages still mapped into our address space are skipped by fadvise, so unmap
// them first with madvise(DONTNEED) (mapping stays valid). `skip` bytes at the
// start (e.g. an mlock'd range) are left alone; locked pages survive anyway.
void evict_cache(int fd, char* map, size_t len, size_t skip = 0) {
    madvise(map + skip, len - skip, MADV_DONTNEED);
    posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED);
}

// Number of pages of [addr, addr+len) currently resident in RAM.
size_t resident_pages(void* addr, size_t len) {
    size_t pages = (len + kPage - 1) / kPage;
    std::vector<unsigned char> vec(pages);
    if (mincore(addr, len, vec.data()) != 0) die("mincore");
    size_t n = 0;
    for (unsigned char v : vec) n += v & 1;
    return n;
}

// Kilobytes of the mapping starting at `addr` that are dirty (modified, not yet on disk).
long dirty_kb(void* addr) {
    char want[32];
    std::snprintf(want, sizeof want, "%lx-", (unsigned long)addr);
    std::ifstream f("/proc/self/smaps");
    std::string line;
    bool inMap = false, found = false;
    long kb = 0;
    while (std::getline(f, line)) {
        if (line.compare(0, strlen(want), want) == 0) inMap = found = true;
        else if (inMap && line.compare(0, 13, "Shared_Dirty:") == 0)
            kb += std::atol(line.c_str() + 13);
        else if (inMap && line.compare(0, 14, "Private_Dirty:") == 0) {
            kb += std::atol(line.c_str() + 14);
            break;
        }
    }
    return found ? kb : -1;
}

double scan_ms(const volatile char* p, size_t len) {
    auto t0 = std::chrono::steady_clock::now();
    unsigned long sum = 0;
    for (size_t i = 0; i < len; i += kPage) sum += p[i];   // touch one byte per page
    double ms = std::chrono::duration<double, std::milli>(
                    std::chrono::steady_clock::now() - t0).count();
    if (sum == 42) std::cout << "";                         // keep the loop alive
    return ms;
}

// ---------------------------------------------------------------- madvise
void demo_madvise(int fd) {
    std::cout << "\n=== madvise: tell the OS how pages will be read ===\n";
    char* map = static_cast<char*>(mmap(nullptr, kFileSize, PROT_READ, MAP_SHARED, fd, 0));
    if (map == MAP_FAILED) die("mmap");

    struct { const char* name; int advice; } modes[] = {
        {"MADV_RANDOM     (kernel: no readahead)       ", MADV_RANDOM},
        {"MADV_NORMAL     (kernel: default heuristics) ", MADV_NORMAL},
        {"MADV_SEQUENTIAL (kernel: aggressive readahead)", MADV_SEQUENTIAL},
    };
    for (auto& m : modes) {
        evict_cache(fd, map, kFileSize);
        madvise(map, kFileSize, m.advice);
        std::printf("  cold sequential scan, %s: %8.1f ms\n", m.name, scan_ms(map, kFileSize));
    }

    // WILLNEED: ask the OS to start loading pages now, before we touch them.
    evict_cache(fd, map, kFileSize);
    madvise(map, kFileSize, MADV_NORMAL);
    size_t before = resident_pages(map, kFileSize);
    madvise(map, 64 << 20, MADV_WILLNEED);                  // prefetch first 64 MiB
    usleep(1000 * 1000);                                    // readahead is async; give it a moment
    size_t after = resident_pages(map, kFileSize);
    std::printf("  MADV_WILLNEED on 64 MiB: resident pages %zu -> %zu (before any access)\n",
                before, after);

    // DONTNEED: DBMS knows it is done with this range -> release it.
    scan_ms(map, kFileSize);
    size_t full = resident_pages(map, kFileSize);
    madvise(map, kFileSize, MADV_DONTNEED);
    posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED);
    std::printf("  MADV_DONTNEED: resident pages %zu -> %zu\n",
                full, resident_pages(map, kFileSize));

    munmap(map, kFileSize);
}

// ---------------------------------------------------------------- mlock
void demo_mlock(int fd) {
    std::cout << "\n=== mlock: prevent memory ranges from being paged out ===\n";
    char* map = static_cast<char*>(mmap(nullptr, kFileSize, PROT_READ, MAP_SHARED, fd, 0));
    if (map == MAP_FAILED) die("mmap");

    constexpr size_t kLock = 4ull << 20;                    // "hot" 4 MiB, e.g. an index root
    struct rlimit rl;
    getrlimit(RLIMIT_MEMLOCK, &rl);
    std::printf("  RLIMIT_MEMLOCK = %lu KiB (mlock fails with ENOMEM above this)\n",
                (unsigned long)(rl.rlim_cur / 1024));

    evict_cache(fd, map, kFileSize);
    scan_ms(map, kFileSize);                                // fault everything in
    std::printf("  after full scan:            hot %zu/%zu, cold %zu/%zu pages resident\n",
                resident_pages(map, kLock), kLock / kPage,
                resident_pages(map + kLock, kFileSize - kLock), (kFileSize - kLock) / kPage);

    bool locked = mlock(map, kLock) == 0;
    if (!locked) std::printf("  mlock failed: %s (raise with `ulimit -l`)\n", strerror(errno));

    // Simulate memory pressure: ask the kernel to drop every page it is allowed to.
    evict_cache(fd, map, kFileSize, locked ? kLock : 0);
    std::printf("  after eviction (mlock %s): hot %zu/%zu, cold %zu/%zu pages resident\n",
                locked ? "ON " : "off",
                resident_pages(map, kLock), kLock / kPage,
                resident_pages(map + kLock, kFileSize - kLock), (kFileSize - kLock) / kPage);

    if (locked) munlock(map, kLock);
    evict_cache(fd, map, kFileSize);
    std::printf("  after munlock + eviction:   hot %zu/%zu pages resident\n",
                resident_pages(map, kLock), kLock / kPage);

    munmap(map, kFileSize);
}

// ---------------------------------------------------------------- msync
void demo_msync(int fd) {
    std::cout << "\n=== msync: flush memory ranges to disk ===\n";
    constexpr size_t kLen = 64ull << 20;
    char* map = static_cast<char*>(
        mmap(nullptr, kLen, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0));
    if (map == MAP_FAILED) die("mmap");

    memset(map, 0xEE, kLen);                                // dirty 64 MiB through the mapping
    std::printf("  after memset:               dirty = %6ld KiB (only in RAM, OS flushes whenever it likes)\n",
                dirty_kb(map));

    auto t0 = std::chrono::steady_clock::now();
    msync(map, 8 << 20, MS_ASYNC);                          // schedule write-back, don't wait
    double async_ms = std::chrono::duration<double, std::milli>(
                          std::chrono::steady_clock::now() - t0).count();
    std::printf("  msync(8 MiB, MS_ASYNC):     dirty = %6ld KiB, returned in %.1f ms (no durability yet)\n",
                dirty_kb(map), async_ms);

    t0 = std::chrono::steady_clock::now();
    if (msync(map, kLen, MS_SYNC) != 0) die("msync");       // block until on disk
    double sync_ms = std::chrono::duration<double, std::milli>(
                         std::chrono::steady_clock::now() - t0).count();
    std::printf("  msync(64 MiB, MS_SYNC):     dirty = %6ld KiB, blocked %.1f ms (now durable)\n",
                dirty_kb(map), sync_ms);

    std::cout << "  -> DBMS needs this for WAL ordering: log page must hit disk BEFORE the data page.\n"
                 "     With mmap the OS may write a dirty data page at any time, even mid-transaction.\n";

    munmap(map, kLen);
}

int main() {
    make_file();
    int fd = open(kPath, O_RDWR);
    if (fd < 0) die("open");
    demo_madvise(fd);
    demo_mlock(fd);
    demo_msync(fd);
    close(fd);
}
