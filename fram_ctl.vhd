----------------------------------------------------------------------
-- Title      : FRAM Controller (fram_ctrl)
-- Project    : platform motor controller
----------------------------------------------------------------------
-- File       : fram_ctrl.vhd
-- Author     : jmorro (Jerry Morrow)
-- Language   : VHDL 1993
----------------------------------------------------------------------
-- Description: 
--   This module implements the system interface bus (SIB) to
--   FRAM interface, via SPI CTRL.
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

entity fram_ctrl is
		
  port ( 
    -- SYSTEM CLOCK AND RESET
    FRAM_CLK     : in std_logic;
    FRAM_RST_N   : in std_logic;

    -- SIB INTERFACE CONTROL
    FRAM_SEL     : in std_logic;
    FRAM_WR      : in std_logic;
    FRAM_RDY     : out std_logic := '0';

    -- SIB INTERFACE ADDR/DATA
    FRAM_ADDR    : in std_logic_vector(15 downto 0);
    FRAM_RD_DATA : out std_logic_vector(7 downto 0) := "ZZZZZZZZ";
    FRAM_WR_DATA : in  std_logic_vector(7 downto 0);

    -- SPI FRAM  
    MOSI0   : out std_logic_vector(7 downto 0) := x"FF";
    MOSI1   : out std_logic_vector(7 downto 0) := x"FF";
    MOSI2   : out std_logic_vector(7 downto 0) := x"FF";
    MOSI3   : out std_logic_vector(7 downto 0) := x"FF";
  
    MISO0   : in std_logic_vector(7 downto 0);
    MISO1   : in std_logic_vector(7 downto 0);
    MISO2   : in std_logic_vector(7 downto 0);
    MISO3   : in std_logic_vector(7 downto 0);

    TSTART  : out std_logic := '0'; 
    TCOMP   : in  std_logic;
    TSIZE   : out unsigned(1 downto 0) := TO_UNSIGNED(0,2) );

end entity fram_ctrl;

architecture rtl of fram_ctrl is

  ---------------------------------------------------------
  -- CONSTANTS AND ENUMERATIONS
  ---------------------------------------------------------
  -- 0--> 1 byte: write enable SPI transaction size
  constant WREN_TSIZE_C : unsigned(1 downto 0) := TO_UNSIGNED(0,2); 
  -- 1--> 2 bytes: read status register SPI transaction size
  constant RDSR_TSIZE_C : unsigned(1 downto 0) := TO_UNSIGNED(1,2); 
  -- 1--> 2 bytes: write status register SPI transaction size
  constant WRSR_TSIZE_C : unsigned(1 downto 0) := TO_UNSIGNED(1,2); 
  -- 3--> 4 bytes: memory write SPI transaction size
  constant WRITE_TSIZE_C : unsigned(1 downto 0) := TO_UNSIGNED(3,2); 
  -- 3--> 4 bytes: memory write SPI transaction size
  constant READ_TSIZE_C : unsigned(1 downto 0) := TO_UNSIGNED(3,2); 

  constant FRAM_CTL_READY_C : std_logic := '1';
  constant FRAM_CTL_BUSY_C  : std_logic := '0';

  -- FRAM OPCODES 
  constant OPCODE_WREN_C  : std_logic_vector(7 downto 0) := "00000110";
  constant OPCODE_WRDI_C  : std_logic_vector(7 downto 0) := "00000100";
  constant OPCODE_RDSR_C  : std_logic_vector(7 downto 0) := "00000101";
  constant OPCODE_WRSR_C  : std_logic_vector(7 downto 0) := "00000001";
  constant OPCODE_READ_C  : std_logic_vector(7 downto 0) := "00000011";
  constant OPCODE_WRITE_C : std_logic_vector(7 downto 0) := "00000010";

  type FRAM_CTRL_STATE_T is 
  ( FRAM_CTRL_STATE_WAIT_SIB_SEL, 
    FRAM_CTRL_STATE_WAIT_WRITE_EN, 
    FRAM_CTRL_STATE_WAIT_BETWEEN, 
    FRAM_CTRL_STATE_WAIT_READ_WRITE,
    FRAM_CTRL_STATE_WAIT_SIB_DESEL );

  ---------------------------------------------------------
  -- INTERNAL SIGNALS 
  ---------------------------------------------------------

  signal fram_ctl_curr_state_q : FRAM_CTRL_STATE_T;
  signal fram_ctl_next_state_i : FRAM_CTRL_STATE_T;

  signal fram_addr_i 	: std_logic_vector(15 downto 0);
  signal fram_wr_i      : std_logic := '0';
  signal fram_rd_data_i : std_logic_vector(7 downto 0) := "ZZZZZZZZ";
  signal fram_wr_data_i : std_logic_vector(7 downto 0)  ;

