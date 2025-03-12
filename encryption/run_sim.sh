#!/bin/bash

# 編譯 Verilog 程式
iverilog -o encryption encryption_tb.v encryption.v permutation.v

# 執行模擬
vvp encryption

# 顯示訊息
echo "Simulation complete. Check the output for results."