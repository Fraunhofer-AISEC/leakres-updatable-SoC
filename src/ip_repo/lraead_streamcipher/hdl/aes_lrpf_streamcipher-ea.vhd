-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.global.all;

entity aes_lrprf_streamcipher is
  port (
    clk_i       : in std_ulogic;
    rst_i       : in std_ulogic;
    k_i         : in std_ulogic_vector(127 downto 0);  -- AES key
    prf_i       : in std_ulogic_vector(127 downto 0);  -- LRPRF input (was iv_i)
    k_we_i      : in std_ulogic;                       -- write enable for key
    prf_we_i    : in std_ulogic;                       -- write enable for LRPRF input (was iv_we_i)
    data_i      : in std_ulogic_vector(127 downto 0);  -- plain-/ciphertext input
    load_i      : in std_ulogic;                       -- process next block
    prfmode_i   : in std_ulogic;                       -- set when writing prf_we_i to run prf standalone (was last_i)
    decrypt_i   : in std_ulogic;                       -- set for decryption -- currently unused, always decrypt
    busy_o      : out std_ulogic;                      -- core is busy and not accepting data
    rdy_o       : out std_ulogic;                      -- core is initialized and ready for the first/next data block
    data_o      : out std_ulogic_vector(127 downto 0); -- cipher-/plaintext output
    data_rdy_o  : out std_ulogic
    );
end aes_lrprf_streamcipher;

architecture rtl of aes_lrprf_streamcipher is

  component hws_aes
    port (
      clk_i      : in  std_ulogic;
      rst_i      : in  std_ulogic;
      encrypt_i  : in  std_ulogic;
      key_i      : in  std_ulogic_vector (127 downto 0);
      key_we_i   : in  std_ulogic;
      data_i     : in  std_ulogic_vector (127 downto 0);
      start_i    : in  std_ulogic;
      done_o     : out std_ulogic;
      data_o     : out std_ulogic_vector (127 downto 0));
  end component;


  constant init_iterations_c : integer := 128;
  constant init_cnt_width_c  : integer := integer(log2(real(init_iterations_c)));

  constant PTXT0 : std_ulogic_vector (127 downto 0) := (others => '0');
  constant PTXT1 : std_ulogic_vector (127 downto 0) := (others => '1');

  type state_t is (IDLE_e,
                   INIT_WAIT_NEXT_KEY_e,
                   PROCESS_BLOCK_TWOPRG_ONE_START_e, PROCESS_BLOCK_TWOPRG_ONE_WAIT_e,
                   PROCESS_BLOCK_TWOPRG_TWO_START_e, PROCESS_BLOCK_TWOPRG_TWO_WAIT_e,
                   INIT_WAIT_PRF_INPUT_e, INIT_PRF_ITERATION_START_e, INIT_PRF_ITERATION_WAIT_e,
                   INIT_PRF_WHITENING_START_e, INIT_PRF_WHITENING_WAIT_e,
                   RDY_e);

  signal state_reg, next_state_s : state_t;
  signal init_cnt_reg       : unsigned(init_cnt_width_c-1 downto 0);

  signal key_reg            : std_ulogic_vector(127 downto 0);
  signal data_in_reg        : std_ulogic_vector(127 downto 0);
  signal data_out_reg       : std_ulogic_vector(127 downto 0);
  signal tag_cmp_reg        : std_ulogic;
  signal prfmode_reg        : std_ulogic;

  signal aes_start_s        : std_ulogic;
  signal aes_done_s         : std_ulogic;
  signal aes_data_in_s      : std_ulogic_vector(127 downto 0);
  signal aes_data_out_s     : std_ulogic_vector(127 downto 0);
  signal aes_key_in_s       : std_ulogic_vector(127 downto 0);
  signal aes_load_key_s     : std_ulogic;

  signal prf_in_reg         : std_ulogic_vector(127 downto 0);
  signal prf_aes_in_s       : std_ulogic_vector(127 downto 0);
  signal data_rdy_s         : std_ulogic;

