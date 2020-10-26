-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use IEEE.MATH_REAL.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity icap_fifo_buffer is
   generic (
      BYTES_PER_BLOCK_gen   : integer  -- must align to a multiple of 4, if not it is rounded up
      );
   port (
      -- system ports
      clk           : in std_logic;
      rst           : in std_logic;  -- low active, synchronous to clk
      -- icap controller interface
      icap_tdata         : out std_logic_vector(31 downto 0);
      icap_abort         : out std_logic;
      icap_tvalid        : out std_logic;
      icap_tready        : in std_logic;
      -- AES interface
      aes_data          : in std_logic_vector(127 downto 0);
      aes_data_stb      : in std_logic;
      aes_ready         : out std_logic;
      aes_tag_valid     : in std_logic;
      aes_tag_invalid   : in std_logic;
      aes_error         : out std_logic;
      aes_empty         : out std_logic
      );
end icap_fifo_buffer;

architecture Behavioral of icap_fifo_buffer is
   -- round up to align to a multiple of four; Minus one as the lowest index is zero
   constant COUNTER_PREVAL_const : integer := (BYTES_PER_BLOCK_gen + 3) / 4 - 1;
   constant COUNTER_WIDTH_const  : integer := INTEGER(CEIL(LOG2(REAL(COUNTER_PREVAL_const + 1))));

   type INPUT_CTRL_STATE_type is (INPUT_CTRL_STATE_RST_BRAM_0,
                                  INPUT_CTRL_STATE_RST_BRAM_1,
                                  INPUT_CTRL_STATE_RST_BRAM_2,
                                  INPUT_CTRL_STATE_RST_BRAM_3,
                                  INPUT_CTRL_STATE_RST_BRAM_4,
                                  INPUT_CTRL_STATE_RST_BRAM_5,
                                  INPUT_CTRL_STATE_WAIT_BRAM_RDY_0,
                                  INPUT_CTRL_STATE_WAIT_BRAM_RDY_1,
                                  INPUT_CTRL_STATE_IDLE,
                                  INPUT_CTRL_STATE_WAIT_PREV_BLOCK_SENT,
                                  INPUT_CTRL_STATE_WRITE_1,
                                  INPUT_CTRL_STATE_WRITE_2,
                                  INPUT_CTRL_STATE_WRITE_3,
                                  INPUT_CTRL_STATE_ERROR);
   type OUTPUT_CTRL_STATE_type is (OUTPUT_CTRL_STATE_RESET,
                                   OUTPUT_CTRL_STATE_WAIT_ICAP_RDY,
                                   OUTPUT_CTRL_STATE_IDLE,
                                   OUTPUT_CTRL_STATE_READ_BLOCK,
                                   OUTPUT_CTRL_STATE_ERROR);

   ------ fifo ------
   signal fifo_data_out_64bit  : std_logic_vector(63 downto 0);
   signal fifo_data_out        : std_logic_vector(31 downto 0);
   signal fifo_empty           : std_logic;
   signal fifo_rderr           : std_logic;
   signal fifo_wrerr           : std_logic;
   signal fifo_almostfull      : std_logic;

   ------ input_ctrl ------
   signal input_ctrl_incomb_next_state    : INPUT_CTRL_STATE_type;
   signal input_ctrl_reg_cur_state_reg    : INPUT_CTRL_STATE_type;
   signal input_ctrl_outcomb_fifo_wren    : std_logic;
   signal input_ctrl_outcomb_fifo_data_in : std_logic_vector(31 downto 0);
   signal input_ctrl_outcomb_fifo_rst     : std_logic;
   signal input_ctrl_outcomb_read_next_block : std_logic;

   ------ output_ctrl ------
   signal output_ctrl_incomb_next_state   : OUTPUT_CTRL_STATE_type;
   signal output_ctrl_reg_cur_state_reg   : OUTPUT_CTRL_STATE_type;
   signal output_ctrl_outcomb_dec_cntr    : std_logic;
   signal output_ctrl_outcomb_set_cntr    : std_logic;
   signal output_ctrl_outcomb_fifo_rden   : std_logic;
   signal output_ctrl_outcomb_rdy_to_read_block : std_logic;
   signal output_ctrl_outcomb_icap_abort  : std_logic;

   ------ datareg ------
   signal datareg_reg1 : std_logic_vector(31 downto 0);
   signal datareg_reg2 : std_logic_vector(31 downto 0);
   signal datareg_reg3 : std_logic_vector(31 downto 0);

   ------ counter_reg ------
   signal counter_reg_cnt    : std_logic_vector(COUNTER_WIDTH_const-1 downto 0);
   signal counter_reg_iszero : std_logic;

   ------ system ------
   signal system_clk    : std_logic;
   signal system_rst    : std_logic;

   ------ inputs ------
   signal i_icap_tready        : std_logic;
   signal i_aes_data           : std_logic_vector(127 downto 0);
   signal i_aes_data_stb       : std_logic;
   signal i_aes_tag_valid      : std_logic;
   signal i_aes_tag_invalid    : std_logic;

   ------ outputs ------
   signal icap_tdata_o         : std_logic_vector(31 downto 0);
   signal icap_abort_o         : std_logic;
   signal icap_tvalid_o        : std_logic;
   signal aes_ready_o          : std_logic;
   signal aes_error_o          : std_logic;
   signal aes_empty_o          : std_logic;

