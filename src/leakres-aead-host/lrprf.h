#ifndef UI_LRPF_H
#define UI_LRPF_H

#define LRPRF_OUTPUT_SIZE 16

//#define UI_LRPRF_DEBUG

typedef enum {
	LR_RES_VERIFY_SUCCESS = 0,
	LR_RES_VERIFY_FAIL,
	/* invalid arguments */
	LR_RES_INVALID_ARG,
	/* default error */
	LR_RES_UNKNOWN_ERR,
} lr_result;

/* data complexities, only dividers of 8 to make implementation easier */
typedef enum {
        DC_2 = 1,
        DC_4 = 2,
        DC_16 = 4,
        DC_256 = 8,
} lr_dc;

lr_result lrprf(const uint8_t *data, size_t data_len, const uint8_t *key,
		size_t key_len, const lr_dc dc, uint8_t *output);

#endif
