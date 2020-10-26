-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-------------------------------------------------------------------------------
-- 16-bit digit serial GF(2^m) multiplier
--
-- width is determined by the size of the reducing polynomial, the width needs
-- to be divisible by the digit size 16
-------------------------------------------------------------------------------

entity gfm_16bit is
  generic (
    irred_poly_g  : std_ulogic_vector
  );
  port (
    clk_i         : in std_ulogic;
    rst_i         : in std_ulogic;
    op_a_i        : in std_ulogic_vector(irred_poly_g'length-2 downto 0);
    op_b_i        : in std_ulogic_vector(irred_poly_g'length-2 downto 0);
    res_o         : out std_ulogic_vector(irred_poly_g'length-2 downto 0);
    start_i       : in std_ulogic;
    done_o        : out std_ulogic
  );

  constant degree_c : integer := irred_poly_g'length-1;
  constant steps_c : integer := degree_c/16;
  constant cnt_width_c : integer := integer(log2(real(steps_c)));

end gfm_16bit;

architecture rtl of gfm_16bit is

  signal acc_reg      : std_ulogic_vector(degree_c-1 downto 0);

  signal last_intermed_result_s : std_ulogic_vector(degree_c+15 downto 0);
  signal next_intermed_result_s : std_ulogic_vector(degree_c+15 downto 0);

  signal part_prod_15_s : std_ulogic_vector(degree_c+14 downto 0);
  signal part_prod_14_s : std_ulogic_vector(degree_c+13 downto 0);
  signal part_prod_13_s : std_ulogic_vector(degree_c+12 downto 0);
  signal part_prod_12_s : std_ulogic_vector(degree_c+11 downto 0);
  signal part_prod_11_s : std_ulogic_vector(degree_c+10 downto 0);
  signal part_prod_10_s : std_ulogic_vector(degree_c+9 downto 0);
  signal part_prod_9_s : std_ulogic_vector(degree_c+8 downto 0);
  signal part_prod_8_s : std_ulogic_vector(degree_c+7 downto 0);
  signal part_prod_7_s : std_ulogic_vector(degree_c+6 downto 0);
  signal part_prod_6_s : std_ulogic_vector(degree_c+5 downto 0);
  signal part_prod_5_s : std_ulogic_vector(degree_c+4 downto 0);
  signal part_prod_4_s : std_ulogic_vector(degree_c+3 downto 0);
  signal part_prod_3_s : std_ulogic_vector(degree_c+2 downto 0);
  signal part_prod_2_s : std_ulogic_vector(degree_c+1 downto 0);
  signal part_prod_1_s : std_ulogic_vector(degree_c downto 0);
  signal part_prod_0_s : std_ulogic_vector(degree_c-1 downto 0);

  signal red_16_s : std_ulogic_vector(degree_c+15 downto 0);
  signal red_15_s : std_ulogic_vector(degree_c+14 downto 0);
  signal red_14_s : std_ulogic_vector(degree_c+13 downto 0);
  signal red_13_s : std_ulogic_vector(degree_c+12 downto 0);
  signal red_12_s : std_ulogic_vector(degree_c+11 downto 0);
  signal red_11_s : std_ulogic_vector(degree_c+10 downto 0);
  signal red_10_s : std_ulogic_vector(degree_c+9 downto 0);
  signal red_9_s : std_ulogic_vector(degree_c+8 downto 0);
  signal red_8_s : std_ulogic_vector(degree_c+7 downto 0);
  signal red_7_s : std_ulogic_vector(degree_c+6 downto 0);
  signal red_6_s : std_ulogic_vector(degree_c+5 downto 0);
  signal red_5_s : std_ulogic_vector(degree_c+4 downto 0);
  signal red_4_s : std_ulogic_vector(degree_c+3 downto 0);
  signal red_3_s : std_ulogic_vector(degree_c+2 downto 0);
  signal red_2_s : std_ulogic_vector(degree_c+1 downto 0);
  signal red_1_s : std_ulogic_vector(degree_c downto 0);

  signal op_a_reg     : std_ulogic_vector(degree_c-1 downto 0);
  signal op_b_reg     : std_ulogic_vector(degree_c-1 downto 0);
  signal digit_s      : std_ulogic_vector(15 downto 0);
  signal run_reg      : std_ulogic;

  signal cnt_reg : unsigned(cnt_width_c-1 downto 0) := (others => '0');

begin
  -----------------------------------------------------------------------------
  -- operand a reg
  -----------------------------------------------------------------------------
  op_a_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      op_a_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if start_i = '1' then
        op_a_reg <= op_a_i;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- operand b reg
  -----------------------------------------------------------------------------
  op_b_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      op_b_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if start_i = '1' then
        op_b_reg <= op_b_i;
      elsif run_reg = '1'  then
        op_b_reg <= op_b_reg(degree_c-1-16 downto 0) & "0000000000000000";
      end if;
    end if;
  end process;

  digit_s <= op_b_reg(degree_c-1 downto degree_c-16);

  -----------------------------------------------------------------------------
  -- cnt reg
  -----------------------------------------------------------------------------
  cnt_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      cnt_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if start_i = '1' then
        cnt_reg <= (others => '0');
      elsif run_reg = '1' then
        cnt_reg <= cnt_reg + 1;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- run reg
  -----------------------------------------------------------------------------
  run_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      run_reg <= '0';
    elsif clk_i'event and clk_i = '1' then
      done_o <= '0';
      if start_i = '1' then
        run_reg <= '1';
      elsif cnt_reg = steps_c-1 then
        run_reg <= '0';
        done_o <= '1';
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- acc reg
  -----------------------------------------------------------------------------
  acc_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      acc_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if start_i = '1' then
        acc_reg <= (others => '0');
      elsif run_reg = '1' then
        acc_reg <= next_intermed_result_s(degree_c-1 downto 0);
      end if;
    end if;
  end process;
  res_o <= acc_reg;

  -----------------------------------------------------------------------------
  -- combinational part
  -----------------------------------------------------------------------------
    last_intermed_result_s <= acc_reg(degree_c-1 downto 0) & "0000000000000000";

    part_prod_15_s <= op_a_reg & "000000000000000" when digit_s(15) = '1' else (others => '0');
    part_prod_14_s <= op_a_reg & "00000000000000"  when digit_s(14) = '1' else (others => '0');
    part_prod_13_s <= op_a_reg & "0000000000000"   when digit_s(13) = '1' else (others => '0');
    part_prod_12_s <= op_a_reg & "000000000000"    when digit_s(12) = '1' else (others => '0');
    part_prod_11_s <= op_a_reg & "00000000000"     when digit_s(11) = '1' else (others => '0');
    part_prod_10_s <= op_a_reg & "0000000000"      when digit_s(10) = '1' else (others => '0');
    part_prod_9_s <= op_a_reg  & "000000000"       when digit_s(9)  = '1' else (others => '0');
    part_prod_8_s <= op_a_reg  & "00000000"        when digit_s(8)  = '1' else (others => '0');
    part_prod_7_s <= op_a_reg  & "0000000"         when digit_s(7)  = '1' else (others => '0');
    part_prod_6_s <= op_a_reg  & "000000"          when digit_s(6)  = '1' else (others => '0');
    part_prod_5_s <= op_a_reg  & "00000"           when digit_s(5)  = '1' else (others => '0');
    part_prod_4_s <= op_a_reg  & "0000"            when digit_s(4)  = '1' else (others => '0');
    part_prod_3_s <= op_a_reg  & "000"             when digit_s(3)  = '1' else (others => '0');
    part_prod_2_s <= op_a_reg  & "00"              when digit_s(2)  = '1' else (others => '0');
    part_prod_1_s <= op_a_reg  & "0"               when digit_s(1)  = '1' else (others => '0');
    part_prod_0_s <= op_a_reg                      when digit_s(0)  = '1' else (others => '0');

    red_16_s <= irred_poly_g & "000000000000000" when (last_intermed_result_s(degree_c+15) = '1')
      else (others => '0');

    red_15_s <= irred_poly_g & "00000000000000" when (
                              last_intermed_result_s(degree_c+14)
                          xor part_prod_15_s(degree_c+14)
                          ) = '1'
      else (others => '0');

    red_14_s <= irred_poly_g & "0000000000000" when (
                              last_intermed_result_s(degree_c+13)
                          xor part_prod_15_s(degree_c+13)
                          xor part_prod_14_s(degree_c+13)
                          ) = '1'
      else (others => '0');

    red_13_s <= irred_poly_g & "000000000000" when (
                              last_intermed_result_s(degree_c+12)
                          xor part_prod_15_s(degree_c+12)
                          xor part_prod_14_s(degree_c+12)
                          xor part_prod_13_s(degree_c+12)
                          ) = '1'
      else (others => '0');

    red_12_s <= irred_poly_g & "00000000000" when (
                              last_intermed_result_s(degree_c+11)
                          xor part_prod_15_s(degree_c+11)
                          xor part_prod_14_s(degree_c+11)
                          xor part_prod_13_s(degree_c+11)
                          xor part_prod_12_s(degree_c+11)
                          ) = '1'
      else (others => '0');

    red_11_s <= irred_poly_g & "0000000000" when (
                              last_intermed_result_s(degree_c+10)
                          xor part_prod_15_s(degree_c+10)
                          xor part_prod_14_s(degree_c+10)
                          xor part_prod_13_s(degree_c+10)
                          xor part_prod_12_s(degree_c+10)
                          xor part_prod_11_s(degree_c+10)
                          ) = '1'
      else (others => '0');

    red_10_s <= irred_poly_g & "000000000" when (
                              last_intermed_result_s(degree_c+9)
                          xor part_prod_15_s(degree_c+9)
                          xor part_prod_14_s(degree_c+9)
                          xor part_prod_13_s(degree_c+9)
                          xor part_prod_12_s(degree_c+9)
                          xor part_prod_11_s(degree_c+9)
                          xor part_prod_10_s(degree_c+9)
                          ) = '1'
      else (others => '0');

    red_9_s <= irred_poly_g & "00000000" when (
                              last_intermed_result_s(degree_c+8)
                          xor part_prod_15_s(degree_c+8)
                          xor part_prod_14_s(degree_c+8)
                          xor part_prod_13_s(degree_c+8)
                          xor part_prod_12_s(degree_c+8)
                          xor part_prod_11_s(degree_c+8)
                          xor part_prod_10_s(degree_c+8)
                          xor part_prod_9_s(degree_c+8)
                          ) = '1'
      else (others => '0');

    red_8_s <= irred_poly_g & "0000000" when (
                              last_intermed_result_s(degree_c+7)
                          xor part_prod_15_s(degree_c+7)
                          xor part_prod_14_s(degree_c+7)
                          xor part_prod_13_s(degree_c+7)
                          xor part_prod_12_s(degree_c+7)
                          xor part_prod_11_s(degree_c+7)
                          xor part_prod_10_s(degree_c+7)
                          xor part_prod_9_s(degree_c+7)
                          xor part_prod_8_s(degree_c+7)
                          ) = '1'
      else (others => '0');

    red_7_s <= irred_poly_g & "000000" when (
                              last_intermed_result_s(degree_c+6)
                          xor part_prod_15_s(degree_c+6)
                          xor part_prod_14_s(degree_c+6)
                          xor part_prod_13_s(degree_c+6)
                          xor part_prod_12_s(degree_c+6)
                          xor part_prod_11_s(degree_c+6)
                          xor part_prod_10_s(degree_c+6)
                          xor part_prod_9_s(degree_c+6)
                          xor part_prod_8_s(degree_c+6)
                          xor part_prod_7_s(degree_c+6)
                          ) = '1'
      else (others => '0');

    red_6_s <= irred_poly_g & "00000" when (
                              last_intermed_result_s(degree_c+5)
                          xor part_prod_15_s(degree_c+5)
                          xor part_prod_14_s(degree_c+5)
                          xor part_prod_13_s(degree_c+5)
                          xor part_prod_12_s(degree_c+5)
                          xor part_prod_11_s(degree_c+5)
                          xor part_prod_10_s(degree_c+5)
                          xor part_prod_9_s(degree_c+5)
                          xor part_prod_8_s(degree_c+5)
                          xor part_prod_7_s(degree_c+5)
                          xor part_prod_6_s(degree_c+5)
                          ) = '1'
      else (others => '0');

    red_5_s <= irred_poly_g & "0000" when (
                              last_intermed_result_s(degree_c+4)
                          xor part_prod_15_s(degree_c+4)
                          xor part_prod_14_s(degree_c+4)
                          xor part_prod_13_s(degree_c+4)
                          xor part_prod_12_s(degree_c+4)
                          xor part_prod_11_s(degree_c+4)
                          xor part_prod_10_s(degree_c+4)
                          xor part_prod_9_s(degree_c+4)
                          xor part_prod_8_s(degree_c+4)
                          xor part_prod_7_s(degree_c+4)
                          xor part_prod_6_s(degree_c+4)
                          xor part_prod_5_s(degree_c+4)
                          ) = '1'
      else (others => '0');

    red_4_s <= irred_poly_g & "000" when (
                              last_intermed_result_s(degree_c+3)
                          xor part_prod_15_s(degree_c+3)
                          xor part_prod_14_s(degree_c+3)
                          xor part_prod_13_s(degree_c+3)
                          xor part_prod_12_s(degree_c+3)
                          xor part_prod_11_s(degree_c+3)
                          xor part_prod_10_s(degree_c+3)
                          xor part_prod_9_s(degree_c+3)
                          xor part_prod_8_s(degree_c+3)
                          xor part_prod_7_s(degree_c+3)
                          xor part_prod_6_s(degree_c+3)
                          xor part_prod_5_s(degree_c+3)
                          xor part_prod_4_s(degree_c+3)
                          ) = '1'
      else (others => '0');

    red_3_s <= irred_poly_g & "00" when (
                              last_intermed_result_s(degree_c+2)
                          xor part_prod_15_s(degree_c+2)
                          xor part_prod_14_s(degree_c+2)
                          xor part_prod_13_s(degree_c+2)
                          xor part_prod_12_s(degree_c+2)
                          xor part_prod_11_s(degree_c+2)
                          xor part_prod_10_s(degree_c+2)
                          xor part_prod_9_s(degree_c+2)
                          xor part_prod_8_s(degree_c+2)
                          xor part_prod_7_s(degree_c+2)
                          xor part_prod_6_s(degree_c+2)
                          xor part_prod_5_s(degree_c+2)
                          xor part_prod_4_s(degree_c+2)
                          xor part_prod_3_s(degree_c+2)
                          ) = '1'
      else (others => '0');

    red_2_s <= irred_poly_g & "0" when (
                              last_intermed_result_s(degree_c+1)
                          xor part_prod_15_s(degree_c+1)
                          xor part_prod_14_s(degree_c+1)
                          xor part_prod_13_s(degree_c+1)
                          xor part_prod_12_s(degree_c+1)
                          xor part_prod_11_s(degree_c+1)
                          xor part_prod_10_s(degree_c+1)
                          xor part_prod_9_s(degree_c+1)
                          xor part_prod_8_s(degree_c+1)
                          xor part_prod_7_s(degree_c+1)
                          xor part_prod_6_s(degree_c+1)
                          xor part_prod_5_s(degree_c+1)
                          xor part_prod_4_s(degree_c+1)
                          xor part_prod_3_s(degree_c+1)
                          xor part_prod_2_s(degree_c+1)
                          ) = '1'
      else (others => '0');

    red_1_s <= irred_poly_g  when (
                              last_intermed_result_s(degree_c)
                          xor part_prod_15_s(degree_c)
                          xor part_prod_14_s(degree_c)
                          xor part_prod_13_s(degree_c)
                          xor part_prod_12_s(degree_c)
                          xor part_prod_11_s(degree_c)
                          xor part_prod_10_s(degree_c)
                          xor part_prod_9_s(degree_c)
                          xor part_prod_8_s(degree_c)
                          xor part_prod_7_s(degree_c)
                          xor part_prod_6_s(degree_c)
                          xor part_prod_5_s(degree_c)
                          xor part_prod_4_s(degree_c)
                          xor part_prod_3_s(degree_c)
                          xor part_prod_2_s(degree_c)
                          xor part_prod_1_s(degree_c)
                          ) = '1'
      else (others => '0');

    next_intermed_result_s <=
      last_intermed_result_s xor red_16_s
      xor ("0" & part_prod_15_s)              xor ("0" & red_15_s)
      xor ("00" & part_prod_14_s)             xor ("00" & red_14_s)
      xor ("000" & part_prod_13_s)            xor ("000" & red_13_s)
      xor ("0000" & part_prod_12_s)           xor ("0000" & red_12_s)
      xor ("00000" & part_prod_11_s)          xor ("00000" & red_11_s)
      xor ("000000" & part_prod_10_s)         xor ("000000" & red_10_s)
      xor ("0000000" & part_prod_9_s)         xor ("0000000" & red_9_s)
      xor ("00000000" & part_prod_8_s)        xor ("00000000" & red_8_s)
      xor ("000000000" & part_prod_7_s)       xor ("000000000" & red_7_s)
      xor ("0000000000" & part_prod_6_s)      xor ("0000000000" & red_6_s)
      xor ("00000000000" & part_prod_5_s)     xor ("00000000000" & red_5_s)
      xor ("000000000000" & part_prod_4_s)    xor ("000000000000" & red_4_s)
      xor ("0000000000000" & part_prod_3_s)   xor ("0000000000000" & red_3_s)
      xor ("00000000000000" & part_prod_2_s)  xor ("00000000000000" & red_2_s)
      xor ("000000000000000" & part_prod_1_s) xor ("000000000000000" & red_1_s)
      xor ("0000000000000000" & part_prod_0_s);

end rtl;
