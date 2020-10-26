/*
 * Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V. 
 * acting on behalf of its Fraunhofer Institute AISEC. 
 * All rights reserved.
 *
 */

#ifndef LRPRF_AES_DRIVER_H_
#define LRPRF_AES_DRIVER_H_

/*------------- Register mapping -----------------
--
-- Register
-- 1.  control_reg (32 bit)
--     0: mode   '0' encryption, '1' decryption
--     1: start  '0' not active, '1' start computation
--     2: reset  '0' nothing, '1' soft reset to clear all registers
--     3: aac data  '0' data in in_reg is no authenticated data, '1' data in in_reg is authenticated data
--     4: tag data  '0' data in in_reg is no tag data, '1' data in in_reg is tag data
--     5: key validity '0' external key (PUF) is invalid   '1' external key (PUF) is valid
--     6: load key   '0' not active   '1' load new key
--     7: load iv    '0' not active   '1' load iv
--     8: prf standalone  '0' not active '1' prf standalone
--	   9: lr stream cipher '0' not active '1' lr stream cipher
-- 2.  status_reg
--     0: done   '0', not computed, '1' computation done, result ready
--     1: busy   '0' idle. '1' busy
--     2: tag valid    '0' tag not valid   '1' tag valid
--     3: error  '0' no error, '1' error
--     4: fifo empty   '0' not empty, '1' empty
----------  128 bit plaintext -------------------
-- 3.  in_reg0
-- 4.  in_reg1
-- 5.  in_reg2
-- 6.  in_reg3
----------  128 bit iv -------------------
-- 7.  iv_reg0
-- 8.  iv_reg1
-- 9.  iv_reg2
-- 10. iv_reg3
----------   128 bit ciphertext -------------------
-- 11. out_reg0 (obsolete)
-- 12. out_reg1 (obsolete)
-- 13. out_reg2 (obsolete)
-- 14. out_reg3 (obsolete)
----------  128/256 bit key (set via control bit) -------------------
-- 15. key_reg0 (obsolete)
-- 16. key_reg1 (obsolete)
-- 17. key_reg2 (obsolete)
-- 18. key_reg3 (obsolete)
-- 19. key_reg4 (obsolete)
-- 20. key_reg5 (obsolete)
-- 21. key_reg6 (obsolete)
-- 22. key_reg7 (obsolete)
------------------------------------------------*/

#include <common.h>
#include <aisec_genlib.h>
#include "linux/types.h"
#include <u-boot/sha256.h>

#define LRPRF_AES_DEBUG 0


#define LRPRF_AES_BASEADDRESS 0x6B040000
#define CONTROL_OFFSET 0x00000000 // regnr 1
#define STATUS_OFFSET  0x00000004 // regnr 2
#define IN_OFFSET      0x00000008 // regnr 3
#define IV_OFFSET      0x00000018 // regnr 7
#define OUT_OFFSET     0x00000028 // regnr 11
#define KEY_OFFSET     0x00000038 // regnr 15

#define LRPRF_AES_CTRL_REG (LRPRF_AES_BASEADDRESS + 0)
#define LRPRF_AES_STAT_REG (LRPRF_AES_BASEADDRESS + 4)
#define LRPRF_AES_IN_REG0  (LRPRF_AES_BASEADDRESS + 8)
#define LRPRF_AES_IN_REG1  (LRPRF_AES_BASEADDRESS + 12)
#define LRPRF_AES_IN_REG2  (LRPRF_AES_BASEADDRESS + 16)
#define LRPRF_AES_IN_REG3  (LRPRF_AES_BASEADDRESS + 20)
#define LRPRF_AES_IV_REG0  (LRPRF_AES_BASEADDRESS + 24)
#define LRPRF_AES_IV_REG1  (LRPRF_AES_BASEADDRESS + 28)
#define LRPRF_AES_IV_REG2  (LRPRF_AES_BASEADDRESS + 32)
#define LRPRF_AES_IV_REG3  (LRPRF_AES_BASEADDRESS + 36)
#define LRPRF_AES_OUT_REG0 (LRPRF_AES_BASEADDRESS + 40)
#define LRPRF_AES_OUT_REG1 (LRPRF_AES_BASEADDRESS + 44)
#define LRPRF_AES_OUT_REG2 (LRPRF_AES_BASEADDRESS + 48)
#define LRPRF_AES_OUT_REG3 (LRPRF_AES_BASEADDRESS + 52)

#define LRPRF_AES_CTRL_MODE_MASK 0x00000001
#define LRPRF_AES_CTRL_START_MASK 0x00000002
#define LRPRF_AES_CTRL_RST_MASK 0x00000004
#define LRPRF_AES_CTRL_TAG_IN_MASK 0x00000008
#define LRPRF_AES_CTRL_EXT_KEY_MASK 0x00000020
#define LRPRF_AES_CTRL_LD_KEY_MASK 0x00000040
#define LRPRF_AES_CTRL_LD_IV_MASK 0x00000080
#define LRPRF_AES_STANDALONE_MASK 0x00000010
#define LRPRF_AES_LD_KEY_STANDALONE_MASK 0x00000050
#define LRPRF_AES_LD_KEY_STREAMCIPHER_MASK 0x00000040
#define LRPRF_AES_STREAMCIPHER_MASK 0x00000000

