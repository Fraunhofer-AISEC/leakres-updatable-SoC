-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity subbytes is
  port (
    subbytes_i  : in  std_ulogic_vector (127 downto 0);
    subbytes_o  : out std_ulogic_vector (127 downto 0);
    encrypt_i   : in  std_ulogic
  );
end subbytes;



architecture rtl of subbytes is

  -- canright s-box
  component bSbox port (
    A       : in std_ulogic_vector(7 downto 0);
    encrypt : in std_ulogic;
    Q       : out std_ulogic_vector(7 downto 0)
  );
  end component;

begin

  sbox_array : for i in 0 to 15 generate
  begin
    sbox : bSbox port map (
      A => subbytes_i((((i+1)*8)-1) downto(i*8)),
      encrypt => encrypt_i,
      Q => subbytes_o((((i+1)*8)-1) downto(i*8))
    );
  end generate;

end rtl;

