// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MarketHaltOracle} from "./MarketHaltOracle.sol";

/// @title 02. 거래정지 연계 — 오라클이 멈추면 어느 쪽으로 넘어지는가
/// @notice 기사: "기존 시장에서 애플 주식 거래가 중단될 경우 토큰화 주식 역시
///         거래를 중단해야 한다." 이 한 줄을 그대로 옮기면 아래처럼 된다.
///
/// @dev 문제는 오라클이 말해주지 않을 때다.
///      halted 는 리포터가 push 로 갱신해주는 값이라, 리포터가 죽으면
///      마지막 값에 그대로 멈춰 있는다. 원주식은 이미 정지됐는데 온체인의
///      halted 는 여전히 false 인 구간이 생긴다.
///
///      이 버전은 halted 만 보고 updatedAt 을 보지 않는다.
///      즉 "모르면 통과"(fail-open)다. 정지 요건을 지키려면 반대여야 한다.
contract HaltLinkedStock {
    MarketHaltOracle public immutable oracle;

    mapping(address => uint256) public balanceOf;

    constructor(MarketHaltOracle _oracle, address holder, uint256 supply) {
        oracle = _oracle;
        balanceOf[holder] = supply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        // 오라클이 "정지"라고 말한 경우에만 막는다. 말이 없으면 거래를 허용한다.
        require(!oracle.halted(), "HALTED");

        require(balanceOf[msg.sender] >= amount, "BALANCE");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
