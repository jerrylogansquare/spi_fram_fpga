library ieee;
use ieee.std_logic_1164.all;

-- added numeric standard for unsigned and signed integers
use ieee.numeric_std.all;

entity THERMOSTAT is
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
end THERMOSTAT;

architecture BEHAV of THERMOSTAT is

type STATE is (ST_INIT, ST_IDLE, ST_PRE_HEAT, ST_HEATING, ST_POST_HEAT, ST_PRE_COOL, ST_COOLING, ST_POST_COOL);

-- internal signals, derived from others 
signal higher : std_logic;
signal lower  : std_logic;

signal cool_only : std_logic;
signal heat_only : std_logic;

-- internal heat and cool input registers
signal i_reg_cool : std_logic;
signal i_reg_heat : std_logic;

signal i_reg_furn_hot : std_logic;
signal i_reg_ac_ready : std_logic;

-- internal heat, AC on, FAN on output registers
signal i_reg_furn_on : std_logic;
signal i_reg_a_c_on  : std_logic;
signal i_reg_fan_on  : std_logic;
-- signal heat, AC on, FAN on output registers
signal sig_furn_on : std_logic;
signal sig_a_c_on  : std_logic;
signal sig_fan_on  : std_logic;

-- internal select register
signal i_reg_sel : std_logic;

-- internal temperature registers 
signal i_reg_current   : std_logic_vector (6 downto 0);
signal i_reg_desired   : std_logic_vector (6 downto 0);
signal i_reg_display   : std_logic_vector (6 downto 0);

-- state registers, current state and next state
signal cur_state : STATE;
signal nxt_state : STATE;

-- set to zero
signal up_cntr : unsigned(7 downto 0) := unsigned'("00000000");
constant heat_dly : unsigned(7 downto 0) := unsigned'("00001010"); -- 10
constant cool_dly : unsigned(7 downto 0) := unsigned'("00010100"); -- 20

begin

heat_only <= i_reg_heat and not i_reg_cool;
cool_only <= i_reg_cool and not i_reg_heat;

-- route internal registers as outputs
furn_on <= i_reg_furn_on;
a_c_on <= i_reg_a_c_on;
fan_on <= i_reg_fan_on;

display <= i_reg_display;

-- clock in inputs to registers, clock out output registers
process (CLK, RESET_F)
begin
    if RESET_F = '1' then
        -- reset all input registers
        i_reg_heat <= '0';
        i_reg_cool <= '0';

        i_reg_current <= (others => '0');
        i_reg_desired <= (others => '0');
    
        -- reset all output registers
        i_reg_furn_on <= '0';
        i_reg_a_c_on <= '0';
        i_reg_fan_on <= '0';
    
        i_reg_display <= (others => '0');
	    up_cntr <= unsigned'("00000000");

    elsif CLK'event and CLK = '1' then
        -- "clock in" all external inputs 
        i_reg_heat <= heat;
        i_reg_cool <= cool;
        
        i_reg_furn_hot <= furn_hot; 
        i_reg_ac_ready <= ac_ready;
        
        i_reg_current <= current; 
        i_reg_desired <= desired;

        -- clock out control signals
        i_reg_furn_on <= sig_furn_on;
        i_reg_a_c_on <= sig_a_c_on;
        i_reg_fan_on <= sig_fan_on;
     
        -- set display register based on inputs (no additional processing)
        if sel = '1' then
            i_reg_display <= current;
        else
            i_reg_display <= desired;
        end if;

	
        if (cur_state = ST_POST_HEAT) or (cur_state = ST_POST_COOL) then
            -- increment counter in post-HEAT or post-COOL states	    
            up_cntr <= up_cntr + 1;
        elsif cur_state = ST_IDLE then
	       -- reset on IDLE
		   up_cntr <= unsigned'("00000000");
        end if;
 
    end if;
   
end process;

process (CLK, RESET_F)
begin
    if RESET_F = '1' then
        -- reset to state machine to initial state
        cur_state <= ST_INIT;
    elsif CLK'event and CLK = '1' then
        -- set current state based on next state
        cur_state <= nxt_state;
    end if;
end process;

-- decide next state based on current state and input signals, 
-- or combinations of input signals
process (cur_state, heat_only, cool_only, lower, higher, i_reg_furn_hot, i_reg_ac_ready, up_cntr)
begin
    -- default next state to current state
    nxt_state <= cur_state;
   
    case cur_state is
        when ST_INIT => 
            -- state is not really necessary but good practice
            sig_furn_on <= '0';
            sig_a_c_on <= '0';
            sig_fan_on <= '0';
            nxt_state <= ST_IDLE;
        
        when ST_IDLE =>
            -- all outputs are off in IDLE state
            sig_furn_on <= '0';
            sig_a_c_on <= '0';
            sig_fan_on <= '0';

            if heat_only = '1' and lower = '1' then
                -- start heating cycle if heat requested and temp lower than desired
                nxt_state <= ST_PRE_HEAT;
	        elsif cool_only = '1' and higher = '1' then
	            -- start cooling cycle if cool requested and temp higher than desired
                nxt_state <= ST_PRE_COOL;
            end if;

        when ST_PRE_HEAT =>
            -- only furnance on in pre-HEAT state
            sig_furn_on <= '1';
            sig_a_c_on  <= '0'; 
            sig_fan_on  <= '0';

            if i_reg_furn_hot = '1' then
                -- furnance is hot, ready to turn on fan
                nxt_state <= ST_HEATING;
            end if;

        when ST_HEATING =>
            -- furnance and fan on while heating
            sig_furn_on <= '1';
            sig_a_c_on  <= '0'; 
            sig_fan_on  <= '1';
	    
            if lower = '0' then
                -- desired temp reached
                nxt_state <= ST_POST_HEAT;
            end if;

        when ST_POST_HEAT =>
            -- only fan on after heating
            sig_furn_on <= '0';
            sig_a_c_on  <= '0'; 
            sig_fan_on  <= '1';

            if i_reg_furn_hot = '0' then
                -- furnance no longer hot, turn off fan
                sig_fan_on  <= '0';
            end if;

            if up_cntr >= heat_dly then 
                -- only allow return to idle after delay
                nxt_state <= ST_IDLE;
            end if;
            
        when ST_PRE_COOL =>
            sig_furn_on <= '0';
            sig_a_c_on  <= '1'; 
            sig_fan_on  <= '0';

            if i_reg_ac_ready = '1' then
                nxt_state <= ST_COOLING;
            end if;

        when ST_COOLING =>
            sig_furn_on <= '0';
            sig_a_c_on  <= '1'; 
            sig_fan_on  <= '1';
	    
            if higher = '0' then
                -- desired temp reached
                nxt_state <= ST_POST_COOL;
            end if;

	when ST_POST_COOL =>
            sig_furn_on <= '0';
            sig_a_c_on  <= '0'; 
            sig_fan_on  <= '1';

            if i_reg_ac_ready = '0' then
                sig_fan_on <= '0';
            end if;

            if up_cntr >= cool_dly then 
                -- only allow return to idle after delay
                nxt_state <= ST_IDLE;
            end if;

	when others =>
	    nxt_state <= ST_INIT;

    end case;
    
    -- regardless of state, if heat/cool turned of just go to IDLE
    if heat_only = '0' and cool_only = '0' then
        nxt_state <= ST_IDLE;
    end if;

end process;


process (i_reg_current,i_reg_desired)
begin

    higher <= '0';
    lower <= '0';
    
    if i_reg_current > i_reg_desired then
        higher <= '1';
    elsif i_reg_current < i_reg_desired then 
        lower <= '1';
    end if;
    
end process;

end architecture;
