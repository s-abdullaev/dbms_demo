// Disk I/O scheduling: noop (FIFO) vs deadline (lecture slide "OS and hardware
// reorder and batch I/O requests").
// Simulates a spinning disk: seek time grows with head travel distance, so the
// ORDER in which requests are dispatched changes total throughput.
//   noop:     FIFO queue, dispatch in arrival order. No reordering (just merging
//             in the real kernel). Seeks are random -> slow on HDD.
//   deadline: keeps requests sorted by sector (elevator, one-way sweep) for
//             short seeks, plus a FIFO per direction with an expiry time
//             (read 500 ms, write 5 s) so no request starves. Reads are
//             preferred over writes; dispatch happens in batches of 16.
// Pure simulation: portable, no root, no real disk touched.
//
//   g++ -O2 -std=c++17 -o io_sched_demo io_sched_demo.cpp
//   ./io_sched_demo
//
// On a real Linux box (needs root; blk-mq kernels call them "none" / "mq-deadline"):
//   cat /sys/block/sda/queue/scheduler
//   echo deadline > /sys/block/sda/queue/scheduler
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <deque>
#include <iomanip>
#include <iostream>
#include <map>
#include <memory>
#include <random>
#include <string>
#include <vector>

constexpr long   kMaxSector   = 1'000'000;
constexpr double kReadExpire  = 500.0;    // ms, deadline default
constexpr double kWriteExpire = 5000.0;   // ms, deadline default
constexpr int    kFifoBatch   = 16;       // requests dispatched per sweep
constexpr int    kWritesStarved = 2;      // reads served before a write is forced

struct Request {
    int    id;
    bool   isRead;
    long   sector;
    double arrival;     // ms
    double expires;     // ms, used by deadline only
    double finish = 0;  // ms
};

// ---------------------------------------------------------------- schedulers
class Scheduler {
public:
    virtual ~Scheduler() = default;
    virtual std::string name() const = 0;
    virtual void add(Request* r) = 0;
    virtual Request* next(double now, long headSector) = 0;   // nullptr if empty
    virtual bool empty() const = 0;
    int expiredDispatches = 0;
};

class Noop : public Scheduler {
    std::deque<Request*> q;
public:
    std::string name() const override { return "noop (FIFO)"; }
    void add(Request* r) override { q.push_back(r); }
    bool empty() const override { return q.empty(); }
    Request* next(double, long) override {
        if (q.empty()) return nullptr;
        Request* r = q.front();
        q.pop_front();
        return r;
    }
};

class Deadline : public Scheduler {
    std::multimap<long, Request*> sorted[2];   // [0]=read [1]=write, by sector
    std::deque<Request*>          fifo[2];     // by arrival (== by expiry)
    int  dir = 0, batching = 0, starved = 0;
    long lastSector = 0;

    void remove(Request* r) {
        int d = r->isRead ? 0 : 1;
        auto range = sorted[d].equal_range(r->sector);
        for (auto it = range.first; it != range.second; ++it)
            if (it->second == r) { sorted[d].erase(it); break; }
        fifo[d].erase(std::find(fifo[d].begin(), fifo[d].end(), r));
    }
public:
    std::string name() const override { return "deadline"; }
    bool empty() const override { return sorted[0].empty() && sorted[1].empty(); }
    void add(Request* r) override {
        int d = r->isRead ? 0 : 1;
        sorted[d].emplace(r->sector, r);
        fifo[d].push_back(r);
    }
    Request* next(double now, long) override {
        if (empty()) return nullptr;

        // Continue the current sweep: next request at or after the last sector.
        if (batching > 0 && batching < kFifoBatch) {
            auto it = sorted[dir].lower_bound(lastSector);
            if (it != sorted[dir].end()) {
                Request* r = it->second;
                remove(r); ++batching; lastSector = r->sector;
                return r;
            }
        }

        // Start a new batch: pick direction. Reads first, but writes can't starve.
        bool haveR = !sorted[0].empty(), haveW = !sorted[1].empty();
        if (haveR && haveW) {
            if (starved >= kWritesStarved) { dir = 1; starved = 0; }
            else                           { dir = 0; ++starved; }
        } else {
            dir = haveR ? 0 : 1;
            starved = 0;
        }

        // Oldest request expired? Serve it (and sweep from there).
        // Otherwise restart the sweep at the lowest sector (one-way elevator).
        Request* r;
        if (!fifo[dir].empty() && fifo[dir].front()->expires <= now) {
            r = fifo[dir].front();
            ++expiredDispatches;
        } else {
            auto it = sorted[dir].lower_bound(lastSector);
            if (it == sorted[dir].end()) it = sorted[dir].begin();   // wrap
            r = it->second;
        }
        remove(r);
        batching = 1;
        lastSector = r->sector;
        return r;
    }
};

