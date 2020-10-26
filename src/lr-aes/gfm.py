#!/usr/bin/python3

from functools import reduce
import sys
# constants used in the multGF2 function
mask1 = mask2 = polyred = None

def setGF2(degree, irPoly):
    """Define parameters of binary finite field GF(2^m)/g(x)
       - degree: extension degree of binary field
       - irPoly: coefficients of irreducible polynomial g(x)
    """
    def i2P(sInt):
        """Convert an integer into a polynomial"""
        return [(sInt >> i) & 1
                for i in reversed(range(sInt.bit_length()))]    
    
    global mask1, mask2, polyred
    mask1 = mask2 = 1 << degree
    mask2 -= 1
    polyred = reduce(lambda x, y: (x << 1) + y, i2P(irPoly)[1:])
        
def multGF2(p1, p2):
    """Multiply two polynomials in GF(2^m)/g(x)"""
    p = 0
    while p2:
        if p2 & 1:
            p ^= p1
        p1 <<= 1
        if p1 & mask1:
            p1 ^= polyred
        p2 >>= 1
    return p & mask2


def reverse(x, n):
    result = 0
    for i in range(n):
        if (x >> i) & 1: result |= 1 << (n - 1 - i)
    return result

def gfm(x, y):
    setGF2(128, 0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000111)
    return reverse(multGF2(reverse(x,128), reverse(y,128)),128)

if __name__ == "__main__":
  
    # Define binary field GF(2^3)/x^3 + x + 1
    setGF2(128, 0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000111)
    # Evaluate the product (x^2 + x + 1)(x^2 + 1)
    #print("{:032x}".format(multGF2(0x42831ec2217774244b7221b784d0d49c, 0xb83b533708bf535d0aa6e52980d53b78)))
    #print("{:032x}".format(multGF2(reverse(0x42831ec2217774244b7221b784d0d49c,128), reverse(0xb83b533708bf535d0aa6e52980d53b78,128))))


    x = int(sys.argv[1], 16)
    y = int(sys.argv[2], 16)
#    print("{:032x}".format(reverse(multGF2(reverse(0x42831ec2217774244b7221b784d0d49c,128), reverse(0xb83b533708bf535d0aa6e52980d53b78,128)),128)))
    print("{:032x}".format(reverse(multGF2(reverse(x,128), reverse(y,128)),128)))
    
    # Define binary field GF(2^8)/x^8 + x^4 + x^3 + x + 1
    # (used in the Advanced Encryption Standard-AES)
#    setGF2(8, 0b100011011)
    
    # Evaluate the product (x^7)(x^7 + x + 1)
#    print("{:02x}".format(multGF2(0b10000000, 0b10000011)))
