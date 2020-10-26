-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity column_mult is
  port (col_i     : in  std_ulogic_vector (31 downto 0);
        col_o     : out std_ulogic_vector (31 downto 0);
        encrypt_i : in std_ulogic
        );
end column_mult;

architecture rtl of column_mult is
  signal a0   : std_ulogic_vector(7 downto 0);
  signal a0x2 : std_ulogic_vector(7 downto 0);
  signal a0x3 : std_ulogic_vector(7 downto 0);
  signal a1   : std_ulogic_vector(7 downto 0);
  signal a1x2 : std_ulogic_vector(7 downto 0);
  signal a1x3 : std_ulogic_vector(7 downto 0);
  signal a2   : std_ulogic_vector(7 downto 0);
  signal a2x2 : std_ulogic_vector(7 downto 0);
  signal a2x3 : std_ulogic_vector(7 downto 0);
  signal a3   : std_ulogic_vector(7 downto 0);
  signal a3x2 : std_ulogic_vector(7 downto 0);
  signal a3x3 : std_ulogic_vector(7 downto 0);

  signal res0 : std_ulogic_vector(7 downto 0);
  signal res1 : std_ulogic_vector(7 downto 0);
  signal res2 : std_ulogic_vector(7 downto 0);
  signal res3 : std_ulogic_vector(7 downto 0);

begin

  -- split into columns
  a0 <= col_i(31 downto 24);
  a1 <= col_i(23 downto 16);
  a2 <= col_i(15 downto 8);
  a3 <= col_i(7 downto 0);

  -- multiply by 2
  a0x2 <= (a0(6 downto 0) & '0') xor X"1B" when a0(7) = '1'
          else a0(6 downto 0) & '0';
  a1x2 <= (a1(6 downto 0) & '0') xor X"1B" when a1(7) = '1'
         else a1(6 downto 0) & '0';
  a2x2 <= (a2(6 downto 0) & '0') xor X"1B" when a2(7) = '1'
         else a2(6 downto 0) & '0';
  a3x2 <= (a3(6 downto 0) & '0') xor X"1B" when a3(7) = '1'
          else a3(6 downto 0) & '0';

  -- multiply by 3
  a0x3 <= a0x2 xor a0;
  a1x3 <= a1x2 xor a1;
  a2x3 <= a2x2 xor a2;
  a3x3 <= a3x2 xor a3;

  -- assemble result of matrix multiplication
  res0 <= a0x2 xor a1x3 xor a2 xor a3;
  res1 <= a1x2 xor a2x3 xor a3 xor a0;
  res2 <= a2x2 xor a3x3 xor a0 xor a1;
  res3 <= a3x2 xor a0x3 xor a1 xor a2;

  -- recombine rows
  col_o <= res0 & res1 & res2 & res3;

end rtl;
