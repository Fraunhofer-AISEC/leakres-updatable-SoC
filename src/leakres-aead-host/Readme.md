# Leakage Resilient Authenticated Encryption 

This tool implements the LR-AEAD encryption scheme which is evaluated in "Retrofitting leakage resilience as side-channel protection to microcontrollers".
It uses the LR-PRF described in [Towards Super-Exponential Side-Channel Security with Efficient Leakage-Resilient PRFs](https://link.springer.com/chapter/10.1007%2F978-3-642-33027-8_12)
in the FHGF' construction described in [Sponges Resist Leakage: The Case of Authenticated Encryption](https://link.springer.com/chapter/10.1007%2F978-3-030-34621-8_8).

The inputs are provided as binary files and the output is printed to stdout in
the format of a C include file.
The purpose of this tool is to generate an encrypted image which can be included
in the microcontroller code for evaluation on the target platforms.

# Build

Building links against the mbedtls library which is included as submodule.
To build the library run (required once):

```bash
make mbedtls
```

then, to (re-)build the tool
```bash
make
```

# Usage

```bash
./lraead_gen_testvector adata_filename message_filename key_filename nonce_filename [data_complexity]
```

| Parameter        | Description                                                                      |
|------------------| ---------------------------------------------------------------------------------|
| adata_filename   | associated data (AD), can be empty or arbitrary length                           |
| message_filename | message that is encrypted, arbitrary length                                      |
| key_filename     | contains encryption and MAC key, both 16 bytes                                   |
| nonce_filename   | 16 byte nonce                                                                    |
| data_complexity  | optional, sets data complexity for the LR-PRF. Can be 2, 4, 16, 256. Default: 2. |


# Example

Example files are located under /example.

To generate an include file with AD:
```bash
	./tests/lraead_test examples/adata.bin ../../images/p_c01.bin examples/keys.bin examples/nonce.bin ../../sdcard/p_c01_enc.bin
```

To generate an include file without AD:
```bash
	./tests/lraead_test examples/empty.bin ../../images/p_c01.bin examples/keys.bin examples/nonce.bin ../../sdcard/p_c01_enc.bin
```