begin

  next_state_p : process(state_reg, k_we_i, aes_done_s, prf_we_i, load_i, prfmode_i)
  begin
    next_state_s <= state_reg;

    case state_reg is
      -------------------------------------------------------------------------
      when IDLE_e =>
        if k_we_i = '1' then
          next_state_s <= INIT_WAIT_PRF_INPUT_e;
        end if;
      -------------------------------------------------------------------------
      when INIT_WAIT_PRF_INPUT_e =>
        if prf_we_i = '1' then
          next_state_s <= INIT_PRF_ITERATION_START_e;
        end if;
      -------------------------------------------------------------------------
      when INIT_PRF_ITERATION_START_e =>
        next_state_s <= INIT_PRF_ITERATION_WAIT_e;
      -------------------------------------------------------------------------
      when INIT_PRF_ITERATION_WAIT_e =>
        if aes_done_s = '1' then
          if init_cnt_reg = init_iterations_c-1 then
            next_state_s <= INIT_PRF_WHITENING_START_e;
          else
            next_state_s <= INIT_PRF_ITERATION_START_e;
          end if;
        end if;
      -------------------------------------------------------------------------
      when INIT_PRF_WHITENING_START_e =>
        next_state_s <= INIT_PRF_WHITENING_WAIT_e;
      -------------------------------------------------------------------------
      when INIT_PRF_WHITENING_WAIT_e =>
        if aes_done_s = '1' then
          if prfmode_reg = '1' then   -- PRF standalone mode, output result and be done
            next_state_s <= INIT_WAIT_PRF_INPUT_e;
          else -- streamcipher mode, go wait for ctxt blocks
            next_state_s <= RDY_e;
          end if;
        end if;
      -------------------------------------------------------------------------
        when RDY_e =>
          if k_we_i = '1' then
            next_state_s <= INIT_WAIT_PRF_INPUT_e;
          elsif load_i = '1' then
            next_state_s <= PROCESS_BLOCK_TWOPRG_ONE_START_e;
          end if;
     -----------------------------------------------------------------------
      when PROCESS_BLOCK_TWOPRG_ONE_START_e =>
          next_state_s <= PROCESS_BLOCK_TWOPRG_ONE_WAIT_e;
      -------------------------------------------------------------------------
      when PROCESS_BLOCK_TWOPRG_ONE_WAIT_e =>
        if aes_done_s = '1' then
          next_state_s <= PROCESS_BLOCK_TWOPRG_TWO_START_e;
        end if;
      -------------------------------------------------------------------------
      when PROCESS_BLOCK_TWOPRG_TWO_START_e =>
          next_state_s <= PROCESS_BLOCK_TWOPRG_TWO_WAIT_e;
      -------------------------------------------------------------------------
      when PROCESS_BLOCK_TWOPRG_TWO_WAIT_e =>
        if aes_done_s = '1' then
          next_state_s <= RDY_e;
        end if;
      -------------------------------------------------------------------------
      when others =>
        null;
    end case;
  end process;

  state_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      state_reg <= IDLE_e;
    elsif clk_i'event and clk_i = '1' then
      state_reg <= next_state_s;
    end if;
  end process;

  prf_in_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      prf_in_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if prf_we_i = '1' then
        prf_in_reg <= prf_i;
      elsif (state_reg = INIT_PRF_ITERATION_WAIT_e and aes_done_s = '1') then
          prf_in_reg(127 downto 1) <= prf_in_reg(126 downto 0);
          prf_in_reg(0) <= '0';
      elsif (state_reg = PROCESS_BLOCK_TWOPRG_ONE_WAIT_e and aes_done_s = '1') then -- buffer 2prg key
        prf_in_reg <= aes_data_out_s;
      end if;
    end if;
  end process;

  prf_aes_in_s <= PTXT0 when prf_in_reg(127) = '0'
                        else PTXT1;

  prfmode_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      prfmode_reg <= '0';
    elsif clk_i'event and clk_i = '1' then
      if prf_we_i = '1' then
        prfmode_reg <= prfmode_i;
      end if;
    end if;
  end process;

  key_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      key_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if k_we_i = '1' then
        key_reg <= k_i;
      elsif (state_reg = INIT_PRF_WHITENING_WAIT_e and next_state_s = RDY_e) then -- set PRG key to prf output
          key_reg <= aes_data_out_s; 
      elsif (state_reg = PROCESS_BLOCK_TWOPRG_TWO_WAIT_e and aes_done_s = '1') then -- update 2prg key, was buffered in prf_in_reg
        key_reg <= prf_in_reg; 
      end if;
    end if;
  end process;

  data_in_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      data_in_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if load_i = '1' then
        data_in_reg <= data_i;
      end if;
    end if;
  end process;

  data_out_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      data_rdy_s <= '0';
      data_out_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      data_rdy_s <= '0';
      if (prfmode_reg = '1') then
        if (state_reg = INIT_PRF_WHITENING_WAIT_e and next_state_s <= INIT_WAIT_PRF_INPUT_e) then
          data_out_reg <= aes_data_out_s;
          data_rdy_s <= '1';
        end if;
      else
        if (state_reg = PROCESS_BLOCK_TWOPRG_TWO_WAIT_e and aes_done_s = '1') then
          data_out_reg <= data_in_reg xor aes_data_out_s;
          data_rdy_s <= '1';
        end if;      
      end if;
    end if;
  end process;

  data_o <= data_out_reg;
  data_rdy_o <= data_rdy_s;

  init_cnt_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      init_cnt_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if (state_reg /= INIT_PRF_ITERATION_WAIT_e and next_state_s = INIT_PRF_ITERATION_START_e) then
        init_cnt_reg <= (others => '0');
        elsif (state_reg = INIT_PRF_ITERATION_WAIT_e and aes_done_s = '1') then
          init_cnt_reg <= init_cnt_reg + 1;
        end if;
      end if;
  end process;

  rdy_o <= '1' when state_reg = RDY_e else '0';
  busy_o <= '0' when (state_reg = IDLE_e)
                  or (state_reg = INIT_WAIT_NEXT_KEY_e)
                  or (state_reg = INIT_WAIT_PRF_INPUT_e)
                  or (state_reg = RDY_e)
                else '1';

  aes_key_in_s <= aes_data_out_s when state_reg = INIT_PRF_ITERATION_WAIT_e
                                 else key_reg;

  aes_load_key_s <= '1' when (state_reg = RDY_e and next_state_s = INIT_PRF_ITERATION_START_e)
                          or (state_reg = INIT_WAIT_PRF_INPUT_e and next_state_s = INIT_PRF_ITERATION_START_e)
                          or (state_reg = INIT_PRF_ITERATION_WAIT_e and aes_done_s = '1')
                          or (next_state_s = PROCESS_BLOCK_TWOPRG_ONE_START_e)
                          or (next_state_s = PROCESS_BLOCK_TWOPRG_TWO_START_e)
                        else '0';

  aes_start_s <=  '1' when (state_reg = INIT_PRF_ITERATION_START_e)
                        or (state_reg = INIT_PRF_WHITENING_START_e)
                        or (state_reg = PROCESS_BLOCK_TWOPRG_ONE_START_e)
                        or (state_reg = PROCESS_BLOCK_TWOPRG_TWO_START_e)
                      else '0';

  aes_data_in_s <=  prf_aes_in_s          when state_reg = INIT_PRF_ITERATION_START_e
                            else PTXT0    when (state_reg = PROCESS_BLOCK_TWOPRG_ONE_START_e or state_reg = INIT_PRF_WHITENING_START_e)
                            else PTXT1    when state_reg = PROCESS_BLOCK_TWOPRG_TWO_START_e
                            else (others => '0');

  hws_aes_0 : hws_aes
    port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      encrypt_i  => '1',
      data_i     => aes_data_in_s,
      key_i      => aes_key_in_s,
      start_i    => aes_start_s,
      key_we_i   => aes_load_key_s,
      done_o     => aes_done_s,
      data_o     => aes_data_out_s
      );


end rtl;
