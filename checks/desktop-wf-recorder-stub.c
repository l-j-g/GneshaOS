#include <signal.h>
#include <sys/prctl.h>
#include <unistd.h>

int main(void)
{
    if (prctl(PR_SET_NAME, "wf-recorder", 0, 0, 0) != 0) {
        return 1;
    }
    if (signal(SIGINT, SIG_DFL) == SIG_ERR) {
        return 1;
    }

    for (;;) {
        pause();
    }
}
