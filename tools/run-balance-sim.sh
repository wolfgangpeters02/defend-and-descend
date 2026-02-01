#!/bin/bash
# Run the Balance Simulator CLI
# Usage: ./run-balance-sim.sh [command] [options]

cd "$(dirname "$0")/BalanceSimulator"
swift main.swift "$@"
