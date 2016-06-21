--
-- Copyright 1991-2014 Mentor Graphics Corporation
--
-- All Rights Reserved.
--
-- THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
-- MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
--   
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity random is
  port ( clk : in std_logic;
         random_num : out std_logic_vector (31 downto 0));
end entity random;

architecture Behavioral of random is
  begin
  gen : process(clk)
    --variable rand_temp : std_logic_vector(31 downto 0):=(31 => '1',others => '0');
    variable rand_temp : std_logic_vector(31 downto 0):= x"A84126C1";
    variable temp : std_logic := '0';
    begin
    if(rising_edge(clk)) then
      temp := rand_temp(31) xor rand_temp(30);
      rand_temp(31 downto 1) := rand_temp(30 downto 0);
      rand_temp(0) := temp;
    end if;
    random_num <= rand_temp;
  end process gen;
end architecture Behavioral;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MR25H10_rand is
  port ( SCK  : IN  std_logic; -- Serial clock input
         SI   : IN  std_logic; -- VHDLSerial data input
         SO   : OUT std_logic; -- Serial Data Out
         CS   : IN  std_logic; -- Chip select input
         HOLD : IN  std_logic; -- Hold input
         WP   : IN  std_logic); -- Write protect input 
end entity MR25H10_rand;

architecture Behavioral of MR25H10_rand is

  component random is
    port ( clk : in std_logic;
           random_num : out std_logic_vector (31 downto 0));
  end component random;

  signal rand_num_i : std_logic_vector(31 downto 0) := x"00000000";

  begin

  -- SPI FRAM device (manufacturer simulation)
  generator: random 
    port map ( clk  => SCK, 
               random_num => rand_num_i );

  process(SCK)
    begin
    if (SCK'event) then 
      if CS = '0' then
        SO <= rand_num_i(0);
      else
        SO <= 'Z'; -- tristate
      end if;          
    end if;
  end process;
end architecture Behavioral;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity test_spi_fram_intf is
    port ( rdy : buffer std_logic );
end;


architecture only of test_spi_fram_intf is

  component MR25H10_rand IS
    port ( SCK  : IN  std_logic; -- Serial clock input
           SI   : IN  std_logic; -- VHDLSerial data input
           SO   : OUT std_logic; -- Serial Data Out
           CS   : IN  std_logic; -- Chip select input
           HOLD : IN  std_logic; -- Hold input
           WP   : IN  std_logic); -- Write protect input 
  end component MR25H10_rand;
  
  component spi_fram_intf is
    port ( FRAM_INTF_CLK     : in std_logic;
           FRAM_INTF_RST_N   : in std_logic;
           FRAM_INTF_SEL     : in std_logic;
           FRAM_INTF_WR      : in std_logic;
           FRAM_INTF_RDY     : out std_logic;
           FRAM_INTF_ADDR    : in std_logic_vector(15 downto 0);
           FRAM_INTF_RD_DATA : out std_logic_vector(7 downto 0);
           FRAM_INTF_WR_DATA : in  std_logic_vector(7 downto 0);
           SPI_FRAM_CS_N     : out std_logic;
           SPI_FRAM_CLK      : out std_logic;
           SPI_FRAM_SO       : in std_logic;
           SPI_FRAM_SI       : out std_logic );
  end component spi_fram_intf;

  signal clk     : std_logic := '0';
  signal reset_n : std_logic := '1';

  signal spi_fram_cs_n : std_logic := '1';
  signal spi_fram_clk  : std_logic := '1';
  signal spi_fram_so   : std_logic;
  signal spi_fram_si   : std_logic;

  signal sib_sel : std_logic := '0';
  signal sib_wr  : std_logic := '0' ;
  signal sib_rdy : std_logic;
  signal sib_addr : std_logic_vector(15 downto 0) := x"0100";
  signal sib_rd_data : std_logic_vector(7 downto 0);
  signal sib_wr_data : std_logic_vector(7 downto 0) := x"AB";

  begin

  -- dut: device under test
  DUT : spi_fram_intf 
    port map ( FRAM_INTF_CLK => clk,
               FRAM_INTF_RST_N => reset_n,
               FRAM_INTF_SEL => sib_sel,
               FRAM_INTF_WR => sib_wr,
               FRAM_INTF_RDY => sib_rdy,
               FRAM_INTF_ADDR => sib_addr,
               FRAM_INTF_RD_DATA => sib_rd_data,
               FRAM_INTF_WR_DATA => sib_wr_data,
               SPI_FRAM_CS_N => spi_fram_cs_n,
               SPI_FRAM_CLK => spi_fram_clk,
               SPI_FRAM_SO => spi_fram_so,
               SPI_FRAM_SI => spi_fram_si );

  -- SPI FRAM device (manufacturer simulation)
  SPI_FRAM: MR25H10_rand
    port map ( SCK => spi_fram_clk, 
               SI => spi_fram_si,
               SO => spi_fram_so,
               CS => spi_fram_cs_n, 
               HOLD => '1',
               WP => '1' );
  

  -- simulated system clock
  clock : process
    begin
    wait for 10 ns; clk  <= not clk;
  end process clock;

  stimulus : process
    begin
    wait for 5  ns; reset_n  <= '0';
    wait for 10 ns; reset_n  <= '1';
    wait for 50 ns; 

    assert sib_rdy = '1'  
      report "spi fram intf not ready (SIB_RDY deasserted)"
      severity WARNING;

    wait for 10 ns; 
    sib_wr <= '1';
    sib_sel <= '1';

    -- delay to prevent next line from triggering too early
    wait for 100 ns; 
    wait until sib_rdy = '1'; 
    sib_sel <= '0';

    -- setup read address 0101 hex and assert SELECT
    wait for 100 ns; 
    sib_addr <= x"0101"; 
    sib_wr <= '0'; 
    sib_sel <= '1';

    wait for 100 ns; 
    wait until sib_rdy = '1';
    sib_sel <= '0';

    wait;
  end process stimulus;
 
  rdy <= sib_rdy;

end only;

