library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;


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

constant PERIOD: time := 50ns;
            
begin

-- 1 / 50ns = 20MHz clock
CLK <= not CLK after 25ns;

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

-- Wait specified number of clock ticks
procedure WaitTicks( signal SYSCLOCK: in std_logic; TICKS: in integer ) is
variable clk_ticks_cnt : integer := 0;
begin
    while ( clk_ticks_cnt < TICKS) loop
        wait until SYSCLOCK'event and SYSCLOCK='1';
        clk_ticks_cnt := clk_ticks_cnt + 1;
    end loop;
end;

-- Set Temps procedure
procedure SetTemps( CUR_TEMP, DES_TEMP: in integer) is
begin
    -- convert integer to 7 bit vector and write
    current <= conv_std_logic_vector(CUR_TEMP,7);
    desired <= conv_std_logic_vector(DES_TEMP,7);
end;

variable FURN_ON_TIME : time := 0ns;
variable FURN_OFF_TIME : time := 0ns;
variable AC_ON_TIME : time := 0ns;
variable AC_OFF_TIME : time := 0ns;
variable FAN_ON_TIME : time := 0ns;
variable FAN_OFF_TIME : time := 0ns;
variable TIME_SPAN : time := 0ns;

begin
   wait until CLK'event and CLK='1';

   assert FALSE report "Starting test bench execution" severity note;
   -- put in powerup reset first
   RESET <= '1';
   
   -- start with heat/cool off, current temp lower than desired
   sel <= '0';
   cool <= '0';
   heat <= '0';
   SetTemps(CUR_TEMP=>65, DES_TEMP=>72);
   
   -- try to turn on heat while in reset
   heat <= '1';
   WaitTicks(CLK, 5); -- wait 5 clock ticks
   assert furn_on = '0' report "Furnance ON during reset" severity error;
   assert fan_on = '0' report "Fan ON during reset" severity error;
   heat <= '0';

   WaitTicks(CLK, 2); -- wait 2 clock ticks
   
   -- try to turn on cool while in reset
   cool <= '1';
   WaitTicks(CLK, 5); -- wait 5 clock ticks
   assert a_c_on = '0' report "A/C ON during reset" severity error;
   assert fan_on = '0' report "Fan ON during reset" severity error;
   cool <= '0';

   WaitTicks(CLK, 2); -- wait 2 clock ticks

   -- deassert RESET
   RESET <= '0';

   WaitTicks(CLK, 2); -- wait 2 clock ticks
   
   -- change desired temp to higher than current  
   SetTemps(CUR_TEMP=>80, DES_TEMP=>72);

   sel <= '1';
   WaitTicks(CLK, 2); -- wait 2 clock ticks
 
   assert display = conv_std_logic_vector(80,7) report "display doesn't match current temp" severity error;
   
   -- resident turns on cool
   cool <= '1';

   WaitTicks(CLK, 4); -- wait 4 clock ticks
   assert a_c_on = '1' report "A/C not on after cool assertion" severity error;
   assert fan_on = '0' report "Fan ON after cool assertion but before ac_ready assertion" severity error;

   WaitTicks(CLK, 2); -- wait 2 clock ticks
   -- AC compressor on and cold
   ac_ready <= '1';
   WaitTicks(CLK, 4); -- wait 4 clock ticks
   -- check both A/C is on and FAN is on
   assert a_c_on = '1' report "A/C not on after cool and ac_ready assertion" severity error;
   assert fan_on = '1' report "Fan OFF after cool assertion and ac_ready assertion" severity error;
   
   WaitTicks(CLK, 10); -- wait 10 clock ticks, let house cool down
   SetTemps(CUR_TEMP=>72, DES_TEMP=>72); -- desired temp reached
      
   WaitTicks(CLK, 4); -- wait 4 clock ticks
   AC_OFF_TIME := NOW; --marks transition from COOLING to POST_COOL state
   -- check outputs after desired temp reached, but before ac ready turns off
   assert a_c_on = '0' report "A/C not off after desired temp reached" severity error;
   assert fan_on = '1' report "Fan OFF after desired temp reached but before ac_ready deassertion" severity error;
   
   -- AC compressor off, coils warm
   ac_ready <= '0';
   WaitTicks(CLK, 4); -- wait 4 clock ticks
   assert fan_on = '0' report "Fan ON after ac_ready deassertion" severity error;
   
   SetTemps(CUR_TEMP=>73, DES_TEMP=>72); -- house gets warm again
   -- wait for A/C to turn back on a measure time from AC off to AC on
   wait until a_c_on'event and a_c_on = '1';
   AC_ON_TIME := NOW; -- marks transition back to COOLING state
   TIME_SPAN := AC_ON_TIME - AC_OFF_TIME;
   assert FALSE report "A/C cycling delay measured as " & time'image(TIME_SPAN) severity note;
   
   ac_ready <= '1';
   WaitTicks(CLK, 4); -- wait 4 clock ticks 
   SetTemps(CUR_TEMP=>72, DES_TEMP=>72); -- house gets cool again
   -- turn off cooling system
   WaitTicks(CLK, 4); -- wait 4 clock ticks 
   ac_ready <= '0';
   
   WaitTicks(CLK, 20); -- wait 20 clock ticks, winter sets in 
   SetTemps(CUR_TEMP=>65, DES_TEMP=>72); -- house gets too cold
    
   WaitTicks(CLK, 10); -- wait 10 clock ticks
   -- resident turns on heat and cool same time accidently
   heat <= '1';
   
   WaitTicks(CLK, 10); -- wait 10 clock ticks
   -- resident realizes heat and cool on, turns off cool
   cool <= '0';

   -----------------------------------
   -- START HEATING 
   -----------------------------------
   
   WaitTicks(CLK, 4); -- wait 4 clock ticks
   assert furn_on = '1' report "furnace not on after heat assertion" severity error;
   assert fan_on = '0' report "Fan ON after heat assertion but before furn_hot assertion" severity error;

   WaitTicks(CLK, 2); -- wait 2 clock ticks
   -- furnance hot
   furn_hot <= '1';
   WaitTicks(CLK, 4); -- wait 4 clock ticks
   -- check both furnance is on and FAN is on
   assert furn_on = '1' report "furance not on after heat and furn_hot assertion" severity error;
   assert fan_on = '1' report "Fan OFF after heat and furn_hot assertion" severity error;
   
   WaitTicks(CLK, 10); -- wait 10 clock ticks, let house cool down
   SetTemps(CUR_TEMP=>72, DES_TEMP=>72); -- desired temp reached
      
   WaitTicks(CLK, 4); -- wait 4 clock ticks
   FURN_OFF_TIME := NOW; --marks transition from HEATING to POST_HEAT state
   -- check outputs after desired temp reached, but before furn_hot turns off
   assert furn_on = '0' report "Furnace not off after desired temp reached" severity error;
   assert fan_on = '1' report "Fan OFF after desired temp reached but before furn_hot deassertion" severity error;
   
   -- burners off, furance cools
   furn_hot <= '0';
   WaitTicks(CLK, 4); -- wait 4 clock ticks
   assert fan_on = '0' report "Fan ON after furn_hot deassertion" severity error;
   
   SetTemps(CUR_TEMP=>69, DES_TEMP=>72); -- house gets cold again
   -- wait for furnance to turn back on a measure time from furnace off to furnace on
   wait until furn_on'event and furn_on = '1';
   FURN_ON_TIME := NOW; -- marks transition back to COOLING state
   TIME_SPAN := FURN_ON_TIME - FURN_OFF_TIME;
   assert FALSE report "furnace cycling delay measured as " & time'image(TIME_SPAN) severity note;
   
   furn_hot <= '1';
   WaitTicks(CLK, 4); -- wait 4 clock ticks 
   SetTemps(CUR_TEMP=>72, DES_TEMP=>72); -- house gets cool again
   -- turn off heating system
   WaitTicks(CLK, 4); -- wait 4 clock ticks 
   furn_hot <= '0';
   
   WaitTicks(CLK, 20); -- wait 20 clock ticks, winter sets in 
    
   wait;
end process;
   
end architecture;
