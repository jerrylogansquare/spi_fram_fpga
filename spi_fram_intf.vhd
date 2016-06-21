----------------------------------------------------------------------
-- Title      : Serial Peripheral Interface FRAM Interface(spi_fram_intf)
-- Project    : platform motor controller
----------------------------------------------------------------------
-- File       : spi_fram_intf.vhd
-- Author     : jmorrow
-- Language   : VHDL 1993
----------------------------------------------------------------------
-- Description: 
--   This module implements the system interface bus (SIB) to SPI
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

entity spi_fram_intf is
		
  port ( 
		-- SYSTEM CLOCK AND RESET
    FRAM_INTF_CLK     : in std_logic;
    FRAM_INTF_RST_N   : in std_logic;

    -- SIB INTERFACE CONTROL
    FRAM_INTF_SEL     : in std_logic;
    FRAM_INTF_WR      : in std_logic;
    FRAM_INTF_RDY     : out std_logic;

    -- SIB INTERFACE ADDR/DATA
    FRAM_INTF_ADDR    : in std_logic_vector(15 downto 0);
    FRAM_INTF_RD_DATA : out std_logic_vector(7 downto 0);
    FRAM_INTF_WR_DATA : in  std_logic_vector(7 downto 0);

    -- SPI FRAM  
    SPI_FRAM_CS_N : out std_logic;
    SPI_FRAM_CLK  : out std_logic;
    SPI_FRAM_SO   : in std_logic;
    SPI_FRAM_SI   : out std_logic );

end entity spi_fram_intf;

architecture rtl of spi_fram_intf is

  component spi_ctrl is
    port ( SYSCLK, RST_N, MISO, TSTART : in std_logic;
           CS_N, SCLK, MOSI, TCOMP : out std_logic;   
           TSIZE : in unsigned(1 downto 0); 
           MOSI0, MOSI1, MOSI2, MOSI3 : in std_logic_vector(7 downto 0);
           MISO0, MISO1, MISO2, MISO3 : out std_logic_vector(7 downto 0) );
  end component;

  component fram_ctrl is
     port ( FRAM_CLK, FRAM_RST_N, FRAM_SEL, FRAM_WR, TCOMP : in std_logic;
            FRAM_RDY, TSTART : out std_logic;
            FRAM_ADDR : in  std_logic_vector(15 downto 0);        
            FRAM_WR_DATA : in  std_logic_vector(7 downto 0);        
            FRAM_RD_DATA : out std_logic_vector(7 downto 0);
            MOSI0, MOSI1, MOSI2, MOSI3 : out std_logic_vector(7 downto 0);
            MISO0, MISO1, MISO2, MISO3 : in std_logic_vector(7 downto 0);
            TSIZE   : out unsigned(1 downto 0) ); 
  end component;

  signal mosi0, mosi1, mosi2, mosi3 : std_logic_vector(7 downto 0);
  signal miso0, miso1, miso2, miso3 : std_logic_vector(7 downto 0);
  signal tsize : unsigned(1 downto 0);  
  signal tstart, tcomp : std_logic;

  begin
  -- instantiate FRAM CONTROLLER and map
  FC0: fram_ctrl port map ( FRAM_CLK => FRAM_INTF_CLK,
                            FRAM_RST_N => FRAM_INTF_RST_N,   
                            FRAM_SEL => FRAM_INTF_SEL, 
                            FRAM_WR => FRAM_INTF_WR, 
                            TCOMP => tcomp,
                            FRAM_RDY => FRAM_INTF_RDY,
                            TSTART => tstart,
                            FRAM_ADDR => FRAM_INTF_ADDR,
                            FRAM_WR_DATA => FRAM_INTF_WR_DATA, 
                            FRAM_RD_DATA => FRAM_INTF_RD_DATA, 
                            MOSI0 => mosi0,
                            MOSI1 => mosi1,
                            MOSI2 => mosi2,
                            MOSI3 => mosi3, 
                            MISO0 => miso0,
                            MISO1 => miso1,
                            MISO2 => miso2,
                            MISO3 => miso3,
                            TSIZE => tsize );
  
  -- instantiate SPI CONTROLLER and map
  SC0: spi_ctrl port map ( SYSCLK => FRAM_INTF_CLK,
                           RST_N => FRAM_INTF_RST_N, 
                           MISO => SPI_FRAM_SO,
                           TSTART => tstart, 
                           CS_N => SPI_FRAM_CS_N, 
                           SCLK => SPI_FRAM_CLK, 
                           MOSI => SPI_FRAM_SI, 
                           TCOMP => tcomp, 
                           TSIZE => tsize, 
                           MOSI0 => mosi0, 
                           MOSI1 => mosi1, 
                           MOSI2 => mosi2, 
                           MOSI3 => mosi3, 
                           MISO0 => miso0, 
                           MISO1 => miso1, 
                           MISO2 => miso2, 
                           MISO3 => miso3 );
end architecture rtl;

