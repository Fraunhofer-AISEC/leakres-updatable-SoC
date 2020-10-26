-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keysched_core is
  port ( encrypt_i : in  std_ulogic;
         idx_i     : in  unsigned(7 downto 0);
         core_i    : in  std_ulogic_vector(31 downto 0);
         core_o    : out std_ulogic_vector(31 downto 0)
  );
end keysched_core;

architecture rtl of keysched_core is

  function rotate(word_i : std_ulogic_vector) return std_ulogic_vector is
    variable res : std_ulogic_vector(31 downto 0);
  begin
    res(7 downto 0)   := word_i(31 downto 24);
    res(15 downto 8)  := word_i(7 downto 0);
    res(23 downto 16) := word_i(15 downto 8);
    res(31 downto 24) := word_i(23 downto 16);
    return res;
  end function rotate;

  type rcon_array_t is array (0 to 15) of std_ulogic_vector(7 downto 0);
  constant rcon_c : rcon_array_t := (X"01", X"02", X"04", X"08", X"10", X"20", X"40", X"80", X"1b", X"36", X"6c", X"d8", X"ab", X"4d", X"9a", X"2f");

  -- canright s-box
  component bSbox port (
    A       : in std_ulogic_vector(7 downto 0);
    encrypt : in std_ulogic;
    Q       : out std_ulogic_vector(7 downto 0)
  );

  end component;

  signal rot_s : std_ulogic_vector(31 downto 0);
  signal sub_s : std_ulogic_vector(31 downto 0);

begin
  rot_s <= rotate(core_i);

  sbox_array : for i in 0 to 3 generate
  begin
    sbox : bSbox port map (
      A => rot_s((((i+1)*8)-1) downto(i*8)),
      encrypt => encrypt_i,
      Q => sub_s((((i+1)*8)-1) downto(i*8))
    );
  end generate;

  core_o <= (sub_s(31 downto 24) xor rcon_c(to_integer(idx_i))) & sub_s(23 downto 0);

end rtl;

