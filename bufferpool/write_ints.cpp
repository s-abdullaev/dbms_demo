// Writes 1024 ints (0..1023) in binary format to integers.b (4096 bytes = one page).
#include <fcntl.h>
#include <unistd.h>
#include <iostream>

int main() {
    int ints[1024];
    for (int i = 0; i < 1024; ++i)
        ints[i] = i;

    int fd = open("integers.b", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) { perror("open"); return 1; }
    if (write(fd, ints, sizeof(ints)) != sizeof(ints)) { perror("write"); return 1; }
    close(fd);

    std::cout << "Wrote " << sizeof(ints) << " bytes to integers.b" << std::endl;
}
