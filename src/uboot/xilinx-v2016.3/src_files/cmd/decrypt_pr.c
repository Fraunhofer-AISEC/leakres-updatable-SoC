/*
 * Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
 * acting on behalf of its Fraunhofer Institute AISEC. 
 * All rights reserved.
*/

#include <common.h>
#include <command.h>
#include <environment.h>
#include <malloc.h>
#include <asm/byteorder.h>
#include <linux/compiler.h>

#include <lrprf_aes_driver.h>
#include <linux/types.h>
/********************************************************/
/* LRPRF_AES_OFB_GMAC vs LRAEAD_STREAMCIPHER                       */
/********************************************************/
#define LRPRF_AES_OFB_GMAC 1 // LRAEAD_ATREAMCIPHER


/********************************************************/
/* Device Configuration Registers                       */
/********************************************************/
#define XDCFG_UNLOCK_DATA		0x757BDF0D // First APB access data
#define XDCFG_BASE_ADDRESS		0xF8007000 // Device Config base
#define XDCFG_UNLOCK_OFFSET		0x00000034 // Unlock Register
#define XDCFG_CTRL_PCAP_MODE_MASK	0x04000000 // Enable PCAP
#define XDCFG_CTRL_OFFSET		0x00000000 // Control Register
#define XDCFG_CTRL_PCAP_PR_MASK		0x08000000 // Enable PCAP for PR

/********************************************************/
/* PR Controller IP Registers                         */
/********************************************************/
#define AISEC_ICAP_CONTROLLER_BASEADDRESS 0x6B060000

#define XPAR_PR_DECOUPLER_0_BASEADDR 0x6B070000 // including xparameters.h did not work

/********************************************************/
/* Debug flags						                    */
/********************************************************/
#define DECPR_DEBUG 0
#define DEBUGAEAD 0

