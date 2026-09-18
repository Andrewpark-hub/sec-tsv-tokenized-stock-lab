// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MarketHaltOracle} from "./MarketHaltOracle.sol";

/// @title 02-fixed. 모르면 멈춘다 (fail-closed)
/// @notice 추가한 것은 "보고가 얼마나 오래됐는지" 검사 한 줄이다.
///         오라클이 MAX_STALENESS 보다 오래 침묵하면 토큰도 거래를 멈춘다.
///
/// @dev 거래정지 연계는 "정지 신호를 받으면 멈춘다" 가 아니라
///      "정지가 아니라는 것을 최근에 확인했을 때만 거래한다" 로 써야 한다.
///      전자는 오라클 장애가 곧 규제 위반으로 이어지고,
///      후자는 오라클 장애가 거래 중단(= 안전한 쪽)으로 이어진다.
///
///      이건 K-Gold 의 PoR 오라클에도 그대로 걸리는 문제다. 담보 잔고를
///      확인하지 못하는 동안 발행을 계속할 것인가, 멈출 것인가.
contract HaltLinkedStockFixed {
    // 이 시간보다 오래 보고가 없으면 오라클을 믿지 않는다
    uint256 public constant MAX_STALENESS = 1 hours;

    MarketHaltOracle public immutable oracle;

    mapping(address => uint256) public balanceOf;

    constructor(MarketHaltOracle _oracle, address holder, uint256 supply) {
        oracle = _oracle;
        balanceOf[holder] = supply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(!oracle.halted(), "HALTED");
        require(block.timestamp - oracle.updatedAt() <= MAX_STALENESS, "STALE_ORACLE");

        require(balanceOf[msg.sender] >= amount, "BALANCE");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
