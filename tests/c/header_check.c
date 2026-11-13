/* Prints what cropsim_kernel.h says; tests/test_c_header.py compares it
 * with the library. Not linked to the library, so it builds anywhere. */
#include <stdio.h>
#include "cropsim_kernel.h"
int main(void) {
    printf("%d %d\n", CSK_API_VERSION, CSK_REVERT_ALL);
    printf("%zu %zu %zu %zu %zu %zu %zu\n", sizeof(csk_params_t), sizeof(csk_sim_t),
           sizeof(csk_soil_t), sizeof(csk_weather_t), sizeof(csk_state_t),
           sizeof(csk_options_t), sizeof(csk_result_t));
    return 0;
}
