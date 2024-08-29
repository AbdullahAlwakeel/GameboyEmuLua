#import <stdio.h>
#import <string.h>

struct Sound {
    unsigned char *Data_CH1;
    unsigned char *Data_CH2;
    unsigned char *Data_CH3;
    unsigned char *Data_CH4;
    int length_CH1;
    int length_CH2;
    int length_CH3;
    int length_CH4;

    int currCH; //0 -> 1, 1 -> 2, 2 -> 3, 3 -> 4
};

void audio_callback(void *userdata, u_int8_t *stream, int len) {
    struct Sound *s_data = (struct Sound *)userdata;

    //memset(stream, 255, len);
}