#define LRPRF_AES_STAT_DONE_MASK 0x00000001
#define LRPRF_AES_STAT_BUSY_MASK 0x00000002
#define LRPRF_AES_STAT_TAG_VALID_MASK 0x00000004
#define LRPRF_AES_STAT_ERROR_MASK 0x00000008
#define LRPRF_AES_STAT_FIFO_EMPTY_MASK 0x00000010

#define LRPRF_AES_TAG_LENGTH_BYTES 0x10

#define LRPRF_AES_POLLTIMEOUT 0xffffffff

#define BLOCK_LENGTH 2048
#define CHUNK_SIZE (BLOCK_LENGTH + 128)

#define DEVCFG_INT_STS_ADDRESS	0xF800700C
#define DEVCFG_INT_STS_PCFG_DONE_INT_MASK	0x00000004

/* @brief Encrypted data file type definition
 *
 */

typedef struct lrprf_aes_encfile {
	uint32_t block_count_high;
	uint32_t block_count_low;
	uint32_t block_length_high;
	uint32_t block_length_low;
	uint32_t block_length_last_high;
	uint32_t block_length_last_low;
	uint32_t *iv_h;
	uint32_t *iv;
	uint32_t aad_length_high; // ignored -> aad_length limited to ~ 536 MB
	uint32_t aad_length_low;
	uint8_t *aad;
	uint8_t *payload_0; // all following payload- and tag sections must \
									be addressed using multiples of block_length \
									+ AES128GMAC_TAG_LENTH_BYTES

} lrprf_aes_encfile;

typedef struct lraead_encfile {
	uint32_t *nonce;
	uint32_t *tag;
	uint32_t aad_length; 
	uint32_t payload_length;
	uint8_t *aad;
	uint8_t *payload; 
} lraead_encfile;

/* Source: http://stackoverflow.com/questions/1644868/c-define-macro-for-debug-printing */
//#define FE_debug_print(fmt, ...) \
//        do { if (FUZZYEXTRACTOR_DEBUG) fprintf(stderr, "%s:%d:%s(): " fmt, __FILE__, __LINE__, __func__, __VA_ARGS__); } while (0)


/* Definition above (using __VA_ARGS__) does not work with used GCC.
   https://gcc.gnu.org/onlinedocs/cpp/Variadic-Macros.html */
#define lrprf_aes_debug_print(fmt, args...) \
        do { if (LRPRF_AES_DEBUG) fprintf(stderr, "%s(): " fmt, __func__, ##args); } while (0)


/*************************** Function prototypes *****************************/

/* @brief  Prints AES registers 
 *
 */
void lrprf_aes_dumpregisters(void);

/* @brief  Resets AES 
 *
 */
int lrprf_aes_reset(void);

/* @brief  Polls for timeout
 *
 * @param  regAddr          Register to be polled
 * @param  bitMask			Bit mask of register
 * @param  value			Expected value
 * @param  timeout			Poll time
 * @return 0 if successful, 1 if not
 */
int poll_timeout(u32 regAddr, u32 bitMask, u32 value, u32 timeout);

/* @brief Reads encrypted data file 
 *
 * @param *filePtr Pointer to first position
 * @param *encFile Pointer to struct
 * @return 0 if successful, 1 if not
 */
int lrprf_aes_load_encfile(volatile u32 *filePtr, lrprf_aes_encfile *encFile );

/* @brief Prints encrypted data  
 *
 * @param *encFile Pointer to struct
 * @return 0 if successful, 1 if not
 */
int lrprf_aes_print_encfile(lrprf_aes_encfile *encFile);

/* @brief Converts to little endian
 *
 * @param in 32-bit input
 * @return out little endian output
 */
u32 to_little_endian(u32 in);

/* @brief Parse encrypted bitstream to lr-aes and trigger puf key reproduction
 *
 * @param *encFile Pointer to struct
 * @return 0 if successful, 1 if not
 */
int lrprf_aes_load_enc_partial_bitstream(lrprf_aes_encfile *encFile);

/* @brief Parse puf key to lr-aes
 *
 * @return 0 if successful, 1 if not
 */
int lrprf_aes_parse_key(void);

/* @brief Parse payload to be hashed
 *
 * @param *encFile Pointer to struct
 * @param Tag
 * @return 0 if successful, 1 if not
 */
int lraead_calc_hash(lraead_encfile *aead_file, uint8_t *hash);

/* @brief Reads encrypted data file 
 *
 * @param *filePtr Pointer to first position
 * @param *encFile Pointer to struct
 * @return 0 if successful, 1 if not
 */
int lraead_load_encfile(volatile u32 *filePtr, lraead_encfile *aead_file );

/* @brief Parse hash of the image and trigger tag validation
 *
 * @param *aead_file Pointer to struct
 * @return 0 if successful, 1 if not
 */
int lrprf_standalone_load_hash(lraead_encfile *aead_file, uint8_t *hash);

/* @brief Parse encrypted bitstream to lr-aes 
 *
 * @param *aead_file Pointer to struct
 * @return 0 if successful, 1 if not
 */
int lrprf_stream_dec_pr_bit(lraead_encfile *aead_file);

/* @brief Load key to aes core with corresponding mask 
 *
 * @param mask value
 * @return 0 if successful, 1 if not
 */
int lrprf_aes_load_key(uint32_t mask);

/* @brief Print enc file  lraead_streamcipher
 *
 * @param *aead_file Pointer to struct
 * @return 0 if successful, 1 if not
 */

int lraead_print_encfile(lraead_encfile *aead_file);
#endif /* LRPRF_AES_DRIVER_H_ */
