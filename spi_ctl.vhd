----------------------------------------------------------------------
-- Title      : Serial Peripheral Interface Control (spi_ctl)
-- Project    : platform motor controller
----------------------------------------------------------------------
-- File       : spi_ctl.vhd
-- Author     : jmorro (Jerry Morrow)
-- Language   : VHDL 1993
----------------------------------------------------------------------
-- Description: 
--   This module implements the SPI
--   FRAM interface.
--
-- Synthesis Notes:
--   None.
----------------------------------------------------------------------
-- Requirements:
--
--   <Identify any requirements that are implemented>
----------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-10-29        1  jmorro   Created
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- SPI Controller 
-- 
entity spi_ctrl is

  port ( 
    -- SYSTEM CLOCK AND RESET
    SYSCLK     : in std_logic;
    RST_N      : in std_logic;

    -- SPI FRAM I/O 
    CS_N       : out std_logic;   
    SCLK       : out std_logic := '1'; -- SPI MODE 3, clock asserted   
    MOSI       : out std_logic;   
    MISO       : in std_logic;   

    -- FRAM Control, (SPI) Transaction Start, Complete, and Size 
    TSTART     : in std_logic;
    TCOMP      : out std_logic;
    TSIZE      : in unsigned(1 downto 0); 

    -- master out (FPGA), slave in (FRAM) : 0-first out, 3-last out
    MOSI0      : in std_logic_vector(7 downto 0);
    MOSI1      : in std_logic_vector(7 downto 0);
    MOSI2      : in std_logic_vector(7 downto 0);
    MOSI3      : in std_logic_vector(7 downto 0);

    -- master in (FPGA), slave out (from FRAM) : 0-first in, 3-last in
    MISO0      : out std_logic_vector(7 downto 0);
    MISO1      : out std_logic_vector(7 downto 0);
    MISO2      : out std_logic_vector(7 downto 0);
    MISO3      : out std_logic_vector(7 downto 0) );

end entity spi_ctrl;

