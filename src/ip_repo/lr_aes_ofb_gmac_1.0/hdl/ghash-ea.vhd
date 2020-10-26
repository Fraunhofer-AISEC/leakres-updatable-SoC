-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.global.all;

entity ghash is
  port (
    clk_i       : in std_ulogic;
    rst_i       : in std_ulogic;
    start_i     : in std_ulogic;  -- init, load first value and start processing
    load_i      : in std_ulogic;  -- load next value
    h_i         : in std_ulogic_vector(127 downto 0); -- hash key H
    h_we_i      : in std_ulogic;
    ac_i        : in std_ulogic_vector(127 downto 0); -- authenticated data or ciphertext
    done_o      : out std_ulogic; -- current block processed, ready for next 'load'
    ghash_o     : out std_ulogic_vector(127 downto 0)
    );
end ghash;

architecture rtl of ghash is

  component gfm_16bit
    generic (
      irred_poly_g : in std_ulogic_vector
    );
    port (
      clk_i         : in std_ulogic;
      rst_i         : in std_ulogic;
      op_a_i        : in std_ulogic_vector(127 downto 0);
      op_b_i        : in std_ulogic_vector(127 downto 0);
      res_o         : out std_ulogic_vector(127 downto 0);
      start_i       : in std_ulogic;
      done_o        : out std_ulogic
    );
  end component;

  signal h_reg          : std_ulogic_vector(127 downto 0);
  signal mult_res_s     : std_ulogic_vector(127 downto 0);
  signal start_mult_reg : std_ulogic;
  signal mult_done_s    : std_ulogic;
  signal cnt_reg        : std_ulogic_vector(127 downto 0);
  signal acc_reg        : std_ulogic_vector(127 downto 0);
  signal h_s            : std_ulogic_vector(127 downto 0);
  signal acc_s          : std_ulogic_vector(127 downto 0);
  signal gfm_res_s      : std_ulogic_vector(127 downto 0);

begin

  h_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      h_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if h_we_i = '1' then
        h_reg <= h_i;
      end if;
    end if;
  end process;

  acc_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      acc_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if start_i = '1' then
        acc_reg <= ac_i;
      elsif load_i <= '1' then
        acc_reg <= mult_res_s xor ac_i;
      end if;
    end if;
  end process;

  start_mult_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      start_mult_reg <= '0';
    elsif clk_i'event and clk_i = '1' then
      start_mult_reg <= load_i or start_i;
    end if;
  end process;

  ghash_o <= mult_res_s;
  done_o <= mult_done_s;

  h_s <= bit_reflect(h_reg);
  acc_s <= bit_reflect(acc_reg);
  mult_res_s <= bit_reflect(gfm_res_s);

  gfm_0 : gfm_16bit
  generic map (
    irred_poly_g => irred_poly_c
  )
  port map (
    clk_i     => clk_i,
    rst_i     => rst_i,
    op_a_i    => h_s,
    op_b_i    => acc_s,
    res_o     => gfm_res_s,
    start_i   => start_mult_reg,
    done_o    => mult_done_s
  );

end rtl;
