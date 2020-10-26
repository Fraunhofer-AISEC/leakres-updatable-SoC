#!/usr/bin/python3
###############################################################################
# Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V. 
# acting on behalf of its Fraunhofer Institute AISEC. 
# All rights reserved.
###############################################################################
"""Usage:
   ui-lrprf_ofb_gmac.py --key0=<key_filename> --key1=<key_filename> --ptxt=<ptxt_filename> --ctxt=<ctxt_filename> [--iv=<iv_filename>] [--aad=<aad_filename>] [--bl=<block_length] [--decrypt] [--verbose] [--force]

   Encrypts a file using the unkwnown-inputs leakage resilient PRF together with AES-OFB mode
   and generates a GMAC tag. The tag is appended to the output. Optionally includes additional authenticated data (aad).
   In encryption mode (default), the <ptxt_filename> and <aad _filename> are read and the result is written to <ctxt_filename>.
   In decryption mode, <ctxt_filename> is read and <ptxt_filename> and (if aad is included) <aad _filename> are written.
   For encrytption, the IVs must be provided via <iv_filename>, for decryption it is read from <ctxt_filename>.
   Keys and IVs are read from file and expected to be formatted as ASCII encoded hex values.
   In the IV file, the IVgmac is expected first (128 bits), followed by the 96 bit nonce part of the IV for the encryption.
   The counter of the encryption IV is added by the software.

   The format of the encrypted file is:
      Field                               Length
      ------------------------------------------
      1.  Payload block count            8 Bytes
      2.  Payload block length in byte   8 Bytes
      3.  Last block length in byte      8 Bytes
      4.  IV_gmac                       16 Bytes
      5.  IV                            16 Bytes
      6.  Length of AAd in bits          8 Bytes
      7.  AAD (padded to 128 bit)      var
      9.  Payload block 0               bl Bytes
      10.  Tag Payload block 0           16 Bytes
      ...
      11. Payload block bc-1            bl Bytes
      12. Tag Payload block bc-1        16 Bytes

   Options:
     -h, --help
     -d, --decrypt  Decrypt file, default is encryption
     -v, --verbose  Print debug information

"""
#     -k, --key  Read key from file, formatted as ASCII encoded hex values
#     -a, --ad   Additional authenticated data (is assumed to be full length)


from Crypto.Cipher import AES
from Crypto import Random
import binascii
import sys
import os
from math import ceil
from docopt import docopt
from gmac import ghash

global verbose
global m

global pad_word # 32 bit NOP padding for ICAP
pad_word = bytearray([0x20, 0x00, 0x00, 0x00])

m = 1
verbose = False

def to_hex(b):
    return ''.join(format(x, '02x') for x in b)

def _find_getch():
    try:
        import termios
    except ImportError:
        # Non-POSIX. Return msvcrt's (Windows') getch.
        import msvcrt
        return msvcrt.getch

    # POSIX system. Create and return a getch that manipulates the tty.
    import sys, tty
    def _getch():
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return ch

    return _getch

getch = _find_getch()

# takes iv and m and creates list of carefully chosen inputs for the PRF tree
def split_iv(iv, m):
    if m == 1:
        mask = 0x01
    elif m == 2:
        mask = 0x03
    elif m == 4:
        mask = 0x0f
    elif m == 8:
        mask = 0xff
    else:
        raise ValueError('split value %d not supported' % m)

    int_iv = int(to_hex(iv), 16)
    res = list(range(0,int(128/m)))
    for i in res:
        res[i] = 0x00000000000000000000000000000000
    for j in range(int(128/m)-1, -1, -1):
        for i in range(0, int(128/m)):
            tmp = (((mask << j*m) & int_iv) >> j*m) << i*m
            res[int(128/m)-1-j] |= tmp
    print(res)
    return res

def two_prg(key, p0, p1, verbose=False):
    aes = AES.new(key, AES.MODE_ECB)
    res = (aes.encrypt(p0), aes.encrypt(p1))
    if (verbose):
            print('\r\n2PRG:')
            print('key:')
            print('>', to_hex(key))
            print('in:')
            print('>', to_hex(p0))
            print('>', to_hex(p1))
            print('out:')
            print('<', to_hex(res[0]))
            print('<', to_hex(res[1]), '\r\n')
    return res

