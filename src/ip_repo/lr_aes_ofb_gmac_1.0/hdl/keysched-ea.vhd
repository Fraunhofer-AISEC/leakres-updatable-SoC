-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keysched is
  port ( clk_i      : in  std_ulogic;
         rst_i      : in  std_ulogic;
         encrypt_i  : in  std_ulogic;
         start_i    : in  std_ulogic;
         key_we_i   : in  std_ulogic;
         rnd_cnt_i  : in  unsigned(7 downto 0);
         key_i      : in  std_ulogic_vector(127 downto 0);
         roundkey_o : out std_ulogic_vector(127 downto 0)
  );
end keysched;

architecture rtl of keysched is

  component keysched_core  port (
    encrypt_i : in  std_ulogic;
    idx_i     : in  unsigned(7 downto 0);
    core_i    : in  std_ulogic_vector(31 downto 0);
    core_o    : out std_ulogic_vector(31 downto 0)
  );
  end component;

  signal key_r  : std_ulogic_vector(127 downto 0);
  signal key_s  : std_ulogic_vector(127 downto 0);

  signal col0_s : std_ulogic_vector(31 downto 0);
  signal col1_s : std_ulogic_vector(31 downto 0);
  signal col2_s : std_ulogic_vector(31 downto 0);
  signal col3_s : std_ulogic_vector(31 downto 0);

  signal col3_core_s : std_ulogic_vector(31 downto 0);

  signal col0_next_s : std_ulogic_vector(31 downto 0);
  signal col1_next_s : std_ulogic_vector(31 downto 0);
  signal col2_next_s : std_ulogic_vector(31 downto 0);
  signal col3_next_s : std_ulogic_vector(31 downto 0);


begin

  -- schedule core function: rotate and xor rcon(round count)
  keysched_core0 : keysched_core port map(
    encrypt_i => encrypt_i,
    idx_i     => rnd_cnt_i,
    core_i    => col3_s,
    core_o    => col3_core_s
  );

  -- key register
  keysched_p : process(clk_i)
  begin
    if (clk_i'event and clk_i = '1') then
      if rst_i = '1' then
        key_r <= (others => '0');
      elsif key_we_i = '1' then
        key_r <= key_i;
      elsif rnd_cnt_i < 11 or start_i = '1' then
        key_r <= key_s;
      end if;
    end if;
  end process;

  -- split into columns
  col0_s <= key_r(127 downto 96);
  col1_s <= key_r(95  downto 64);
  col2_s <= key_r(63  downto 32);
  col3_s <= key_r(31  downto  0);

  -- calculate columns of next roundkey
  col0_next_s <= col0_s xor col3_core_s;
  col1_next_s <= col0_next_s xor col1_s;
  col2_next_s <= col1_next_s xor col2_s;
  col3_next_s <= col2_next_s xor col3_s;

  -- recombine rows
  key_s <= col0_next_s & col1_next_s & col2_next_s & col3_next_s;

  roundkey_o <= key_r;
end rtl;
