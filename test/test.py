# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start EdgeGuard ASIC Verification")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Resetting chip")
    dut.ena.value = 1
    dut.ui_in.value = 160  # Safe nominal voltage (~220V scaled)
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # 1. Verify safe state: Relay Trip (bit 0) = 0, Warning (bit 1) = 0
    assert int(dut.uo_out.value) == 0

    # 2. Simulate brief 2-cycle surge (should trigger warning, NOT trip relay)
    dut._log.info("Testing brief voltage flicker")
    dut.ui_in.value = 240  # Over-voltage limit is 220
    await ClockCycles(dut.clk, 2)
    assert (int(dut.uo_out.value) & 0b01) == 0  # Relay must stay OFF

    # Return to safe voltage
    dut.ui_in.value = 160
    await ClockCycles(dut.clk, 2)
    assert int(dut.uo_out.value) == 0

    # 3. Simulate sustained 7-cycle surge (must trip relay and increment fault counter)
    dut._log.info("Testing sustained voltage surge")
    dut.ui_in.value = 245
    await ClockCycles(dut.clk, 7)
    # Bit 0 (Relay Trip) = 1, Bit 1 (Warning) = 1, Bits [7:2] (Faults = 1 -> 4) => 4 + 2 + 1 = 7
    assert int(dut.uo_out.value) == 7

    dut._log.info("EdgeGuard ASIC passed all hardware verification tests!")