# unknown inputs leakage-resilient PRF
def ui_lr_prf(keys, x, verbose=False):
    p0 = bytes([0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0])
    p1 = bytes([255,255,255,255,255,255,255,255, 255,255,255,255,255,255,255,255])
    (ps0, ps1) = two_prg(keys[0], p0, p1, verbose)

    key = keys[1]
    if (verbose):
            print('\r\nLR-PRF:')
            print('key:')
            print('>', to_hex(key))
            print('input:')
            print('>', to_hex(x))
    int_x = int(to_hex(x), 16)
    cci = []
    for j in range(128-1, -1, -1):
        bit = (((0x01 << j) & int_x) >> j)
        if (bit == 0):
            cci.append(ps0)
        else:
            cci.append(ps1)
    i = 0
    for ptxt in cci:
        if (verbose):
            print('round', i)
            print(">", to_hex(ptxt))
        i = i+1
        aes = AES.new(key, AES.MODE_ECB)
        key = aes.encrypt(ptxt);
        if (verbose):
            print("<", to_hex(key))
    return key


def parse_bytearray_from_file(fn, bitlen):
    with open(fn, 'r') as datafile:
        datastring = datafile.read()
    # remove spaces, newlines, tabs
    datastring = ''.join(datastring.split())
    if (len(datastring) != bitlen/4):
        print('Invalid length (should be ' + str(bitlen) +  ' Bit)')
        sys.exit(-1)
    return bytearray(binascii.unhexlify(datastring))

def int_to_bytearray(i, len):
    return bytearray(i.to_bytes(len, byteorder='big'))


def split_to_list(d, chunksize):
    l = []
    if (len(d)%chunksize != 0):
        print('Error: data is not aligned to chunksize')
        sys.exit(-1)
    for i in range(int(len(d)/chunksize)):
        l.append(d[i*chunksize:(i+1)*chunksize])
    return l

# creates and writes the output file
def encrypt(ptxt_fn, adata_fn, ctxt_fn, key, iv_gmac, iv, block_len):
    global pad_word

    print('Encrypting: ' + ptxt_fn + '\r\nTo: ' + ctxt_fn)
    print('AAD: ' + str(adata_fn))
    if (os.path.isfile(ctxt_fn)):
        if (args['--force'] == False):
            print(str(ctxt_fn) + ' exists. Press [y] to overwrite')
            if (getch() != 'y'):
                print('Aborted')
                sys.exit(0)

    keys = split_to_list(bytes(key), 16)

    # create and open output file
    with open(ctxt_fn, 'wb') as of:
        # get payload length
        ptxt_len = os.path.getsize(ptxt_fn)
        block_count = ceil(ptxt_len / block_len)
        last_block_len = ptxt_len % block_len
        if (last_block_len % 4 != 0):
            print('Error: payload is not a mutliple of 32 Bit words')
            sys.exit(-1)

        if (last_block_len == 0):
            # last block is full block
            last_block_len = block_len

        if (verbose):
            print('length of last block before padding: ' + str(last_block_len))
        # calculate length of last block after padding to 128 bit:
        if (last_block_len % 16 != 0):
            last_block_len = last_block_len + (16 - (last_block_len%16))

        if (verbose):
            print('length of last block after padding: ' + str(last_block_len))


        if (verbose):
            print('Payload length: ' + str(ptxt_len))
            print('Block count:    ' + str(block_count))

        # write block count
        of.write(int_to_bytearray(block_count, 8))

        # write block length
        of.write(int_to_bytearray(block_len, 8))

        # write last block length
        of.write(int_to_bytearray(last_block_len, 8))

        # write IV_gmac
        of.write(iv_gmac)

        # write IV
        of.write(iv)

        # AAD length
        if (adata_fn != None):
            aad_len = os.path.getsize(adata_fn)
        else:
            aad_len = 0
        of.write(int_to_bytearray(aad_len*8, 8))

        # AAD
        if (adata_fn != None):
            with open(adata_fn, 'rb') as af:
                adata = bytearray(af.read())
            # fill up 128 bit block
            if (aad_len%16 != 0):
                for i in range(16-aad_len%16):
                    adata.append(0)
            of.write(adata)


        with open(ptxt_fn, 'rb') as pf:
            ptxt = bytearray(pf.read())
            # fill up 128 bit block
            while (len(ptxt)%16 != 0):
                ptxt += pad_word
        ptxt = bytes(ptxt)

        # loop over all payload blocks
        for i in range(block_count):

            # build IV
            iv = bytes(bytearray(iv[0:12]) + int_to_bytearray(i,4))
           # print('\r\nprocessing block ' + str(i))
           # print('IV:' )
           # print(to_hex(iv))
            if (verbose):
                print('\r\nprocessing block ' + str(i))
                print('IV:' )
                print(to_hex(iv))

            # calculate IV_h
            # LR INITIALIZATION
            iv_h = ui_lr_prf(keys, iv)
            if (verbose):
                print('')
                print("iv_h:")
                print(to_hex(iv_h))

            aes_ecb = AES.new(keys[1], AES.MODE_ECB)
            enc_iv_h = aes_ecb.encrypt(iv_h)
            if (verbose):
                print("enc_iv_h:")
                print(to_hex(enc_iv_h))



            # AES-OFB encryption
            aes_ofb = AES.new(keys[1], AES.MODE_OFB, enc_iv_h)
            ctxt = aes_ofb.encrypt(ptxt[i*block_len:(i+1)*block_len])

            # write payload
            of.write(ctxt)

            # calculate tag, use last_block_len if last block is partial block
            if (i == block_count-1):
                length = bytes(int_to_bytearray(aad_len*8, 8)+(int_to_bytearray(last_block_len*8, 8)))
            else:
                length = bytes(int_to_bytearray(aad_len*8, 8)+(int_to_bytearray(block_len*8, 8)))

            # ghash expects lists of 16 byte chunks
            if (adata_fn != None):
                adata = split_to_list(adata, 16)
            else:
                adata = []
            ctxt  = split_to_list(ctxt, 16)

            h = ui_lr_prf(keys, iv_gmac, verbose)
            if (verbose):
                print('')
                print("h_iv:")
                print(to_hex(h))

            tag = ghash(keys[1], iv_h, adata, ctxt, length, verbose, h)
            tag = int_to_bytearray(tag, 16)
            of.write(tag)
            if (verbose):
                print('length for tag generation:')
                print(to_hex(length))
                print('tag:')
                print(to_hex(tag))

            # set adata to None so it is only processed w/ first block
            adata_fn = None
            aad_len = 0

    print('*** Success ***')
    return

