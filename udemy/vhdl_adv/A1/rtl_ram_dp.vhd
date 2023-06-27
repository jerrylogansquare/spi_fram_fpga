library IEEE;

use IEEE.std_logic_1164.all;
use ieee.STD_LOGIC_ARITH.all;

entity ram_dp is
    -- the port definition is copied from the vendor implementation
    port (
        DataInA: in  std_logic_vector(15 downto 0); 
        DataInB: in  std_logic_vector(15 downto 0); 
        AddressA: in  std_logic_vector(3 downto 0); 
        AddressB: in  std_logic_vector(3 downto 0); 
        ClockA: in  std_logic; 
        ClockB: in  std_logic; 
        ClockEnA: in  std_logic; 
        ClockEnB: in  std_logic; 
        WrA: in  std_logic; 
        WrB: in  std_logic; 
        ResetA: in  std_logic; 
        ResetB: in  std_logic; 
        QA: out  std_logic_vector(15 downto 0); 
       QB: out  std_logic_vector(15 downto 0));
end ram_dp;

architecture RTL of ram_dp is

-- create memory block using array of logic vectors
-- memory size: 16 x 16 bit
type MEMTYPE is array(15 downto 0) of std_logic_vector(15 downto 0); 
signal DPMEM : MEMTYPE;

signal AddrA_Int,AddrB_Int : integer range 0 to 15;
signal ClockA_gated : std_logic;
signal ClockB_gated : std_logic;

begin

-- convert vector to integer to use for memory index        
AddrA_Int <= conv_integer(unsigned(AddressA));
AddrB_Int <= conv_integer(unsigned(AddressB));

-- gate the clock inputs
ClockA_gated <= ClockA and ClockEnA;
ClockB_gated <= ClockB and ClockEnB;

-- write only process for 'left' (A) side
process(ClockA_gated, ResetA)
begin
    if ResetA'event and ResetA = '1' then
        QA <= (others => 'Z');
    elsif ClockA_gated'event and ClockA_gated = '1' then
        if WrA = '1' then
            DPMEM(AddrA_Int) <= DataInA;
        end if;
    end if;
end process;

-- read only process for 'right' (B) side
process(ClockB_gated, ResetB)
begin
    if ResetB'event and ResetB = '1' then
        QB <= (others => 'Z');
    elsif ClockB_gated'event and ClockB_gated = '1' then
        QB <= DPMEM(AddrB_Int);
    end if;
end process;

end RTL;