// ---------------------------------------------------------------- simulation
struct Result {
    std::string name;
    double totalMs, avgRead, maxRead, avgWrite, maxWrite;
    long   seekDistance;
    int    expired;
};

// Seek ~1 ms minimum + up to 8 ms full stroke, plus 0.1 ms transfer.
double serviceTime(long from, long to) {
    long dist = std::labs(to - from);
    return (dist ? 1.0 + 8.0 * dist / kMaxSector : 0.0) + 0.1;
}

Result simulate(Scheduler& s, std::vector<Request> reqs) {   // copy: each run gets fresh state
    double now = 0;
    long   head = 0, seekDistance = 0;
    size_t nextArrival = 0;
    int    done = 0;
    const int n = (int)reqs.size();

    while (done < n) {
        while (nextArrival < reqs.size() && reqs[nextArrival].arrival <= now)
            s.add(&reqs[nextArrival++]);
        if (s.empty()) { now = reqs[nextArrival].arrival; continue; }   // idle disk

        Request* r = s.next(now, head);
        now += serviceTime(head, r->sector);
        seekDistance += std::labs(r->sector - head);
        head = r->sector;
        r->finish = now;
        ++done;
    }

    Result res{s.name(), now, 0, 0, 0, 0, seekDistance, s.expiredDispatches};
    int nr = 0, nw = 0;
    for (auto& r : reqs) {
        double lat = r.finish - r.arrival;
        if (r.isRead) { res.avgRead  += lat; res.maxRead  = std::max(res.maxRead,  lat); ++nr; }
        else          { res.avgWrite += lat; res.maxWrite = std::max(res.maxWrite, lat); ++nw; }
    }
    res.avgRead /= nr; res.avgWrite /= nw;
    return res;
}

int main() {
    // Workload: 3000 random 4 KiB requests, 70% reads, one every ~3 ms on average.
    // Mean random service time is ~4 ms, so FIFO is overloaded; sorting is not.
    std::mt19937 gen(42);
    std::uniform_int_distribution<long> sector(0, kMaxSector);
    std::exponential_distribution<double> gap(1.0 / 3.0);
    std::bernoulli_distribution isRead(0.7);

    std::vector<Request> reqs;
    double t = 0;
    for (int i = 0; i < 3000; ++i) {
        t += gap(gen);
        bool rd = isRead(gen);
        reqs.push_back({i, rd, sector(gen), t, t + (rd ? kReadExpire : kWriteExpire)});
    }

    Noop     noop;
    Deadline deadline;
    std::vector<Result> results = { simulate(noop, reqs), simulate(deadline, reqs) };

    std::cout << "3000 requests, 70% reads, random sectors in [0, " << kMaxSector << "]\n\n"
              << std::left << std::setw(14) << "scheduler"
              << std::right << std::setw(11) << "total ms"
              << std::setw(15) << "seek distance"
              << std::setw(12) << "avg rd ms" << std::setw(11) << "max rd ms"
              << std::setw(12) << "avg wr ms" << std::setw(11) << "max wr ms"
              << std::setw(9)  << "expired" << "\n";
    std::cout << std::fixed << std::setprecision(1);
    for (auto& r : results)
        std::cout << std::left << std::setw(14) << r.name
                  << std::right << std::setw(11) << r.totalMs
                  << std::setw(15) << r.seekDistance
                  << std::setw(12) << r.avgRead << std::setw(11) << r.maxRead
                  << std::setw(12) << r.avgWrite << std::setw(11) << r.maxWrite
                  << std::setw(9)  << r.expired << "\n";

    std::cout << "\nnoop never reorders -> long random seeks, queue keeps growing.\n"
                 "deadline sorts by sector -> short seeks, higher throughput; the\n"
                 "per-request expiry bounds how long any request can wait.\n"
                 "Neither knows which request the DBMS cares about most.\n";
}