#define decpr_debug_print(fmt, args...) \
        do { if (DECPR_DEBUG) fprintf(stderr, "%s(): " fmt, __func__, ##args); } while (0)

DECLARE_GLOBAL_DATA_PTR;

/**
 * do_decrypt_and_pr() - Handle the "decpr" command-line command
 *
 * Returns zero on success, CMD_RET_USAGE in case of misuse and negative
 * on error.
 */
static int do_decrypt_and_pr(cmd_tbl_t *cmdtp, int flag, int argc, char *const argv[])
{
	char *endp;

	char *env_var = NULL;

	uint32_t *bitfile_ptr, *hd0_ascii_ptr, *hd1_ascii_ptr;
	uint32_t icap_ctrl_state;
	uint32_t check;

	volatile uint32_t *pcap_ctrl_reg = (volatile uint32_t*) (XDCFG_BASE_ADDRESS + XDCFG_CTRL_OFFSET);
	volatile uint32_t *pcap_unlock_reg = (volatile uint32_t*) (XDCFG_BASE_ADDRESS + XDCFG_UNLOCK_OFFSET);
	uint32_t pcap_ctrl_reg_cfg;
	int config_no_pr;
	uint8_t *hash;

	/***************************************/
	/* LRPRF_AES_OFB_GMAC				   */
	/***************************************/

#ifdef LRPRF_AES_OFB_GMAC
	// File types
	printf("Starting LRPRF AES OFB GMAC \n\r");
	lrprf_aes_encfile encFileVar;
	lrprf_aes_encfile *encFile = &encFileVar;

	if (argc != 2){
		printf("Error: Argument count does not match!\n\r");
		return CMD_RET_USAGE;
	}

	// Get first argument (bit_add)
	if (*argv[1] == 0){
		printf("Error: can't process 1st argument!\n\r");
		return CMD_RET_USAGE;
	}
	bitfile_ptr = (uint32_t*) simple_strtoul(argv[1], &endp, 16);
	decpr_debug_print("Passed parameters:\n\r" \
			"                     bitfile addr   = 0x%08x\n\r" , bitfile_ptr);
	//Parse key to LR AES
	if(lrprf_aes_parse_key()){
		printf("Error: Key Reproduction\n\r");
		return 1;
	}

	// load encrypted file
	decpr_debug_print("Load encrypted file\n\r");
	lrprf_aes_load_encfile((uint32_t*)bitfile_ptr, encFile);
#if DECPR_DEBUG
	lrprf_aes_print_encfile(encFile);
#endif

	// Enable ICAP interface

	// Unlock pcap registers
	*pcap_unlock_reg = XDCFG_UNLOCK_DATA;
	// Look up current configuration
	pcap_ctrl_reg_cfg = *pcap_ctrl_reg;
	// Set devcfg.CTRL[PCAP_MODE] (0: TAP, 1: PCAP/ICAP)
	pcap_ctrl_reg_cfg |= XDCFG_CTRL_PCAP_MODE_MASK;
	// Clear devcfg.CTRL[PCAP_PR] (0: ICAP, 1: PCAP)
	pcap_ctrl_reg_cfg &= ~XDCFG_CTRL_PCAP_PR_MASK;
	// Write back configuration
	*pcap_ctrl_reg = pcap_ctrl_reg_cfg;

	// Enable decoupler
	reg_write32(XPAR_PR_DECOUPLER_0_BASEADDR, 1);

	// Decrypt file
	decpr_debug_print("Start decryption and partial reconfiguration\n\r");
	if (lrprf_aes_load_enc_partial_bitstream(encFile)){
		printf("Error: Configuration failed.\n\r");
		decpr_debug_print("       Invalid Tag\n\r");
		return 1;
	} 
	else {
		decpr_debug_print("Configuration successful\n\r");
		// Disable decoupler
		reg_write32(XPAR_PR_DECOUPLER_0_BASEADDR, 0);
		return 0;
	}

	/***************************************/
	/* LRAEAD_STREAMCIPHER				   */
	/***************************************/
#else // LRAEAD_STREAMCIPHER
	// File types
	printf("--- Starting LRAEAD STREAMCIPHER ---\n\r");
	lraead_encfile aead_file_var;
	lraead_encfile *aead_file = &aead_file_var;

	if (argc != 2){
		printf("Error: Argument count does not match!\n\r");
		return CMD_RET_USAGE;
	}

	// Get first argument (bit_add)
	if (*argv[1] == 0){
		printf("Error: can't process 1st argument!\n\r");
		return CMD_RET_USAGE;
	}
	bitfile_ptr = (uint32_t*) simple_strtoul(argv[1], &endp, 16);
	decpr_debug_print("Passed parameters:\n\r" \
			"                     bitfile addr   = 0x%08x\n\r" , bitfile_ptr);
	//Parse encryption key to LRAEAD_STREAMCIPHER
	if(lrprf_aes_load_key(LRPRF_AES_LD_KEY_STANDALONE_MASK)){
		printf("Error: Standalone Key Reproduction\n\r");
		return 1;
	}

	// load encrypted file
	decpr_debug_print("Load encrypted file\n\r");
	lraead_load_encfile((uint32_t*)bitfile_ptr, aead_file);

#ifdef DEBUGAEAD
	// Print encrypted file
	lraead_print_encfile(aead_file);
#endif

	// Compute hash and verify tag in standalone mode
	decpr_debug_print("Start hashing and tag validation\n\r");
	if(lrprf_standalone_load_hash(aead_file, hash)){
		printf("Error: LRPRF AEAD TAG validation failed.\n\r");
		decpr_debug_print("       Invalid Tag\n\r");
		return 1;
	}
	else {
		decpr_debug_print("Hashing and tag computation successful\n\r");
	}
	//
	// Enable ICAP interface

	// Unlock pcap registers
	*pcap_unlock_reg = XDCFG_UNLOCK_DATA;
	// Look up current configuration
	pcap_ctrl_reg_cfg = *pcap_ctrl_reg;
	// Set devcfg.CTRL[PCAP_MODE] (0: TAP, 1: PCAP/ICAP)
	pcap_ctrl_reg_cfg |= XDCFG_CTRL_PCAP_MODE_MASK;
	// Clear devcfg.CTRL[PCAP_PR] (0: ICAP, 1: PCAP)
	pcap_ctrl_reg_cfg &= ~XDCFG_CTRL_PCAP_PR_MASK;
	// Write back configuration
	*pcap_ctrl_reg = pcap_ctrl_reg_cfg;

	// Enable decoupler
	reg_write32(XPAR_PR_DECOUPLER_0_BASEADDR, 1);



	//Parse decryption key to LR AES 
	//Set PRF mode -> Streamcipher
	reg_write32(LRPRF_AES_CTRL_REG, LRPRF_AES_STREAMCIPHER_MASK);
	if(lrprf_aes_load_key(LRPRF_AES_LD_KEY_STREAMCIPHER_MASK)){
		//if(lrprf_aes_parse_key()){
		printf("Error: Streamcipher Key Reproduction\n\r");
		return 1;
	}
	// Decrypt file
	decpr_debug_print("Start decryption and partial reconfiguration\n\r");
	if (lrprf_stream_dec_pr_bit(aead_file)){
		printf("Error: Configuration failed.\n\r");
		return 1;
	} 
	else {
		decpr_debug_print("Configuration successful\n\r");
		// Disable decoupler
		reg_write32(XPAR_PR_DECOUPLER_0_BASEADDR, 0);
		return 0;
	}

#endif
	}

/***************************************************/
#ifdef CONFIG_SYS_LONGHELP
static char decrypt_and_pr_help_text[] =
   "Performs a partial reconfiguration using a lr-aes encrypted\n\r" \
   "bitfile. ICAP is used as configuration interface.\n\r" \
   ":decpr <bit_add> \n\r" \
   "    bit_add    Address to encrypted partial bitfile\n\r";
#endif

U_BOOT_CMD(
   decrypt_pr, 2, 0, do_decrypt_and_pr,
   "Performs decrypttion and partial reconfiguration",
   decrypt_and_pr_help_text
);