architecture rtl of spi_ctrl is 

  type SPI_CTRL_STATE_T is 
  ( SPI_CTRL_STATE_WAIT_TSTART_ASSERT, 
    SPI_CTRL_STATE_CLOCKING, 
    SPI_CTRL_STATE_WAIT_TSTART_DEASSERT);

  signal spi_ctl_curr_state_q : SPI_CTRL_STATE_T;
  signal spi_ctl_next_state_i : SPI_CTRL_STATE_T;

  -- clock count, used for clock divider
  signal clkcnt: std_logic_vector(7 downto 0) := "00000000" ; 

  -- SPI shift registers
  signal mosi32: std_logic_vector(31 downto 0) := x"FFFFFFFF" ; 
  signal miso32: std_logic_vector(31 downto 0) := x"FFFFFFFF" ; 

  -- internal clock source
  signal clk       : std_logic := '0';   

   -- serial clock (SPI Mode 3, initialized to logic 1) 
  signal sclk_sig  : std_logic := '1';   
  signal cs_n_sig  : std_logic := '1';  -- chip select signal

  signal shift_done : std_logic := '0';  

  -- bit counter  
  constant ONE_WORD_C    : unsigned (7 downto 0) := TO_UNSIGNED(8,8); 
  constant TWO_WORDS_C   : unsigned (7 downto 0) := TO_UNSIGNED(16,8); 
  constant THREE_WORDS_C : unsigned (7 downto 0) := TO_UNSIGNED(24,8); 
  constant FOUR_WORDS_C  : unsigned (7 downto 0) := TO_UNSIGNED(32,8); 

  signal   bit_ctr    : unsigned (7 downto 0) := TO_UNSIGNED(0,8); 
  -- SPI transaction size in bits
  signal   num_bits   : unsigned (7 downto 0) := TO_UNSIGNED(0,8); 

  begin 

  clock_divider: process (SYSCLK)
  begin
    if SYSCLK'event and SYSCLK = '1' then
      clkcnt <= std_logic_vector(unsigned(clkcnt) + 1);
    end if; 
  end process clock_divider; 

  -- clk is 8x slower than SYSCLK
  clk <= clkcnt(3); 
  -- SPI clock is gated by SPI chip select
  sclk_sig <= clk or cs_n_sig;

  spi_ctl_clk : process (clk) is
  begin  
    if clk'event and clk = '0' then -- falling clock edge
      if spi_ctl_curr_state_q = SPI_CTRL_STATE_CLOCKING then 
        if cs_n_sig = '1' then 
          -- latch MOSI register
          mosi32 <= MOSI0 & MOSI1 & MOSI2 & MOSI3;
          bit_ctr <= TO_UNSIGNED(0,8); -- zero
	  cs_n_sig <= '0';
        elsif cs_n_sig = '0' then
	  if bit_ctr = num_bits then	
            cs_n_sig <= '1'; 
            shift_done <= '1'; 
          else
            -- shift left MOSI and MISO 
            mosi32 <= mosi32(30 downto 0) & '0'; 
            miso32 <= miso32(30 downto 0) & '0'; 
	  end if;
        end if;
      else
        shift_done <= '0'; -- reset shift_done flag
        bit_ctr <= TO_UNSIGNED(0,8); -- zero
      end if;
    elsif clk'event and clk = '1' then  -- rising clock edge
      if spi_ctl_curr_state_q = SPI_CTRL_STATE_CLOCKING and cs_n_sig = '0' then
        -- latch MISO into LSB of miso32 and increment bit counter 
        miso32(0) <= MISO;
        bit_ctr <= bit_ctr + 1;
      end if;
    end if;
  end process spi_ctl_clk;

  -- Combinatorial process to determine the next
  -- state and the outputs of the FSM
  spi_ctl_state_logic : process (spi_ctl_curr_state_q,TSTART,shift_done) 
  begin  -- process spi_ctl_state_logic

    -- initialize next state to current state (default)
    spi_ctl_next_state_i <= spi_ctl_curr_state_q;

    case spi_ctl_curr_state_q is
      when SPI_CTRL_STATE_WAIT_TSTART_ASSERT =>
        TCOMP <= '1';  -- waiting for SPI transaction start 

        if TSTART = '1' and shift_done = '0' then 
          spi_ctl_next_state_i <= SPI_CTRL_STATE_CLOCKING;
        end if;

      when SPI_CTRL_STATE_CLOCKING =>
        TCOMP <= '0'; -- transfer in progress 

	-- signal from shifter
	if shift_done = '1' then
          -- exit clocking state 
          spi_ctl_next_state_i <= SPI_CTRL_STATE_WAIT_TSTART_DEASSERT;
        end if;

      when SPI_CTRL_STATE_WAIT_TSTART_DEASSERT =>
        TCOMP <= '1'; -- transfer ending 

        if TSTART = '0' then 
          spi_ctl_next_state_i <= SPI_CTRL_STATE_WAIT_TSTART_ASSERT;
        end if;
         
    end case; -- spi_ctl_curr_state_q
  end process spi_ctl_state_logic;

  process (RST_N, SYSCLK) is
    begin  -- process reset/sysclock
    if RST_N = '0' then 
      --cs_n_sig <= '1'; -- deselect SPI FRAM
      --bit_ctr <= TO_UNSIGNED(0,5); -- reset bit counter and transaction size (bits)  
      --num_bits <= TO_UNSIGNED(0,5); 
      spi_ctl_curr_state_q <= SPI_CTRL_STATE_WAIT_TSTART_ASSERT;
    elsif SYSCLK'event and SYSCLK = '1' then
      spi_ctl_curr_state_q <= spi_ctl_next_state_i;

      if TSTART = '1' then 
        -- start transaction, latch TSIZE and MOSI0-MOSI3  
        case TSIZE is 
          when "00" => num_bits <= ONE_WORD_C;
          when "01" => num_bits <= TWO_WORDS_C;
          when "10" => num_bits <= THREE_WORDS_C;
          when "11" => num_bits <= FOUR_WORDS_C;
          when others => null; 
        end case;
      end if;
    end if;
  end process;

  -- always output MISO, it will be latched by FRAM Controller when TCOMP is set
  MISO0 <= miso32(31 downto 24);
  MISO1 <= miso32(23 downto 16);
  MISO2 <= miso32(15 downto 8);
  MISO3 <= miso32(7 downto 0);

  MOSI <= mosi32(31); -- route MSB of MOSI32 to MOSI output  
  CS_N <= cs_n_sig;
  SCLK <= sclk_sig ; 

end architecture rtl;
