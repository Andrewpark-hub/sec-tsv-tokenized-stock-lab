// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @notice 원주식(나스닥 등)의 거래정지 여부를 온체인에 올려주는 오라클.
///         지정된 리포터만 갱신할 수 있고, 갱신 시각을 함께 기록한다.
contract MarketHaltOracle {
    address public immutable reporter;

    bool public halted;      // 원주식이 거래정지 상태인가
    uint256 public updatedAt; // 마지막으로 보고된 시각

    constructor(address _reporter) {
        reporter = _reporter;
        updatedAt = block.timestamp;
    }

    function report(bool _halted) external {
        require(msg.sender == reporter, "NOT_REPORTER");
        halted = _halted;
        updatedAt = block.timestamp;
    }
}
