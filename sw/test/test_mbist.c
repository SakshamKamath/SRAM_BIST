#include "bist.h"


int main(void)
{
    uart_init();
    printf("Starting MBIST\n");
    // uart_write_flush();

    uint32_t ret = mbist_run_macro(0);
    printf("MBIST finished\n");
    uart_write_flush();
}