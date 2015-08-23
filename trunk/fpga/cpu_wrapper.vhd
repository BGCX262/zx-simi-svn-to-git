library IEEE;
Library UNISIM;
use UNISIM.vcomponents.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;

entity cpu_wrapper is
    port (
        RESET           : in std_logic;
        CLK             : in std_logic;

        ADDR            : out std_logic_vector(15 downto 0);
        DIN             : in  std_logic_vector(7 downto 0);
        DOUT            : out std_logic_vector(7 downto 0);
        
        MEM_DIN_RD      : out std_logic;
        MEM_DIN_VLD     : in std_logic;
        MEM_DOUT_WR     : out std_logic;
        MEM_DOUT_VLD    : in std_logic;        
    
        IO_DIN_RD       : out std_logic;
        IO_DIN_VLD      : in std_logic;
        IO_DOUT_WR      : out std_logic;
        IO_DOUT_VLD     : in std_logic;        

        INT             : in std_logic
    );
end entity;


architecture cpu_wrapper_inst of cpu_wrapper is

    signal reset_n  : std_logic;
    signal clk_n    : std_logic;
    signal wait_n   : std_logic;
    signal int_n    : std_logic;
    signal mreq_n   : std_logic;
    signal iorq_n   : std_logic;
    signal rd_n     : std_logic;
    signal wr_n     : std_logic;
    
    signal mem_din_rd_sig : std_logic;
    signal mem_dout_wr_sig : std_logic;
    
    signal io_din_rd_sig : std_logic;
    signal io_dout_wr_sig : std_logic;
    
begin

    reset_n <= not RESET;
    clk_n   <= CLK;
    
    int_n <= not INT;

    wait_n <= '0' when (io_din_rd_sig='1' and IO_DIN_VLD='0') or (io_dout_wr_sig='1' and IO_DOUT_VLD='0') or (mem_din_rd_sig='1' and MEM_DIN_VLD='0') or (mem_dout_wr_sig='1' and MEM_DOUT_VLD='0') else '1';


    MEM_DIN_RD <= mem_din_rd_sig;
    mem_din_rd_sig <= not (rd_n or mreq_n);
    
    MEM_DOUT_WR <= mem_dout_wr_sig;
    mem_dout_wr_sig <= not (wr_n or mreq_n);
    
    IO_DIN_RD <= io_din_rd_sig;
    io_din_rd_sig <= not (rd_n or iorq_n);
    
    IO_DOUT_WR <= io_dout_wr_sig;
    io_dout_wr_sig <= not (wr_n or iorq_n);
    
    T80a_inst : entity work.T80s
    generic map(
		Mode => 0,	-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
		T2Write => 1,	-- 0 => WR_n active in T3, /=0 => WR_n active in T2
		IOWait => 1	-- 0 => Single cycle I/O, 1 => Std I/O cycle
    )
    port map (
        RESET_n     => reset_n,
        CLK_n       => clk_n,
        WAIT_n      => wait_n,
        INT_n       => int_n,
        NMI_n       => '1',
        BUSRQ_n     => '1',
        M1_n        => open,
        MREQ_n      => mreq_n,
        IORQ_n      => iorq_n,
        RD_n        => rd_n,
        WR_n        => wr_n,
        RFSH_n      => open,
        HALT_n      => open,
        BUSAK_n     => open,
        A           => ADDR,
        DI			=> DIN,
		DO			=> DOUT
    );

end architecture;