begin  -- architecture rtl

  -- FINITE STATE MACHINE

  -- Clocked process to register the current state and latch inputs 
  sequential : process (FRAM_CLK, FRAM_RST_N) is
  begin  -- process registered
    if FRAM_RST_N = '0' then  -- asynchronous reset (active low)
      fram_ctl_curr_state_q <= FRAM_CTRL_STATE_WAIT_SIB_SEL;
      fram_rd_data_i <= "ZZZZZZZZ"; 
    elsif FRAM_CLK'event and FRAM_CLK = '1' then  -- rising clock edge
      -- latch next state 
      fram_ctl_curr_state_q <= fram_ctl_next_state_i;

      if (FRAM_SEL = '1') then
	-- latch address, read/write, and data when select is enabled
        fram_addr_i <= FRAM_ADDR;
        fram_wr_i <= FRAM_WR;
        fram_wr_data_i <= FRAM_WR_DATA;
      end if;
    end if;
  end process sequential;

  -- Combinatorial process to determine the next
  -- state and the outputs of the FSM
  fram_ctl_state_logic : process (fram_ctl_curr_state_q, FRAM_SEL, TCOMP) is
  begin  -- process fram_ctl_state_logic

    fram_ctl_next_state_i <= fram_ctl_curr_state_q;

    case fram_ctl_curr_state_q is
      when FRAM_CTRL_STATE_WAIT_SIB_SEL =>
        FRAM_RDY <= FRAM_CTL_READY_C;  
        TSTART <= '0';
	TSIZE  <= "00";

        if FRAM_SEL = '1' then 
	  if FRAM_WR = '1' then 
            -- setup write enable command
            fram_ctl_next_state_i <= FRAM_CTRL_STATE_WAIT_WRITE_EN;
          else
            -- setup read command 
            fram_ctl_next_state_i <= FRAM_CTRL_STATE_WAIT_READ_WRITE;
	  end if;
        end if;

      when FRAM_CTRL_STATE_WAIT_WRITE_EN =>
        FRAM_RDY <= FRAM_CTL_BUSY_C;  
	MOSI0  <= OPCODE_WREN_C;
	TSIZE  <= WREN_TSIZE_C;
        TSTART <= '1';

        if TCOMP'event and TCOMP = '1' then  -- on TRANSFER COMPLETE assertion 
          -- setup write command 
          fram_ctl_next_state_i <= FRAM_CTRL_STATE_WAIT_BETWEEN;
        end if;

      when FRAM_CTRL_STATE_WAIT_BETWEEN =>
        -- stay in this state at one clock cycle
        FRAM_RDY <= FRAM_CTL_BUSY_C;  
        TSTART <= '0';
        fram_ctl_next_state_i <= FRAM_CTRL_STATE_WAIT_READ_WRITE;
      
      when FRAM_CTRL_STATE_WAIT_READ_WRITE =>
     
        FRAM_RDY <= FRAM_CTL_BUSY_C;  

	-- output address on MOSI1/MOSI2 for either read or write
        MOSI1 <= fram_addr_i(15 downto 8); 
        MOSI2 <= fram_addr_i(7 downto 0); 

	-- setup for write or read (different opcodes, sizes)
	if fram_wr_i = '1' then
          MOSI0  <= OPCODE_WRITE_C;
          MOSI3  <= fram_wr_data_i;
          TSIZE  <= WRITE_TSIZE_C;
        else
          MOSI0  <= OPCODE_READ_C;
	  TSIZE  <= READ_TSIZE_C;
          MOSI3  <= x"00";
        end if;

	-- start transfer
        TSTART <= '1'; 

        if TCOMP'event and TCOMP = '1' then  -- on TRANSFER COMPLETE assertion 
	  if fram_wr_i = '0' then 
            -- latch read data from SPI CTRL 
	    fram_rd_data <= MISO3; 
	  end if;

	  -- go to wait for deselect state
          fram_ctl_next_state_i <= FRAM_CTRL_STATE_WAIT_SIB_DESEL;
        end if;

      when FRAM_CTRL_STATE_WAIT_SIB_DESEL =>
        FRAM_RDY <= FRAM_CTL_READY_C;
        -- reset TSIZE/TSTART	
	TSIZE <= "00";
        TSTART <= '0';

        if FRAM_SEL = '0' then  -- on SELECT deassertion 
          fram_rd_data_i <= "ZZZZZZZZ";
          fram_ctl_next_state_i <= FRAM_CTRL_STATE_WAIT_SIB_SEL;
        end if;
       
    end case;
  end process fram_ctl_state_logic;

  FRAM_RD_DATA <= fram_rd_data_i; 

end architecture rtl;