def decrypt(ptxt_fn, adata_fn, ctxt_fn, key):

    print('Decrypting: ' + ctxt_fn + '\r\nTo: ' + ptxt_fn)
    if (os.path.isfile(ptxt_fn)):
        if (args['--force'] == False):
            print(str(ptxt_fn) + ' exists. Press [y] to overwrite')
            if (getch() != 'y'):
                print('Aborted')
                sys.exit(0)

    keys = split_to_list(bytes(key), 16)

    # create and open output file
    with open(ctxt_fn, 'rb') as cf:
        # block count
        block_count = cf.read(8)
        block_count = int.from_bytes(block_count, byteorder='big')
        if (verbose):
            print('Block count:')
            print(block_count)

        # block length
        block_len = cf.read(8)
        #convert to byte count
        block_len = int.from_bytes(block_len, byteorder='big')
        if (verbose):
            print('Block length:')
            print(block_len)

        # last block length
        last_block_len = cf.read(8)
        #convert to byte count
        last_block_len = int.from_bytes(last_block_len, byteorder='big')
        if (verbose):
            print('Last block length:')
            print(last_block_len)

        # read IV_gmac
        iv_gmac = cf.read(16)

        # read IV
        iv = cf.read(16)

        # AAD length
        aad_len = cf.read(8)
        #convert to byte count
        aad_len = int(int.from_bytes(aad_len, byteorder='big')/8)
        if (verbose):
            print('AAD length:')
            print(aad_len)

        if (aad_len > 0):
            if (adata_fn == None):
                print('Found AAD, parameter --aad is required')
                sys.exit(0)
            if (aad_len%16 != 0):
                aad_pad_len = 16-aad_len%16
            else:
                aad_pad_len = 0
            adata = cf.read(aad_len + aad_pad_len)
            if (os.path.isfile(adata_fn)):
                if (args['--force'] == False):
                    print(str(adata_fn) + ' exists. Press [y] to overwrite')
                    if (getch() != 'y'):
                        print('Aborted')
                        sys.exit(0)

        # open ptxt file
        with open(ptxt_fn, 'wb') as pf:
            # loop over all payload blocks
            for i in range(block_count):

                # build IV
                iv = bytes(bytearray(iv[0:12]) + int_to_bytearray(i,4))
                if (verbose):
                    print('\r\nprocessing block ' + str(i))
                    print('IV:' )
                    print(to_hex(iv))

                # calculate IV_h
                # LR INITIALIZATION
                iv_h = ui_lr_prf(keys, iv)
                if (verbose):
                    print('')
                    print("iv_h:")
                    print(to_hex(iv_h))

                aes_ecb = AES.new(keys[1], AES.MODE_ECB)
                enc_iv_h = aes_ecb.encrypt(iv_h)
                if (verbose):
                    print("enc_iv_h:")
                    print(to_hex(enc_iv_h))

                if (i == block_count-1):
                    # read potentially partial block
                    ctxt_len = last_block_len
                    # fill up 128 bit block
                    if (ctxt_len%16 != 0):
                        print('Error: last ciphertext block is not a multiple of 128 bits')
                        sys.exit(-1)
                    ctxt =  cf.read(ctxt_len)
                else:
                    # read full block
                    ctxt_len = block_len
                    ctxt  = cf.read(ctxt_len)

                # AES-OFB encryption
                aes_ofb = AES.new(keys[1], AES.MODE_OFB, enc_iv_h)
                ptxt = aes_ofb.decrypt(ctxt)[0:ctxt_len]

                # read tag
                read_tag = bytearray(cf.read(16))

                # calculate tag
                length = bytes(int_to_bytearray(aad_len*8, 8)+(int_to_bytearray(ctxt_len*8, 8)))

                # ghash expects lists of 16 byte chunks
                if (aad_len > 0):
                    adata_list = split_to_list(adata, 16)
                else:
                    adata_list = []
                ctxt  = split_to_list(ctxt, 16)

                # generate hash key h
                h = ui_lr_prf(keys, iv_gmac, verbose)
                if (verbose):
                    print('IV_gmac:' )
                    print(to_hex(iv_gmac))
                    print('')
                    print("h_iv:")
                    print(to_hex(h))


                tag = ghash(keys[1], iv_h, adata_list, ctxt, length, verbose, h)
                tag = int_to_bytearray(tag, 16)

                if (verbose):
                    print('length for tag generation:')
                    print(to_hex(length))
                    print('tag:')
                    print(to_hex(tag))

                # compare tags:
                if (read_tag != tag):
                    print('Error: Tag is not correct')
                    sys.exit(-1)
                else:
                    print('Tag is correct')

                # write adata
                if (aad_len > 0):
                    print('Writing AAD')
                    with open(adata_fn, 'wb') as af:
                        af.write(adata[0:aad_len])

                pf.write(ptxt)

                aad_len = 0

    print('*** Success ***')
    return


