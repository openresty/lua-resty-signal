#include <signal.h>


enum {
    RS_NONE = 0,
    RS_HUP = 1,
    RS_INT = 2,
    RS_QUIT = 3,
    RS_ILL = 4,
    RS_TRAP = 5,
    RS_ABRT = 6,
    RS_BUS = 7,
    RS_FPE = 8,
    RS_KILL = 9,
    RS_USR1 = 10,
    RS_SEGV = 11,
    RS_USR2 = 12,
    RS_PIPE = 13,
    RS_ALRM = 14,
    RS_TERM = 15,
    RS_CHLD = 17,
    RS_CONT = 18,
    RS_STOP = 19,
    RS_TSTP = 20,
    RS_TTIN = 21,
    RS_TTOU = 22,
    RS_URG= 23,
    RS_XCPU = 24,
    RS_XFSZ = 25,
    RS_VTALRM = 26,
    RS_PROF = 27,
    RS_WINCH = 28,
    RS_IO = 29,
    RS_PWR	= 30
};


int
resty_signal_signum(int num)
{
    switch (num) {

    case RS_NONE:
        return 0;

    case RS_HUP:
        return SIGHUP;

    case RS_INT:
        return SIGINT;

    case RS_QUIT:
        return SIGQUIT;

    case RS_ILL:
        return SIGILL;

    case RS_TRAP:
        return SIGTRAP;

    case RS_ABRT:
        return SIGABRT;

    case RS_BUS:
        return SIGBUS;

    case RS_FPE:
        return SIGFPE;

    case RS_KILL:
        return SIGKILL;

    case RS_SEGV:
        return SIGSEGV;

    case RS_PIPE:
        return SIGPIPE;

    case RS_ALRM:
        return SIGALRM;

    case RS_TERM:
        return SIGTERM;

    case RS_CHLD:
        return SIGCHLD;

    case RS_CONT:
        return SIGCONT;

    case RS_STOP:
        return SIGSTOP;

    case RS_TSTP:
        return SIGTSTP;

    case RS_TTIN:
        return SIGTTIN;

    case RS_TTOU:
        return SIGTTOU;

    case RS_XCPU:
        return SIGXCPU;

    case RS_XFSZ:
        return SIGXFSZ;

    case RS_VTALRM:
        return SIGVTALRM;

    case RS_PROF:
        return SIGPROF;

    case RS_WINCH:
        return SIGWINCH;

    case RS_IO:
        return SIGIO;

    default:
        return -1;
    }
}
