configuration IP_DP_RAM_TEST of tb is 
    for TEST 
       for UUT:ram_dp
           use entity WORK.ram_dp(Structure);
       end for;  
	end for;
end IP_DP_RAM_TEST;


configuration RTL_DP_RAM_TEST of tb is 
    for TEST 
       for UUT:ram_dp
           use entity WORK.ram_dp(RTL);
       end for;
    end for;
end RTL_DP_RAM_TEST;