if __name__ == "__main__":
    args = docopt(__doc__)

    if (args['--verbose'] == True):
        verbose = True

    ptxt_fn = args['--ptxt']
    ctxt_fn = args['--ctxt']
    if (args['--aad'] != None):
        adata_fn = args['--aad']
    else:
        adata_fn = None

    if (verbose):
        print('Debug outputs enabled')

    if (args['--key0']== None):
        print('Key0 is required')
        sys.exit(0)
    else:
        key0 = parse_bytearray_from_file(args['--key0'], 128)
        key = key0 
    if (args['--key1']== None):
        print('Key1 is required')
        sys.exit(0)
    else:
        key1 = parse_bytearray_from_file(args['--key1'], 128)
        key += key1
#    key = parse_bytearray_from_file(args['--key'], 256)
    print('\r\nKey:\r\n' + str(binascii.hexlify(key)))

    if (args['--decrypt'] == True):
        decrypt(ptxt_fn, adata_fn, ctxt_fn, key)
    else:
        if (args['--iv'] == None):
            print('--iv parameter is required for encryption')
            sys.exit(0)
        print('IVs:')
        iv = parse_bytearray_from_file(args['--iv'], 224)
        iv_gmac = bytearray(iv[:16])
        iv = bytearray(iv[16:])+bytearray([0,0,0,0])
        print('IV_gmac:\r\n' + str(binascii.hexlify(iv_gmac)))
        print('IV:\r\n' + str(binascii.hexlify(iv)))
        if (args['--bl'] != None):
            block_len = int(args['--bl'])
            if (verbose):
                print('Setting payload block length to ' + str(block_len))
        else:
            block_len = 2048
            if (verbose):
                print('Setting payload block length to default value (' + str(block_len) + ')')
        encrypt(ptxt_fn, adata_fn, ctxt_fn, key, iv_gmac, iv, block_len)
