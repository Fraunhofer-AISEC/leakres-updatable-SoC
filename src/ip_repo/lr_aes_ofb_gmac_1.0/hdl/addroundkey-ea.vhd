-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity addroundkey is
  port ( key_i         : in  std_ulogic_vector(127 downto 0);
         addroundkey_i : in  std_ulogic_vector(127 downto 0);
         addroundkey_o : out std_ulogic_vector(127 downto 0)
  );
end addroundkey;

architecture rtl of addroundkey is

begin
  addroundkey_o <= addroundkey_i xor key_i;
end rtl;