begin

   -- Assign system signals
   system_clk <= clk;
   system_rst <= rst;

   -- Assign input signals
   i_icap_tready        <= icap_tready;
   i_aes_data           <= aes_data;
   i_aes_data_stb       <= aes_data_stb;
   i_aes_tag_valid      <= aes_tag_valid;
   i_aes_tag_invalid    <= aes_tag_invalid;

   -- Assign output signals
   icap_tdata        <= icap_tdata_o;
   icap_abort        <= icap_abort_o;
   icap_tvalid       <= icap_tvalid_o;
   aes_ready         <= aes_ready_o;
   aes_error         <= aes_error_o;
   aes_empty         <= aes_empty_o;

   -- Connect lower 32bit of output of 36kb FIFO to fifo_data_out (32bit)
   -- if the 36kb FIFO is instantiated, if not, fifo_data_out will be
   -- connected directly to the 18kb FIFO
   fifo_output_gen : if BYTES_PER_BLOCK_gen > 2048 generate
      fifo_data_out <= fifo_data_out_64bit(31 downto 0);
   end generate fifo_output_gen;

   -- If one chunk of decrypted data does not exceed 128*4 words = 512 words, use the
   -- smaller BRAM (18kb)
   fifo_18kb_gen: if BYTES_PER_BLOCK_gen <= 2048 generate
      fifo_inst : FIFO18E1
      generic map (
         ALMOST_EMPTY_OFFSET     => X"0001",       -- Sets the almost empty threshold
         ALMOST_FULL_OFFSET      => X"0003",       -- Sets almost full threshold
         DATA_WIDTH              => 36,            -- Sets data width to 4-36
         DO_REG                  => 0,             -- Enable output register (1-0) Must be 1 if EN_SYN = FALSE
         EN_SYN                  => TRUE,          -- Specifies FIFO as dual-clock (FALSE) or Synchronous (TRUE)
         FIFO_MODE               => "FIFO18_36",   -- Sets mode to FIFO18 or FIFO18_36
         FIRST_WORD_FALL_THROUGH => FALSE,         -- Sets the FIFO FWFT to FALSE, TRUE
         INIT                    => X"000000000",  -- Initial values on output port
         SIM_DEVICE              => "7SERIES",     -- Must be set to "7SERIES" for simulation behavior
         SRVAL                   => X"000000000"   -- Set/Reset value for output port
         )
      port map (
         -- Read Data: 32-bit (each) output: Read output data
         DO          => fifo_data_out,          -- 32-bit output: Data output
         DOP         => open,                   -- 4-bit output: Parity data output
         -- Status: 1-bit (each) output: Flags and other FIFO status outputs
         ALMOSTEMPTY => open,                   -- 1-bit output: Almost empty flag
         ALMOSTFULL  => fifo_almostfull,        -- 1-bit output: Almost full flag
         EMPTY       => fifo_empty,             -- 1-bit output: Empty flag
         FULL        => open,                   -- 1-bit output: Full flag
         RDCOUNT     => open,                   -- 12-bit output: Read count
         RDERR       => fifo_rderr,             -- 1-bit output: Read error
         WRCOUNT     => open,                   -- 12-bit output: Write count
         WRERR       => fifo_wrerr,             -- 1-bit output: Write error
         -- Read Control Signals: 1-bit (each) input: Read clock, enable and reset input signals
         RDCLK       => system_clk,             -- 1-bit input: Read clock
         RDEN        => output_ctrl_outcomb_fifo_rden,              -- 1-bit input: Read enable
         REGCE       => '1',                    -- 1-bit input: Clock enable
         RST         => input_ctrl_outcomb_fifo_rst,             -- 1-bit input: Asynchronous Reset
         RSTREG      => '0',                    -- 1-bit input: Output register set/reset
         -- Write Control Signals: 1-bit (each) input: Write clock and enable input signals
         WRCLK       => system_clk,             -- 1-bit input: Write clock
         WREN        => input_ctrl_outcomb_fifo_wren,              -- 1-bit input: Write enable
         -- Write Data: 32-bit (each) input: Write input data
         DI          => input_ctrl_outcomb_fifo_data_in,           -- 32-bit input: Data input
         DIP         => (others=>'0')           -- 4-bit input: Parity input
         );
      -- End of FIFO18E1_inst instantiation
   end generate fifo_18kb_gen;

   -- If one chunk of decrypted data exceeds 128*4 words = 512 words, use both
   -- BRAMs (36kb). (The makro below uses both BRAMs)
   fifo_32kb_gen: if BYTES_PER_BLOCK_gen > 2048 generate
      FIFO36E1_inst : FIFO36E1
      generic map (
         ALMOST_EMPTY_OFFSET     => X"0001",                -- Sets the almost empty threshold
         ALMOST_FULL_OFFSET      => X"0003",                -- Sets almost full threshold
         DATA_WIDTH              => 36,                     -- Sets data width to 4-72
         DO_REG                  => 0,                      -- Enable output register (1-0) Must be 1 if EN_SYN = FALSE
         EN_ECC_READ             => FALSE,                  -- Enable ECC decoder, FALSE, TRUE
         EN_ECC_WRITE            => FALSE,                  -- Enable ECC encoder, FALSE, TRUE
         EN_SYN                  => TRUE,                   -- Specifies FIFO as Asynchronous (FALSE) or Synchronous (TRUE)
         FIFO_MODE               => "FIFO36",               -- Sets mode to "FIFO36" or "FIFO36_72"
         FIRST_WORD_FALL_THROUGH => FALSE,                  -- Sets the FIFO FWFT to FALSE, TRUE
         INIT                    => X"000000000000000000",  -- Initial values on output port
         SIM_DEVICE              => "7SERIES",              -- Must be set to "7SERIES" for simulation behavior
         SRVAL                   => X"000000000000000000"   -- Set/Reset value for output port
         )
      port map (
         -- ECC Signals: 1-bit (each) output: Error Correction Circuitry ports
         DBITERR => open,              -- 1-bit output: Double bit error status
         ECCPARITY => open,          -- 8-bit output: Generated error correction parity
         SBITERR => open,              -- 1-bit output: Single bit error status
         -- Read Data: 64-bit (each) output: Read output data
         DO => fifo_data_out_64bit,                        -- 64-bit output: Data output
         DOP => open,                      -- 8-bit output: Parity data output
         -- Status: 1-bit (each) output: Flags and other FIFO status outputs
         ALMOSTEMPTY => open,      -- 1-bit output: Almost empty flag
         ALMOSTFULL => fifo_almostfull,        -- 1-bit output: Almost full flag
         EMPTY => fifo_empty,                  -- 1-bit output: Empty flag
         FULL => open,                    -- 1-bit output: Full flag
         RDCOUNT => open,              -- 13-bit output: Read count
         RDERR => fifo_rderr,                  -- 1-bit output: Read error
         WRCOUNT => open,              -- 13-bit output: Write count
         WRERR => fifo_wrerr,                  -- 1-bit output: Write error
         -- ECC Signals: 1-bit (each) input: Error Correction Circuitry ports
         INJECTDBITERR => '0',  -- 1-bit input: Inject a double bit error input
         INJECTSBITERR => '0',
         -- Read Control Signals: 1-bit (each) input: Read clock, enable and reset input signals
         RDCLK => system_clk,                  -- 1-bit input: Read clock
         RDEN => output_ctrl_outcomb_fifo_rden,                    -- 1-bit input: Read enable
         REGCE => '1',                  -- 1-bit input: Clock enable
         RST => input_ctrl_outcomb_fifo_rst,                      -- 1-bit input: Reset
         RSTREG => '0',                -- 1-bit input: Output register set/reset
         -- Write Control Signals: 1-bit (each) input: Write clock and enable input signals
         WRCLK => system_clk,                  -- 1-bit input: Rising edge write clock.
         WREN => input_ctrl_outcomb_fifo_wren,                    -- 1-bit input: Write enable
         -- Write Data: 64-bit (each) input: Write input data
         DI(31 downto 0) => input_ctrl_outcomb_fifo_data_in,                        -- 64-bit input: Data input
         DI(63 downto 32) => x"00000000",
         DIP => (others=>'0')                       -- 8-bit input: Parity input
         );
      -- End of FIFO36E1_inst instantiation
   end generate fifo_32kb_gen;

   -- Assert an error if one of the FSMs is in error state (The FSM goes into
   -- error state only if the FIFO signaled an read- or write error)
   aes_error_o <= '1' when input_ctrl_reg_cur_state_reg = INPUT_CTRL_STATE_ERROR
                           or output_ctrl_reg_cur_state_reg = OUTPUT_CTRL_STATE_ERROR
                      else '0';

   -- If the tag of the current block is not valid, abort the FPGA configuration.
   -- Also abort it if the FIFO is reset (in case the reset was during a config)
   --icap_abort_o <= '1' when system_rst = '0' or i_aes_tag_invalid = '1'
   --                    else '0';
   icap_abort_o <= output_ctrl_outcomb_icap_abort;

   -- New data can be written if input FSM is waiting for new data AND the FIFO
   -- has enougth free memory (at least four words)
   -- Check also output_ctrl_outcomb_rdy_to_read_block for the following scenario:
   --   Buffer has size of one block + 0...3 words, and the AES fills the buffer.
   --   AES writes last 128 bits and waits until buffer signals a ready, but the
   --   ready is only signaled when almostfull is low. The system will be in a
   --   dead loop. => ignore almostfull if output_ctrl_outcomb_rdy_to_read_block
   --                 is high.
   aes_ready_o <= '1' when input_ctrl_reg_cur_state_reg = INPUT_CTRL_STATE_IDLE
                           and (fifo_almostfull = '0' or output_ctrl_outcomb_rdy_to_read_block = '1')
                      else '0';

   icap_tdata_o <= fifo_data_out;

   icap_tvalid_o <= '1' when output_ctrl_reg_cur_state_reg = OUTPUT_CTRL_STATE_READ_BLOCK and i_icap_tready = '1'
                        else '0';

   aes_empty_o <= fifo_empty;

   input_ctrl_incomb_proc : process (input_ctrl_reg_cur_state_reg,
                                     i_aes_tag_invalid,
                                     i_aes_data_stb,
                                     output_ctrl_outcomb_rdy_to_read_block,
                                     i_aes_tag_valid)
   begin
      case input_ctrl_reg_cur_state_reg is
         when INPUT_CTRL_STATE_RST_BRAM_0 =>
            input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_RST_BRAM_1;

         when INPUT_CTRL_STATE_RST_BRAM_1 =>
            input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_RST_BRAM_2;

         when INPUT_CTRL_STATE_RST_BRAM_2 =>
            input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_RST_BRAM_3;

         when INPUT_CTRL_STATE_RST_BRAM_3 =>
            input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_RST_BRAM_4;

         when INPUT_CTRL_STATE_RST_BRAM_4 =>
            input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_RST_BRAM_5;

         when INPUT_CTRL_STATE_RST_BRAM_5 =>
            input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_WAIT_BRAM_RDY_0;

         when INPUT_CTRL_STATE_WAIT_BRAM_RDY_0 =>
            input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_WAIT_BRAM_RDY_1;

         when INPUT_CTRL_STATE_WAIT_BRAM_RDY_1 =>
            input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_IDLE;

         when INPUT_CTRL_STATE_IDLE =>
            if i_aes_tag_invalid = '1' then
               input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_RST_BRAM_0;
            elsif i_aes_tag_valid = '1' then
               input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_WAIT_PREV_BLOCK_SENT;
            elsif i_aes_data_stb = '1' then
               input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_WRITE_1;
            else
               input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_IDLE;
            end if;

         when INPUT_CTRL_STATE_WAIT_PREV_BLOCK_SENT =>
            -- Wait for output FSM
            if output_ctrl_outcomb_rdy_to_read_block = '1' then
               input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_IDLE;
            else
               input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_WAIT_PREV_BLOCK_SENT;
            end if;


         when INPUT_CTRL_STATE_WRITE_1 =>
               input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_WRITE_2;

         when INPUT_CTRL_STATE_WRITE_2 =>
               input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_WRITE_3;

         when INPUT_CTRL_STATE_WRITE_3 =>
               input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_IDLE;

         when INPUT_CTRL_STATE_ERROR =>
            input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_ERROR;

         when others =>
            input_ctrl_incomb_next_state <= INPUT_CTRL_STATE_RST_BRAM_0;

      end case;

   end process input_ctrl_incomb_proc;

   input_ctrl_outcomb_comb_proc : process (input_ctrl_reg_cur_state_reg,
                                           datareg_reg1,
                                           datareg_reg2,
                                           datareg_reg3,
                                           i_aes_data,
                                           i_aes_data_stb)
   begin
      case input_ctrl_reg_cur_state_reg is
         when INPUT_CTRL_STATE_WRITE_1 =>
            input_ctrl_outcomb_fifo_data_in <= datareg_reg1;

         when INPUT_CTRL_STATE_WRITE_2 =>
            input_ctrl_outcomb_fifo_data_in <= datareg_reg2;

         when INPUT_CTRL_STATE_WRITE_3 =>
            input_ctrl_outcomb_fifo_data_in <= datareg_reg3;

         when others =>
            input_ctrl_outcomb_fifo_data_in <= i_aes_data(127 downto 96);

      end case;

      case input_ctrl_reg_cur_state_reg is
         when INPUT_CTRL_STATE_WRITE_1 =>
            input_ctrl_outcomb_fifo_wren <= '1';

         when INPUT_CTRL_STATE_WRITE_2 =>
            input_ctrl_outcomb_fifo_wren <= '1';

         when INPUT_CTRL_STATE_WRITE_3 =>
            input_ctrl_outcomb_fifo_wren <= '1';

         when INPUT_CTRL_STATE_IDLE =>
            input_ctrl_outcomb_fifo_wren <= i_aes_data_stb;

         when others =>
            input_ctrl_outcomb_fifo_wren <= '0';

      end case;

      case input_ctrl_reg_cur_state_reg is
         when INPUT_CTRL_STATE_RST_BRAM_0 =>
            input_ctrl_outcomb_fifo_rst <= '1';

         when INPUT_CTRL_STATE_RST_BRAM_1 =>
            input_ctrl_outcomb_fifo_rst <= '1';

         when INPUT_CTRL_STATE_RST_BRAM_2 =>
            input_ctrl_outcomb_fifo_rst <= '1';

         when INPUT_CTRL_STATE_RST_BRAM_3 =>
            input_ctrl_outcomb_fifo_rst <= '1';

         when INPUT_CTRL_STATE_RST_BRAM_4 =>
            input_ctrl_outcomb_fifo_rst <= '1';

         when INPUT_CTRL_STATE_RST_BRAM_5 =>
            input_ctrl_outcomb_fifo_rst <= '1';

         when others =>
            input_ctrl_outcomb_fifo_rst <= '0';

      end case;

      if input_ctrl_reg_cur_state_reg = INPUT_CTRL_STATE_WAIT_PREV_BLOCK_SENT then
         input_ctrl_outcomb_read_next_block <= '1';
      else
         input_ctrl_outcomb_read_next_block <= '0';
      end if;

   end process input_ctrl_outcomb_comb_proc;


   input_ctrl_reg_proc : process (system_clk, system_rst, input_ctrl_incomb_next_state)
   begin
      if rising_edge(system_clk) then
         if system_rst = '0' then
            input_ctrl_reg_cur_state_reg <= INPUT_CTRL_STATE_RST_BRAM_0;
         else
            input_ctrl_reg_cur_state_reg <= input_ctrl_incomb_next_state;
         end if;
      else
         null;
      end if;
   end process input_ctrl_reg_proc;


   datareg_proc : process (system_clk, system_rst, i_aes_data, i_aes_data_stb, datareg_reg1, datareg_reg2, datareg_reg3)
   begin
      if rising_edge(system_clk) then
         if system_rst = '0' then
            datareg_reg1 <= (others=>'0');
            datareg_reg2 <= (others=>'0');
            datareg_reg3 <= (others=>'0');
         else
            if i_aes_data_stb = '1' then
               datareg_reg1 <= i_aes_data(95 downto 64);
               datareg_reg2 <= i_aes_data(63 downto 32);
               datareg_reg3 <= i_aes_data(31 downto 0);
            else
               null;
            end if;
         end if;
      else
         null;
      end if;
   end process datareg_proc;





   output_ctrl_incomb_proc : process ( output_ctrl_reg_cur_state_reg,
                                       i_icap_tready,
                                       counter_reg_iszero,
                                       fifo_rderr,
                                       fifo_empty,
                                       i_aes_tag_valid,
                                       i_aes_tag_invalid,
                                       input_ctrl_outcomb_read_next_block)
   begin
      case output_ctrl_reg_cur_state_reg is
         when OUTPUT_CTRL_STATE_RESET =>
            output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_WAIT_ICAP_RDY;

         when OUTPUT_CTRL_STATE_WAIT_ICAP_RDY =>
            if i_aes_tag_invalid = '1' then
               output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_RESET;
            else
               if i_icap_tready = '1' then
                  output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_IDLE;
               else
                  output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_WAIT_ICAP_RDY;
               end if;
            end if;

         when OUTPUT_CTRL_STATE_IDLE =>
            if fifo_rderr = '1' then
               output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_ERROR;
            else
               if i_aes_tag_invalid = '1' then
                  output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_RESET;
               else
                  -- Wait for input FSM (until tag_valid was signaled)
                  if input_ctrl_outcomb_read_next_block = '1' then
                     output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_READ_BLOCK;
                  else
                     output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_IDLE;
                  end if;
               end if;
            end if;

         when OUTPUT_CTRL_STATE_READ_BLOCK =>
            if fifo_rderr = '1' then
               output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_ERROR;
            else
               if i_aes_tag_invalid = '1' then
                  output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_RESET;
               else
                  if fifo_empty = '1' then
                     output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_IDLE;
                  else
                     if counter_reg_iszero = '1' then
                        output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_IDLE;
                     else
                        output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_READ_BLOCK;
                     end if;
                  end if;
               end if;
            end if;

         when OUTPUT_CTRL_STATE_ERROR =>
            output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_ERROR;

         when others =>
            output_ctrl_incomb_next_state <= OUTPUT_CTRL_STATE_ERROR;

      end case;

   end process output_ctrl_incomb_proc;

   output_ctrl_outcomb_comb_proc : process (output_ctrl_reg_cur_state_reg, i_icap_tready, i_aes_tag_valid, counter_reg_iszero, fifo_empty, input_ctrl_outcomb_read_next_block)
   begin
      case output_ctrl_reg_cur_state_reg is
         when OUTPUT_CTRL_STATE_RESET =>
            output_ctrl_outcomb_dec_cntr  <= '0';
            output_ctrl_outcomb_set_cntr  <= '0';
            output_ctrl_outcomb_fifo_rden <= '0';
            output_ctrl_outcomb_rdy_to_read_block <= '0';
            output_ctrl_outcomb_icap_abort <= '1';

         when OUTPUT_CTRL_STATE_WAIT_ICAP_RDY =>
            output_ctrl_outcomb_dec_cntr  <= '0';
            output_ctrl_outcomb_set_cntr  <= '0';
            output_ctrl_outcomb_fifo_rden <= '0';
            output_ctrl_outcomb_rdy_to_read_block <= '0';
            output_ctrl_outcomb_icap_abort <= '0';

         when OUTPUT_CTRL_STATE_IDLE =>
            output_ctrl_outcomb_dec_cntr  <= '0';
            output_ctrl_outcomb_set_cntr  <= '1';
            output_ctrl_outcomb_fifo_rden <= input_ctrl_outcomb_read_next_block;
            output_ctrl_outcomb_rdy_to_read_block <= '1';
            output_ctrl_outcomb_icap_abort <= '0';

         when OUTPUT_CTRL_STATE_READ_BLOCK =>
            output_ctrl_outcomb_dec_cntr  <= i_icap_tready;
            output_ctrl_outcomb_set_cntr  <= '0';
            output_ctrl_outcomb_fifo_rden <= i_icap_tready and not counter_reg_iszero and not fifo_empty; -- don't enable read at last word (when buffer is empty and FSM goes back to IDLE)
            output_ctrl_outcomb_rdy_to_read_block <= '0';
            output_ctrl_outcomb_icap_abort <= '0';

         when OUTPUT_CTRL_STATE_ERROR =>
            output_ctrl_outcomb_dec_cntr  <= '0';
            output_ctrl_outcomb_set_cntr  <= '0';
            output_ctrl_outcomb_fifo_rden <= '0';
            output_ctrl_outcomb_rdy_to_read_block <= '0';
            output_ctrl_outcomb_icap_abort <= '0';

         when others =>
            output_ctrl_outcomb_dec_cntr  <= '0';
            output_ctrl_outcomb_set_cntr  <= '0';
            output_ctrl_outcomb_fifo_rden <= '0';
            output_ctrl_outcomb_rdy_to_read_block <= '0';
            output_ctrl_outcomb_icap_abort <= '0';

      end case;
   end process output_ctrl_outcomb_comb_proc;

   output_ctrl_reg_proc : process (system_clk, system_rst, output_ctrl_incomb_next_state)
   begin
      if rising_edge(system_clk) then
         if system_rst = '0' then
            output_ctrl_reg_cur_state_reg <= OUTPUT_CTRL_STATE_RESET;
         else
            output_ctrl_reg_cur_state_reg <= output_ctrl_incomb_next_state;
         end if;
      else
         null;
      end if;
   end process output_ctrl_reg_proc;

   counter_reg_proc : process(system_clk,
                              output_ctrl_outcomb_dec_cntr,
                              output_ctrl_outcomb_set_cntr,
                              counter_reg_cnt)
   begin
      if rising_edge(system_clk) then
         if output_ctrl_outcomb_set_cntr = '1' then
            counter_reg_cnt <= std_logic_vector(to_unsigned(COUNTER_PREVAL_const, COUNTER_WIDTH_const));
         elsif output_ctrl_outcomb_dec_cntr = '1' then
            counter_reg_cnt <= std_logic_vector(unsigned(counter_reg_cnt) - 1);
         else
            null;
         end if;
      else
         null;
      end if;

      if counter_reg_cnt = std_logic_vector(to_unsigned(0, COUNTER_WIDTH_const)) then
         counter_reg_iszero <= '1';
      else
         counter_reg_iszero <= '0';
      end if;
   end process counter_reg_proc;



end Behavioral;
