-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package global is


  -- irreducible polynomial for GF multiplier used in GHASH function
  -- p(x) = x^128 + x^7 + x^2 + x + 1
  constant m_c  : integer := 128;
  constant k3_c : integer := 7;
  constant k2_c : integer := 2;
  constant k1_c : integer := 1;
  constant irred_poly_c : std_ulogic_vector(128 downto 0) := (m_c    => '1',
                                                              k3_c   => '1',
                                                              k2_c   => '1',
                                                              K1_c   => '1',
                                                              0      => '1',
                                                              others => '0');
  constant degree_c : integer := 128;

  function bit_reflect (a: in std_ulogic_vector)return std_ulogic_vector;

end global;

package body global is

  function bit_reflect (a: in std_ulogic_vector)return std_ulogic_vector is
    variable result: std_ulogic_vector(a'RANGE);
    alias aa: std_ulogic_vector(a'REVERSE_RANGE) is a;
  begin
    for i in aa'RANGE loop
      result(i) := aa(i);
    end loop;
    return result;
  end;

end global;
