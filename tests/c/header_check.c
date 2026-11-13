#include <stdio.h>
#include "cropsim_kernel.h"
int main(void){
  size_t s[]={sizeof(csk_params_t),sizeof(csk_sim_t),sizeof(csk_soil_t),sizeof(csk_weather_t),sizeof(csk_state_t),sizeof(csk_options_t),sizeof(csk_result_t)};
  int bad=0; for(int i=0;i<7;i++){ if((int)s[i]!=csk_struct_size(i+1)){printf("mismatch %d: %zu vs %d\n",i+1,s[i],csk_struct_size(i+1));bad=1;} }
  printf("version %d, %s\n", csk_version(), bad?"BAD":"sizes ok"); return bad;}
