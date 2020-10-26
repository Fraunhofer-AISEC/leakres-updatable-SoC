# SCA Secure and Updatable Crypto Engines for FPGA SoC Bitstream Decryption


SCA Secure and Updatable Crypto Engines for FPGA SoC Bitstream Decryption is vendor agnostic and fully updatable mechanism to securely configure the FPGA logic starting from power-up until the whole system is booted and running.
This is done using a leakage resilient AEAD, PUF and dynamic partial reconfiguration.

This repository is part of the paper "SCA Secure and Updatable Crypto Engines for FPGA SoC Bitstream Decryption", which was presented presented at [ASHES 2019](https://dl.acm.org/doi/10.1145/3338508.3359573) 
and an extended version is also to be published in [Journal of Cryptographic Engineering](https://www.springer.com/journal/13389).\
This is a joint collaboration between [Fraunhofer AISEC](https://www.aisec.fraunhofer.de/) and [CSIT, Queens University Belfast](https://www.qub.ac.uk/ecit/CSIT/)

## Dependencies
This repository provides a prototype implementation only for the Zedboard Rev. D consisting of a Xilinx Zynq 7000 FPGA SoC.

The AXI wrappers for the following IP cores were generated using Vivado 2017.2.
- led_driver_axi
- lr_aes_ofb_gmac
- pr_controller
- lraead_streamcipher


The s-boxes for the AES core uses the [Canright implementation](https://calhoun.nps.edu/bitstream/handle/10945/791/NPS-MA-04-001.pdf?sequence=1&isAllowed=y)

The [PUF module imported from by Queens University belfast](https://innersource.qub.ac.uk/opensource/fuzzy-key-commitment).\
In this project the key is hard-coded and hence does not include a PUF key enrollment process.

[MbedTLS](https://github.com/ARMmbed/mbedtls) is imported as submodule to this project. 
It is used to generate encrypted partial bitstreams for the lraead_streamcipher.
### Disclaimer
Please note that this repository contains no production code and is a prototype implementation for the Zedboard Rev. D.
The debug ports are still available e.g., the key reproduced by the PUF can be read-out via AXI, the PUF is not locked after key reproduction, following decryption the bitstream can be readback via AXI.

## Project build description

### 1. Requirements
   - Zedboard Rev D
   - Vivado Version: 2017.2
   - GNU Make 4.1
   - GNU patch 2.7.5
   - Minicom
 
### 2. Build instructions
```
   make all     Generates all components to enroll a new key
                (see make ip hard, make enroll)

   make ip      Generates AXI IP cores.

   make hard    Generates the hardware configuration only
                  > Creates a new vivado project
                  > Sets up the system
                  > Creates the PL bitstream
                  > Creates all parital bitstreams
                Note: in the Makefile set "IP_core" to one of the two side-channel
                hardened decryption cores. Default setting is LRAES_OFB_GMAC
                IP_CORE = LRAES_OFB_GMAC/LRAEAD_STREAMCIPHER

   make enroll  This target generates the softwre binaries and boot image
                to enroll a key to a device
                (With every new target and bitstream a key enrollment
                process must be repeated.)

   make soft    Builds FSBL and U-Boot. (to run this command, 'make hard' must
                have been executed before)
                  > Clones u-boot-xlnx
                  > Copies u-boot  patch
                  > Builds u-boot (NOTE: DTC must be successfully installed before building u-boot)
                  > Creates XSDK project (Board Support Package and FSBL)
                  > Build BSP and FSBL
                NOTE: Prior to running this target set  the follwoing: 
                1. Flag in src/uboot/xilinx-v2016.3/src_files/cmd/decrypt_pr.c 
                to be built drivers corresponding to the side-channel hardened
                decryption cores. Default setting is LRAES_OFB_GMAC.
                2. Include the helper data generated in the previous step (enroll)
                in src/fsbl/fkc_reproduction.c

   make  post   Builds boot images for key reproduction and enrollment.

   make encrypt-bitstreams
                Encrypts the partial bitstream using the PUF key and
                LRPRF AES OFB GMAC. For this the two key files are expected
                to be present in the sdcard folder

    Encrypting binaries using LR AEAD OFB GMAC
    -----------------------
	The pyhton file in src/lraes/ui-lrprf_ofb_gmac.py is used to encrypt the partial bitstreams
	python3 ui-lrprf_ofb_gmac.py
	Usage:
	ui-lrprf_ofb_gmac.py --key0=<key_filename> --key1=<key_filename> --ptxt=<ptxt_filename> --ctxt=<ctxt_filename> [--iv=<iv_filename>] [--aad=<aad_filename>] [--bl=<block_length] [--decrypt] [--verbose] [--force]

    Encrypting binaries using LR AEAD STREAM CIPHER
    -----------------------
	The encryption script and license can be found at src/leakres-aead-host/

	Usage:
	./tests/lraead_test <aadfile.bin> <msg.bin> <key.bin> <nonce.bin> <ctxt.bin>
	Note: For this set-up the AAD (if present) and Payload must be multiples of 16.

    Running the sample project
    ----------------------
	1. Run:
		> make key-enroll
	2. Copy BOOT_enroll.BIN to an SD Card and rename it to BOOT.BIN
	3. Set Zedboard bootstrap pins to SD card boot mode
	4. Turn on board and connect to serial terminal
	5. Copy the generated helper data to src/fsbl/fkc_reproduction.c
	6. Copy key files to the sdcard/ folder in case of LRPRF_OFB_GMAC
	7. Run:
		> make key-reproduction
	8. In case of LRAEAD_STREAMCIPHER follow build instructions in src/leakres-aead-host/Readme.md to encrypt the partial bitstreams
	9. Copy Boot.bin, p_c00_enc.bin, p_c01_enc.bin, p_c02_enc.bin from the sdcard folder to an SD Card
	10. Expected serial output is listed below

	RSA signature check
	----------------------
	In order to enable the Xilinx RSA and blow the efuses on the Zynq 7000
	follow the application note XAPP1175 from Xilinx.
```
## Expected serial console output. Config 115200/8-N-1
```

	----------------------------------
	--  Secure Update Demonstrator  --
	----------------------------------
	Main menu:
	  0: secure update of partial reconfiguration
	  1: exit
	(Enter option to be run): 0

	Enter partial configuration to be loaded (0-3)
	  0: partial bitstream 0
	  1: partial bitstream 1
	  2: partial bitstream 2
	  3: blank bitstream
	  4: exit demo
	(Enter Config to be loaded): 1
	Loading encrypted partial configuration 1
	reading p_c01_enc.bin
	210688 bytes read in 61 ms (3.3 MiB/s)
	Starting LRPRF AES OFB GMAC
	Configuration of partial bitstream successful

	Enter partial configuration to be loaded (0-3)
	  0: partial bitstream 0
	  1: partial bitstream 1
	  2: partial bitstream 2
	  3: blank bitstream
	  4: exit demo
	(Enter Config to be loaded): 4
	Exit to terminal...

	The LEDs are reconfigured based on the loaded configuration:
	Option 0: No LEDs are turned on
	Option 1: LD0 (T22) is turned on
	Option 2: LD1 (T21) is turned on
	Option 3: Reconfigurable module is cleared
	(No LEDs are turned on)
```
