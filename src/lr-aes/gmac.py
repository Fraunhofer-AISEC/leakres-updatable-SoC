#!/usr/bin/python3

from Crypto.Cipher import AES
from Crypto import Random
import itertools
from gfm import gfm

def reverse(x, n):
    result = 0
    for i in range(n):
        if (x >> i) & 1: result |= 1 << (n - 1 - i)
    return result

def _gfm(a, b):
    x = reverse(a, 128)
    y = reverse(b, 128)
    r = 0x100000000000000000000000000000087
    z = 0
    for i in range (0, 127):
        if y & (0x01 << i):
            z = z^x
        x <<= 1
        if x & (0x01 << 128):
            x = x ^ r
    return reverse(z, 128)


def to_hex(b):
    return ''.join(format(x, '02x') for x in b)

def ghash(key, iv, aad, ciphertext, length, verbose=False, h_iv=None):

    aes_ecb = AES.new(key, AES.MODE_ECB)
    if (h_iv == None):
        h = aes_ecb.encrypt(bytes(bytearray.fromhex('00000000000000000000000000000000')))
    else:
        h = aes_ecb.encrypt(bytes(h_iv))
    x = 0
    if (verbose):
        print('\r\nCalculating GHASH')
        print('h:     ' + to_hex(h))
        print("state: %0.32x" % x)
    enc_iv = aes_ecb.encrypt(iv)
    for item in itertools.chain(aad, ciphertext):
        op_a = x^int(to_hex(item), 16)
        x = gfm(x^int(to_hex(item), 16), int(to_hex(h), 16))
        if (verbose):
            print('\r\ninput: ' + to_hex(item))
            print('op_a : %0.32x' % + op_a)
            print('op_b : %0.32x' % + int(to_hex(h), 16))
            print("state: %0.32x" % x)

    x = gfm(x^int(to_hex(length), 16), int(to_hex(h), 16))
    tag = x^int(to_hex(enc_iv), 16)
    if (verbose):
        print('\r\nlen:   ' + to_hex(length))
        print("state: %0.32x" % x)
        print("\r\ntag:   %0.32x" % tag)
    return tag
