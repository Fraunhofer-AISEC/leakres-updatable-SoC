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

entity aes_ui_lrprf_ofb_gmac is
  generic (
    key_cnt_g       : integer                              -- no of keys which are used (1 for PRF and OFB, rest for 2PRG)
  );
  port (
    clk_i       : in std_ulogic;
    rst_i       : in std_ulogic;
    k_i         : in std_ulogic_vector(255 downto 0);  -- AES key
    iv_i        : in std_ulogic_vector(127 downto 0);  -- Initialization Vector
    k_we_i      : in std_ulogic;                       -- write enable for key
    iv_we_i     : in std_ulogic;                       -- write enable for IV
    data_i      : in std_ulogic_vector(127 downto 0);  -- authenticated data or plain-/ciphertext or tag input
    load_i      : in std_ulogic;                       -- process next block
    last_i      : in std_ulogic;                       -- block is last block (length)
    aad_i       : in std_ulogic;                       -- block is AAD, do not decrypt
    decrypt_i   : in std_ulogic;                       -- set for decryption -- currently unused, always decrypt
    busy_o      : out std_ulogic;                      -- core is busy and not accepting data
    rdy_o       : out std_ulogic;                      -- core is initialized and ready for the first/next data block
    data_o      : out std_ulogic_vector(127 downto 0); -- cipher-/plaintext output
    data_rdy_o  : out std_ulogic;
    t_valid_o   : out std_ulogic
    );
end aes_ui_lrprf_ofb_gmac;

architecture rtl of aes_ui_lrprf_ofb_gmac is

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

  component ghash
    port (
      clk_i       : in std_ulogic;
      rst_i       : in std_ulogic;
      start_i     : in std_ulogic;
      load_i      : in std_ulogic;
      h_i         : in std_ulogic_vector(127 downto 0);
      h_we_i      : in std_ulogic;
      ac_i        : in std_ulogic_vector(127 downto 0);
      done_o      : out std_ulogic;
      ghash_o     : out std_ulogic_vector(127 downto 0)
      );
  end component;

  constant init_iterations_c : integer := 128;
  constant init_cnt_width_c  : integer := integer(log2(real(init_iterations_c)));
  constant key_cnt_c         : integer := 2;
  constant key_cnt_width_c   : integer := integer(log2(real(key_cnt_c)));

  type state_t is (IDLE_e,
                   INIT_WAIT_NEXT_KEY_e,
                   INIT_TWOPRG_ONE_START_e, INIT_TWOPRG_ONE_WAIT_e,
                   INIT_TWOPRG_TWO_START_e, INIT_TWOPRG_TWO_WAIT_e,
                   INIT_WAIT_IVgmac_e, INIT_GEN_IVgmac_START_e, INIT_GEN_IVgmac_WAIT_e,
                   INIT_GEN_H_START_e, INIT_GEN_H_WAIT_e,
                   INIT_WAIT_IV_e, INIT_GEN_IVh_START_e, INIT_GEN_IVh_WAIT_e,
                   INIT_ENC_IVh_START_e, INIT_ENC_IVh_WAIT_e,
                   RDY_e,
                   PROCESS_BLOCK_START_e, PROCESS_BLOCK_WAIT_e,
                   PROCESS_AAD_START_e, PROCESS_AAD_WAIT_e,
                   PROCESS_LAST_BLOCK_START_e, PROCESS_LAST_BLOCK_WAIT_e,
                   WAIT_TAG_e);
  type key_array_t is array (0 to key_cnt_c-1) of std_ulogic_vector(127 downto 0);

  signal state_reg, next_state_s : state_t;
  signal init_cnt_reg       : unsigned(init_cnt_width_c-1 downto 0);
  signal key_cnt_reg        : unsigned(key_cnt_width_c-1 downto 0);

  signal key_array_reg      : key_array_t;
  signal data_in_reg        : std_ulogic_vector(127 downto 0);
  signal data_out_reg       : std_ulogic_vector(127 downto 0);
  signal tag_cmp_reg        : std_ulogic;

  signal aes_start_s        : std_ulogic;
  signal aes_done_s         : std_ulogic;
  signal aes_data_in_s      : std_ulogic_vector(127 downto 0);
  signal aes_data_out_s     : std_ulogic_vector(127 downto 0);
  signal aes_data_out_buf_r : std_ulogic_vector(127 downto 0);
  signal aes_key_in_s       : std_ulogic_vector(127 downto 0);
  signal aes_load_key_s     : std_ulogic;

  signal ghash_start_s      : std_ulogic;
  signal ghash_load_s       : std_ulogic;
  signal ghash_h_s          : std_ulogic_vector(127 downto 0);
  signal ghash_h_we_s       : std_ulogic;
  signal ghash_data_in_s    : std_ulogic_vector(127 downto 0);
  signal ghash_done_s       : std_ulogic;
  signal ghash_data_out_s   : std_ulogic_vector(127 downto 0);

  signal iv_reg             : std_ulogic_vector(127 downto 0);
  signal split_iv_s         : std_ulogic_vector(127 downto 0);
  signal ps0_reg            : std_ulogic_vector(127 downto 0);
  signal ps1_reg            : std_ulogic_vector(127 downto 0);
  signal enc_y0_reg         : std_ulogic_vector(127 downto 0);
  signal tag_s              : std_ulogic_vector(127 downto 0);
  signal process_aad_reg    : std_ulogic;
  signal process_block_reg  : std_ulogic;
  signal data_rdy_s         : std_ulogic;

