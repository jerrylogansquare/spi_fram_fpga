library ieee;
use ieee.std_logic_1164.all;


entity T_THERMOSTAT is
--  no ports for test bench
end T_THERMOSTAT;

architecture test of T_THERMOSTAT is

component THERMOSTAT is
    port (  sel       : in std_logic;
            current   : in std_logic_vector (6 downto 0);
            desired   : in std_logic_vector (6 downto 0);
            cool      : in std_logic;
            heat      : in std_logic;
            furn_hot  : in std_logic;
            ac_ready  : in std_logic;
            CLK       : in std_logic;
            RESET_F   : in std_logic;
            display   : out std_logic_vector (6 downto 0);
            a_c_on    : out std_logic;
            furn_on   : out std_logic;
            fan_on    : out std_logic
         );
end component;

signal sel       : std_logic;
signal current   : std_logic_vector (6 downto 0);
signal desired   : std_logic_vector (6 downto 0);
signal cool      : std_logic := '0';
signal heat      : std_logic := '0';
signal furn_hot   : std_logic := '0';
signal ac_ready  : std_logic := '0';
signal CLK       : std_logic := '0';
signal RESET     : std_logic := '1';
signal display   : std_logic_vector (6 downto 0);
signal a_c_on    : std_logic;
signal furn_on   : std_logic;
signal fan_on    : std_logic;
            
begin

-- 1 / 50ns = 20MHz clock
CLK <= not CLK after 25ns;

-- reset on powerup then 5 microseconds later
RESET <= '1', '0' after 80ns, '1' after 3500ns, '0' after 3580ns;

UUT: THERMOSTAT port map ( sel => sel,
                           current => current,
                           desired => desired,
                           cool => cool,
                           heat => heat,
                           furn_hot => furn_hot,
                           ac_ready => ac_ready,
                           CLK => CLK,
                           RESET_F => RESET,
                           display => display,
                           a_c_on => a_c_on,
                           furn_on => furn_on,
                           fan_on => fan_on);

process
begin
   -- start with heat/cool off, current temp lower than desired
   sel <= '0';
   current <= "0010101";
   desired <= "0010111";
   cool <= '0';
   heat <= '0';
   -- try to turn on heat (while still in reset for 80ns)
   wait for 5ns;
   heat <= '1';
   wait for 5ns;
   heat <= '0';
   wait for 5ns;
   -- change desired temp to higher than current  
   desired <= "0010100";
   wait for 5ns;
   -- try to turn on A/C (while still in reset for 80ns), and change display select
   wait for 5ns;
   cool <= '1';
   sel <= '1';
   wait for 5ns;
   cool <= '0';
   wait for 5ns;

   -- wait for reset to complete
   wait for 100ns;

   -- spring/summer comes, temp goes higher
   current <= "0011010";
   wait for 130 ns;
   -- resident turns on cool
   cool <= '1';
   wait for 400 ns;
   -- AC compressor on and cold
   ac_ready <= '1';
   wait for 470 ns;   
   -- house cools down
   current <= "0010000";
   wait for 510 ns;
   -- AC compressor no longer cold, fan should turn off
   ac_ready <= '0';
   wait for 110 ns;
   -- temp goes up again
   current <= "0011010";
   wait for 600 ns;
   
  
   -- temperature goes down further (winter)
   current <= "0001111";
   wait for 215 ns;
   -- user changes select to show desired setting
   sel <= '0';
   wait for 220 ns;
   -- user turns on heat, its too cold
   -- this is the heat and cool on same time, should be no output
   heat <= '1';
   wait for 215 ns;
   -- user realized they have both heat and cool on, turns on cool
   cool <= '0';
   wait for 410 ns;
   -- furnance has become hot (burners on)
   furn_hot <= '1';
   wait for 520 ns;
   -- user switches back to current temp select, wait for home to heat up
   sel <= '1';
   wait for 210 ns;
   -- temp starts to go up
   current <= "0010000";
   wait for 100 ns;
   current <= "0010010";
   wait for 100 ns;
   current <= "0010110";
   wait for 220 ns;
   -- furance has become cold (burners on)
   furn_hot <= '0';
   wait for 100 ns;
   
   -- reached, furance should turn off, then temp goes down again
   current <= "0010011";
   wait for 520 ns; 

   wait;
end process;
   
end architecture;