begin

  next_state_p : process(state_reg, k_we_i, aes_done_s, iv_we_i, ghash_done_s, load_i, last_i)
  begin
    next_state_s <= state_reg;

    case state_reg is
      -------------------------------------------------------------------------
      when IDLE_e =>
        if k_we_i = '1' then
          next_state_s <= INIT_TWOPRG_ONE_START_e;
        end if;
      -------------------------------------------------------------------------
      when INIT_TWOPRG_ONE_START_e =>
          next_state_s <= INIT_TWOPRG_ONE_WAIT_e;
      -------------------------------------------------------------------------
      when INIT_TWOPRG_ONE_WAIT_e =>
        if aes_done_s = '1' then
          next_state_s <= INIT_TWOPRG_TWO_START_e;
        end if;
      -------------------------------------------------------------------------
      when INIT_TWOPRG_TWO_START_e =>
          next_state_s <= INIT_TWOPRG_TWO_WAIT_e;
      -------------------------------------------------------------------------
      when INIT_TWOPRG_TWO_WAIT_e =>
        if aes_done_s = '1' then
          next_state_s <= INIT_WAIT_IVgmac_e;
        end if;
      -------------------------------------------------------------------------
      when INIT_WAIT_IVgmac_e =>
        if iv_we_i = '1' then
          next_state_s <= INIT_GEN_IVgmac_START_e;
        end if;
      -------------------------------------------------------------------------
      when INIT_GEN_IVgmac_START_e =>
        next_state_s <= INIT_GEN_IVgmac_WAIT_e;
      -------------------------------------------------------------------------
      when INIT_GEN_IVgmac_WAIT_e =>
        if aes_done_s = '1' then
          if init_cnt_reg = init_iterations_c-1 then
            next_state_s <= INIT_GEN_H_START_e;
          else
            next_state_s <= INIT_GEN_IVgmac_START_e;
          end if;
        end if;
      -------------------------------------------------------------------------
      when INIT_GEN_H_START_e =>
          next_state_s <= INIT_GEN_H_WAIT_e;
      -------------------------------------------------------------------------
      when INIT_GEN_H_WAIT_e =>
        if aes_done_s = '1' then
          next_state_s <= INIT_WAIT_IV_e;
        end if;
      -------------------------------------------------------------------------
      when INIT_WAIT_IV_e =>
        if iv_we_i = '1' then
          next_state_s <= INIT_GEN_IVh_START_e;
        end if;
      -------------------------------------------------------------------------
      when INIT_GEN_IVh_START_e =>
        next_state_s <= INIT_GEN_IVh_WAIT_e;
      -------------------------------------------------------------------------
      when INIT_GEN_IVh_WAIT_e =>
        if aes_done_s = '1' then
          if init_cnt_reg = init_iterations_c-1 then
            next_state_s <= INIT_ENC_IVh_START_e;
          else
            next_state_s <= INIT_GEN_IVh_START_e;
          end if;
        end if;
      -------------------------------------------------------------------------
      when INIT_ENC_IVh_START_e =>
          next_state_s <= INIT_ENC_IVh_WAIT_e;
      -------------------------------------------------------------------------
      when INIT_ENC_IVh_WAIT_e =>
        if aes_done_s = '1' then
          next_state_s <= RDY_e;
        end if;
      -------------------------------------------------------------------------
      when RDY_e =>
        if k_we_i = '1' then
          next_state_s <= INIT_TWOPRG_ONE_START_e;
        elsif iv_we_i = '1' then
          next_state_s <= INIT_GEN_IVh_START_e;
        elsif load_i = '1' then
          if last_i = '1' then
            next_state_s <= PROCESS_LAST_BLOCK_START_e;
          elsif aad_i = '1' then
            next_state_s <= PROCESS_AAD_START_e;
          else
            next_state_s <= PROCESS_BLOCK_START_e;
          end if;
        end if;
      -------------------------------------------------------------------------
      when PROCESS_AAD_START_e =>
        next_state_s <= PROCESS_AAD_WAIT_e;
      -------------------------------------------------------------------------
      when PROCESS_AAD_WAIT_e =>
        if ghash_done_s = '1' then
          next_state_s <= RDY_e;
        end if;
      -------------------------------------------------------------------------
      when PROCESS_BLOCK_START_e =>
        next_state_s <= PROCESS_BLOCK_WAIT_e;
      -------------------------------------------------------------------------
      when PROCESS_BLOCK_WAIT_e =>
        if aes_done_s = '1' then
          next_state_s <= RDY_e;
        end if;
      -------------------------------------------------------------------------
      when PROCESS_LAST_BLOCK_START_e =>
        next_state_s <= PROCESS_LAST_BLOCK_WAIT_e;
      -------------------------------------------------------------------------
      when PROCESS_LAST_BLOCK_WAIT_e =>
        if ghash_done_s = '1' then
          next_state_s <= WAIT_TAG_e;
        end if;
      -------------------------------------------------------------------------
      when WAIT_TAG_e =>
        if load_i = '1' then
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

  iv_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      iv_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if iv_we_i = '1' then
        iv_reg <= iv_i;
      elsif (state_reg = INIT_GEN_IVh_WAIT_e and aes_done_s = '1')
         or (state_reg = INIT_GEN_IVgmac_WAIT_e and aes_done_s = '1') then
        if init_cnt_reg = init_iterations_c-1 then
          iv_reg <= aes_data_out_s;
        else
          iv_reg(127 downto 1) <= iv_reg(126 downto 0);
          iv_reg(0) <= '0';
        end if;
      end if;
    end if;
  end process;

  split_iv_s <= ps0_reg when iv_reg(127) = '0'
                        else ps1_reg;

  enc_y0_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      enc_y0_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if aes_done_s = '1' and state_reg = INIT_ENC_IVh_WAIT_e then
        enc_y0_reg <= aes_data_out_s;
      end if;
    end if;
  end process;

  ps0_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      ps0_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if aes_done_s = '1' and state_reg = INIT_TWOPRG_ONE_WAIT_e then
        ps0_reg <= aes_data_out_s;
      end if;
    end if;
  end process;

  ps1_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      ps1_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if aes_done_s = '1' and state_reg = INIT_TWOPRG_TWO_WAIT_e then
        ps1_reg <= aes_data_out_s;
      end if;
    end if;
  end process;

  k_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      key_array_reg(0) <= (others => '0');
      key_array_reg(1) <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if k_we_i = '1' then
          key_array_reg(0) <= k_i(255 downto 128);
          key_array_reg(1) <= k_i(127 downto 0);
      end if;
    end if;
  end process;

  aes_data_out_buf_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      aes_data_out_buf_r <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if aes_done_s = '1' then
        aes_data_out_buf_r <= aes_data_out_s;
      end if;
    end if;
  end process;

  data_in_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      data_in_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if load_i = '1' and state_reg /= WAIT_TAG_e  then
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
      if ( aes_done_s = '1') and (state_reg = PROCESS_BLOCK_WAIT_e or state_reg = PROCESS_LAST_BLOCK_WAIT_e)  then
        data_out_reg <= data_in_reg xor aes_data_out_s;
        data_rdy_s <= '1';
      elsif load_i = '1' and state_reg = WAIT_TAG_e  then
        data_rdy_s <= '1';
        if data_i = tag_s then
          data_out_reg <= tag_s;
        else
          data_out_reg <= not tag_s;
        end if;
      end if;
    end if;
  end process;

  data_o <= data_out_reg;
  data_rdy_o <= data_rdy_s;

  tag_cmp_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      tag_cmp_reg <= '0';
    elsif clk_i'event and clk_i = '1' then
      if load_i = '1' and process_block_reg = '0' then
        tag_cmp_reg <= '0';
      elsif load_i = '1' and state_reg = WAIT_TAG_e  then
        if data_i = tag_s then
          tag_cmp_reg <= '1';
        else
          tag_cmp_reg <= '0';
        end if;
      end if;
    end if;
  end process;

  t_valid_o <= tag_cmp_reg;

  process_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      process_block_reg <= '0';
      process_aad_reg <= '0';
    elsif clk_i'event and clk_i = '1' then
      if (state_reg = INIT_ENC_IVh_WAIT_e and next_state_s = RDY_e)
      or (load_i = '1' and state_reg = WAIT_TAG_e) then
        process_block_reg <= '0';  -- still waiting for starting block
      elsif (process_block_reg = '0' and state_reg = PROCESS_BLOCK_START_e) then
        process_block_reg <= '1';  -- at least one block has already been processed
      end if;
      if (state_reg = INIT_ENC_IVh_WAIT_e and next_state_s = RDY_e)
      or (load_i = '1' and state_reg = WAIT_TAG_e) then
        process_aad_reg <= '0';  -- still waiting for starting block
      elsif (process_aad_reg = '0' and state_reg = PROCESS_BLOCK_START_e)
         or (process_aad_reg = '0' and state_reg = PROCESS_AAD_START_e) then
        process_aad_reg <= '1';  -- at least one block has already been processed
      end if;
    end if;
  end process;

  init_cnt_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      init_cnt_reg <= (others => '0');
    elsif clk_i'event and clk_i = '1' then
      if (state_reg /= INIT_GEN_IVh_WAIT_e and next_state_s = INIT_GEN_IVh_START_e)
      or (state_reg /= INIT_GEN_IVgmac_WAIT_e and next_state_s = INIT_GEN_IVgmac_START_e) then
        init_cnt_reg <= (others => '0');
        elsif (state_reg = INIT_GEN_IVh_WAIT_e and aes_done_s = '1')
           or (state_reg = INIT_GEN_IVgmac_WAIT_e and aes_done_s = '1') then
          init_cnt_reg <= init_cnt_reg + 1;
        end if;
      end if;
  end process;

  rdy_o <= '1' when state_reg = RDY_e else '0';
  busy_o <= '0' when (state_reg = IDLE_e)
                  or (state_reg = INIT_WAIT_NEXT_KEY_e)
                  or (state_reg = INIT_WAIT_IVgmac_e)
                  or (state_reg = INIT_WAIT_IV_e)
                  or (state_reg = WAIT_TAG_e)
                  or (state_reg = RDY_e)
                else '1';

  aes_key_in_s <= k_i(255 downto 128) when k_we_i = '1' and next_state_s = INIT_TWOPRG_ONE_START_e -- key0, only for 2prg
                      else key_array_reg(0) when (next_state_s = INIT_TWOPRG_TWO_START_e)
                      else aes_data_out_s when (state_reg = INIT_GEN_IVh_WAIT_e and next_state_s = INIT_GEN_IVh_START_e)
                                            or (state_reg = INIT_GEN_IVgmac_WAIT_e and next_state_s = INIT_GEN_IVgmac_START_e)
                      else key_array_reg(1); -- key1, for prf, aes-ofb and gmac

  aes_load_key_s <= '1' when (state_reg = RDY_e and next_state_s = INIT_GEN_IVh_START_e)
                          or (state_reg = INIT_WAIT_IVgmac_e and next_state_s = INIT_GEN_IVgmac_START_e)
                          or (state_reg = INIT_GEN_IVgmac_WAIT_e and aes_done_s = '1')
                          or (state_reg = INIT_WAIT_IV_e and next_state_s = INIT_GEN_IVh_START_e)
                          or (state_reg = INIT_GEN_IVh_WAIT_e and aes_done_s = '1')
                          or (next_state_s = PROCESS_BLOCK_START_e)
                          or (next_state_s = INIT_GEN_H_START_e)
                          or (next_state_s = INIT_TWOPRG_ONE_START_e)
                          or (next_state_s = INIT_TWOPRG_TWO_START_e)
                        else '0';

  aes_start_s <=  '1' when (state_reg = INIT_GEN_H_START_e)
                        or (state_reg = INIT_GEN_IVgmac_START_e)
                        or (state_reg = INIT_GEN_IVh_START_e)
                        or (state_reg = INIT_ENC_IVh_START_e)
                        or (state_reg = PROCESS_BLOCK_START_e)
                        or (state_reg = INIT_TWOPRG_ONE_START_e)
                        or (state_reg = INIT_TWOPRG_TWO_START_e)
                      else '0';

  aes_data_in_s <= iv_reg   when state_reg = INIT_ENC_IVh_START_e
                            else split_iv_s         when (state_reg = INIT_GEN_IVh_START_e or state_reg = INIT_GEN_IVgmac_START_e)
                            else aes_data_out_buf_r when state_reg = INIT_GEN_H_START_e
                            else (others => '0')    when state_reg = INIT_TWOPRG_ONE_START_e
                            else (others => '1')    when state_reg = INIT_TWOPRG_TWO_START_e
                            else enc_y0_reg         when (state_reg = PROCESS_BLOCK_START_e and process_block_reg = '0')
                            else aes_data_out_buf_r;  -- OFB mode

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

  ghash_h_s <= aes_data_out_s;
  ghash_h_we_s <= '1' when aes_done_s = '1' and state_reg = INIT_GEN_H_WAIT_e
                      else '0';

  ghash_data_in_s <= data_i;
  ghash_load_s <= '1' when (state_reg = PROCESS_BLOCK_START_e)
                        or (state_reg = PROCESS_LAST_BLOCK_START_e)
                        or (state_reg = PROCESS_AAD_START_e)
                      else '0';
  ghash_start_s <= '1' when (state_reg = PROCESS_BLOCK_START_e and process_aad_reg = '0')
                         or (state_reg = PROCESS_AAD_START_e and process_aad_reg = '0')
                       else '0';
  tag_s <= ghash_data_out_s xor enc_y0_reg;

  ghash_0 : ghash
    port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      start_i     => ghash_start_s,
      load_i      => ghash_load_s,
      h_i         => ghash_h_s,
      h_we_i      => ghash_h_we_s,
      ac_i        => ghash_data_in_s,
      done_o      => ghash_done_s,
      ghash_o     => ghash_data_out_s
    );

end rtl;
